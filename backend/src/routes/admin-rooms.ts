import { Router, type RequestHandler } from 'express';
import { Prisma, type PrismaClient } from '@prisma/client';
import { z } from 'zod';
import { sendAdminError } from '../middleware/auth.js';
import { runTransactionWithRetry } from '../services/transaction-retry.js';
import { consumeRoomStock, lockRoomProduct, RoomInventoryError } from '../services/room-inventory.js';
import { InventoryService, InventoryAdjustmentError } from '../services/inventory.js';

const roomInput = z.object({
  name: z.string().trim().min(1).max(80),
  number: z.string().trim().min(1).max(30).transform((value) => value.toUpperCase()),
}).strict();
const transferInput = z.object({
  requestId: z.string().uuid(), productId: z.string().min(1).max(100),
  fromRoomId: z.string().min(1).max(100).nullable(),
  toRoomId: z.string().min(1).max(100).nullable(),
  quantity: z.number().int().positive().max(2147483647),
}).strict().refine((value) => value.fromRoomId !== value.toRoomId);
const stockFingerprint = (items: unknown, picks: unknown) => JSON.stringify({
  items: (items as Array<{ productId: string; quantity: number; sku?: string }>).map((item) => [item.productId, item.quantity, item.sku ?? null]).sort(),
  picks: (picks as Array<{ productId: string; roomId: string | null; quantity: number }>).map((pick) => [pick.productId, pick.roomId, pick.quantity]).sort(),
});

export function createRoomInventoryRouter(prisma: PrismaClient, adminOnly: RequestHandler) {
  const router = Router();
  const errorResponse = (error: unknown, res: Parameters<RequestHandler>[1]) => {
    if (error instanceof RoomInventoryError || error instanceof InventoryAdjustmentError) return res.status(409).json({ error: error.message });
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
      return res.status(409).json({ error: 'That room number or request already exists. Refresh before trying again.' });
    }
    return sendAdminError(error, res);
  };
  const snapshot = async (ids?: string[]) => prisma.$transaction(async (tx) => {
    const [rooms, stocks, inventory, wholesale] = await Promise.all([
      tx.inventoryRoom.findMany({ orderBy: [{ number: 'asc' }, { id: 'asc' }] }),
      tx.inventoryRoomStock.findMany({ where: ids ? { productId: { in: ids } } : {}, take: 50001 }),
      tx.inventory.findMany({ where: ids ? { productId: { in: ids } } : {},
        select: { productId: true, totalStock: true, reservedStock: true, product: { select: { id: true, name: true, sku: true, barcode: true, price: true, unitLabel: true, imageUrl: true } } }, take: 50001 }),
      tx.wholesaleItem.findMany({ where: ids ? { id: { in: ids.filter((id) => id.startsWith('wholesale-')).map((id) => id.slice(10)) } } : {},
        select: { id: true, stock: true, name: true, sku: true, price: true, unitLabel: true, imageUrl: true }, take: 50001 }),
    ]);
    if ([stocks, inventory, wholesale].some((rows) => rows.length > 50000)) throw new RoomInventoryError('Inventory is too large. Search for specific products.');
    return { rooms, stocks, products: [
      ...inventory.map((row) => ({ ...row.product, price: Number(row.product.price), available: row.totalStock - row.reservedStock })),
      ...wholesale.map((row) => ({ id: `wholesale-${row.id}`, name: row.name, sku: row.sku, imageUrl: row.imageUrl, barcode: null, price: Number(row.price), unitLabel: row.unitLabel, available: row.stock })),
    ], totals: [
      ...inventory.map((row) => ({ productId: row.productId, total: row.totalStock, available: row.totalStock - row.reservedStock })),
      ...wholesale.map((row) => ({ productId: `wholesale-${row.id}`, total: row.stock, available: row.stock })),
    ], capturedAt: new Date().toISOString() };
  });
  router.get('/', async (_req, res) => {
    try { return res.json(await snapshot()); } catch (error) { return errorResponse(error, res); }
  });
  router.post('/availability', async (req, res) => {
    const parsed = z.object({ productIds: z.array(z.string().min(1).max(100)).min(1).max(100) }).strict().safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: 'Choose up to 100 products.' });
    try { return res.json(await snapshot(parsed.data.productIds)); } catch (error) { return errorResponse(error, res); }
  });
  router.post('/', adminOnly, async (req, res) => {
    const parsed = roomInput.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: 'Enter a room name and a unique room number.' });
    try { return res.status(201).json({ room: await prisma.inventoryRoom.create({ data: parsed.data }) }); }
    catch (error) { return errorResponse(error, res); }
  });
  // Financial records remain on the computer; only stock leaves this endpoint.
  router.post('/local-sales', adminOnly, async (req, res) => {
    const parsed = z.object({
      requestId: z.string().uuid(),
      items: z.array(z.object({ productId: z.string().min(1).max(100), quantity: z.number().int().positive().max(2147483647), sku: z.string().trim().min(1).max(100).optional() }).strict()).min(1).max(100),
      roomPicks: z.array(z.object({ productId: z.string().min(1).max(100), roomId: z.string().min(1).max(100).nullable(), quantity: z.number().int().positive().max(2147483647) }).strict()).min(1).max(500),
    }).strict().safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: 'A valid local stock snapshot is required.' });
    const input = parsed.data;
    const ownerId = res.locals.authenticatedUserId as string;
    try {
      const resolved = new Map<string, string>();
      // Offline catalog entries receive a database ID after catalog sync.
      // The cashier's sync worker only submits these once catalog sync succeeds.
      for (const item of input.items) {
        if (/^(offline|wholesale)-\d+$/.test(item.productId)) {
          if (!item.sku) throw new RoomInventoryError('Synchronize the offline product catalogue before sharing its stock.');
          const match = item.productId.startsWith('wholesale-')
            ? await prisma.wholesaleItem.findUnique({ where: { sku: item.sku }, select: { id: true } })
            : await prisma.product.findUnique({ where: { sku: item.sku }, select: { id: true } });
          if (!match) throw new RoomInventoryError('Synchronize the offline product catalogue before sharing its stock.');
          resolved.set(item.productId, item.productId.startsWith('wholesale-') ? `wholesale-${match.id}` : match.id);
        } else { resolved.set(item.productId, item.productId); }
      }
      await runTransactionWithRetry(prisma, async (tx) => {
        const existing = await tx.inventoryLocalStockReceipt.findUnique({ where: { id: input.requestId } });
        if (existing) {
          if (existing.ownerId !== ownerId || stockFingerprint(existing.items, existing.roomPicks) !== stockFingerprint(input.items, input.roomPicks)) throw new RoomInventoryError('This stock reference has different contents. Review the saved local bill.');
          return;
        }
        if (new Set(input.items.map((item) => item.productId)).size !== input.items.length || input.roomPicks.some((pick) => !input.items.some((item) => item.productId === pick.productId))) throw new RoomInventoryError('Stock selections do not match the local bill.');
        const items = input.items.map((item) => ({ ...item, productId: resolved.get(item.productId)! }));
        if (new Set(items.map((item) => item.productId)).size !== items.length) throw new RoomInventoryError('Multiple local products resolve to the same database product. Review the catalogue.');
        const picks = input.roomPicks.map((pick) => ({ ...pick, productId: resolved.get(pick.productId)! }));
        const retail = items.filter((item) => !item.productId.startsWith('wholesale-')).sort((a,b) => a.productId.localeCompare(b.productId));
        await new InventoryService(prisma).consumeStockForPosSale(tx, retail, `LOCAL-${input.requestId}`, ownerId, picks);
        for (const item of items.filter((item) => item.productId.startsWith('wholesale-')).sort((a,b) => a.productId.localeCompare(b.productId))) {
          const before = await lockRoomProduct(tx, item.productId);
          if (item.quantity > before) throw new RoomInventoryError('Insufficient wholesale stock. Review the local bill.');
          await tx.wholesaleItem.update({ where: { id: item.productId.slice(10) }, data: { stock: { decrement: item.quantity } } });
          await consumeRoomStock(tx, item.productId, item.quantity, before, `LOCAL-${input.requestId}`, ownerId, picks);
        }
        await tx.inventoryLocalStockReceipt.create({ data: { id: input.requestId, ownerId, items: input.items, roomPicks: input.roomPicks } });
      });
      return res.json({ success: true, requestId: input.requestId, productIds: Object.fromEntries(resolved) });
    } catch (error) { return errorResponse(error, res); }
  });
  router.patch('/:id', adminOnly, async (req, res) => {
    const parsed = roomInput.extend({ active: z.boolean() }).safeParse(req.body);
    if (!parsed.success || req.params.id.length > 100) return res.status(400).json({ error: 'Enter valid room details.' });
    try {
      const room = await runTransactionWithRetry(prisma, async (tx) => {
        if (!parsed.data.active && await tx.inventoryRoomStock.count({ where: { roomId: req.params.id, quantity: { gt: 0 } } })) {
          throw new RoomInventoryError('Move all stock out before deactivating this room.');
        }
        return tx.inventoryRoom.update({ where: { id: req.params.id }, data: parsed.data });
      });
      return res.json({ room });
    } catch (error) { return errorResponse(error, res); }
  });
  router.post('/transfers', adminOnly, async (req, res) => {
    const parsed = transferInput.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: 'Choose different source and destination rooms and a positive whole quantity.' });
    const input = parsed.data;
    try {
      await runTransactionWithRetry(prisma, async (tx) => {
        const old = await tx.inventoryRoomMovement.findUnique({ where: { requestId: input.requestId } });
        if (old) {
          if (old.productId !== input.productId || old.quantity !== input.quantity || old.fromRoomId !== input.fromRoomId || old.toRoomId !== input.toRoomId) {
            throw new RoomInventoryError('This transfer reference has different contents. Refresh Inventory.');
          }
          return;
        }
        const total = await lockRoomProduct(tx, input.productId);
        const ids = [input.fromRoomId, input.toRoomId].filter((id): id is string => id != null);
        if (await tx.inventoryRoom.count({ where: { id: { in: ids }, active: true } }) !== ids.length) throw new RoomInventoryError('Choose active rooms.');
        const rows = await tx.inventoryRoomStock.findMany({ where: { productId: input.productId } });
        const assigned = rows.reduce((sum, row) => sum + row.quantity, 0);
        if (assigned > total) throw new RoomInventoryError('Room counts exceed total stock. Review the stock adjustment.');
        if (input.fromRoomId == null) {
          if (input.quantity > total - assigned) throw new RoomInventoryError('Not enough Unassigned stock.');
        } else {
          const changed = await tx.inventoryRoomStock.updateMany({
            where: { productId: input.productId, roomId: input.fromRoomId, quantity: { gte: input.quantity } },
            data: { quantity: { decrement: input.quantity } },
          });
          if (changed.count !== 1) throw new RoomInventoryError('Not enough stock in the source room.');
        }
        if (input.toRoomId) await tx.inventoryRoomStock.upsert({
          where: { roomId_productId: { roomId: input.toRoomId, productId: input.productId } },
          create: { roomId: input.toRoomId, productId: input.productId, quantity: input.quantity },
          update: { quantity: { increment: input.quantity } },
        });
        await tx.inventoryRoomMovement.create({ data: {
          ...input, reason: 'TRANSFER', actorId: res.locals.authenticatedUserId ?? null,
        } });
      });
      return res.json({ success: true });
    } catch (error) { return errorResponse(error, res); }
  });
  router.get('/movements', async (req, res) => {
    const parsed = z.object({ productId: z.string().min(1).max(100) }).strict().safeParse(req.query);
    if (!parsed.success) return res.status(400).json({ error: 'Choose a product.' });
    try { return res.json({ movements: await prisma.inventoryRoomMovement.findMany({
      where: { productId: parsed.data.productId }, orderBy: [{ createdAt: 'desc' }, { id: 'desc' }], take: 100,
    }) }); } catch (error) { return errorResponse(error, res); }
  });
  return router;
}
