import { Prisma } from '@prisma/client';
import { z } from 'zod';
import { inventoryQuantityForUnit } from './product-validation.js';

export const initialRoomAllocationsInput = z.array(z.object({
  roomId: z.string().trim().min(1).max(100),
  quantity: z.number().finite().positive().max(1000000),
}).strict()).min(1).max(100);

/** Opening stock and its locations commit together; no extra stock is created. */
export async function allocateOpeningRoomStock(
  tx: Prisma.TransactionClient, productId: string, total: number,
  allocations: z.infer<typeof initialRoomAllocationsInput> | undefined,
  actorId?: string, unitLabel?: string | null,
): Promise<void> {
  if (!allocations) return; // Existing clients retain Unassigned opening stock.
  const factor = unitLabel != null && /^\s*\d+(?:\.\d+)?\s*(?:kg|g)\s*$/i.test(unitLabel) ? 1000 : 1;
  if (allocations.some((row) => Math.abs(row.quantity * factor - Math.round(row.quantity * factor)) > 0.000001)) {
    throw new RoomInventoryError('Enter valid room quantities in the same unit as starting stock.');
  }
  const rows = allocations.map((row) => ({ ...row,
    quantity: unitLabel == null ? row.quantity : inventoryQuantityForUnit(row.quantity, unitLabel),
  }));
  if (new Set(rows.map((row) => row.roomId)).size !== rows.length ||
      rows.some((row) => !Number.isSafeInteger(row.quantity) || row.quantity <= 0) ||
      rows.reduce((sum, row) => sum + row.quantity, 0) !== total) {
    throw new RoomInventoryError('Room quantities must match the starting stock exactly. Choose each room once.');
  }
  if (await tx.inventoryRoom.count({ where: { id: { in: rows.map((row) => row.roomId) }, active: true } }) !== rows.length) {
    throw new RoomInventoryError('Choose active rooms. Refresh the room list before saving.');
  }
  for (const row of rows) {
    await tx.inventoryRoomStock.create({ data: { productId, ...row } });
    await tx.inventoryRoomMovement.create({ data: {
      productId, fromRoomId: null, toRoomId: row.roomId, quantity: row.quantity,
      reason: 'OPENING', referenceId: `opening:${productId}`, actorId: actorId ?? null,
    } });
  }
}

export type RoomPick = { productId: string; roomId: string | null; quantity: number };
export class RoomInventoryError extends Error {}

/** Called inside the same serializable transaction as the aggregate stock write.
 * New receipts/returns enter Unassigned; placing stock never creates new units.
 */
export async function consumeRoomStock(
  tx: Prisma.TransactionClient, productId: string, quantity: number,
  before: number, referenceId: string, actorId?: string,
  picks?: RoomPick[], reason = 'SALE',
): Promise<void> {
  const stocks = await tx.inventoryRoomStock.findMany({
    where: { productId, quantity: { gt: 0 } }, orderBy: { roomId: 'asc' },
  });
  const assigned = stocks.reduce((sum, row) => sum + row.quantity, 0);
  if (assigned > before) throw new RoomInventoryError('Room stock exceeds total stock. Refresh Inventory before billing.');
  const unassigned = before - assigned;
  const selected = picks?.filter((pick) => pick.productId === productId);
  let allocations: RoomPick[];
  if (selected) {
    const seen = new Set<string | null>();
    if (selected.reduce((sum, pick) => sum + pick.quantity, 0) !== quantity ||
        selected.some((pick) => !Number.isSafeInteger(pick.quantity) || pick.quantity <= 0 ||
          (seen.has(pick.roomId) ? true : (seen.add(pick.roomId), false)))) {
      throw new RoomInventoryError('Choose room quantities matching every bill item exactly.');
    }
    allocations = selected;
  } else {
    // Orders/legacy clients consume unassigned first, then rooms deterministically.
    allocations = [];
    let left = quantity;
    if (unassigned > 0) {
      const take = Math.min(left, unassigned);
      allocations.push({ productId, roomId: null, quantity: take }); left -= take;
    }
    for (const row of stocks) {
      const take = Math.min(left, row.quantity);
      if (take > 0) allocations.push({ productId, roomId: row.roomId, quantity: take });
      left -= take;
    }
    if (left !== 0) throw new RoomInventoryError('Insufficient room stock. Refresh and try again.');
  }
  // No rooms configured: avoid writing one extra movement for every legacy sale.
  if (stocks.length === 0 && !selected) return;
  for (const pick of allocations) {
    if (pick.roomId == null) {
      if (pick.quantity > unassigned) throw new RoomInventoryError('Not enough Unassigned stock. Choose another room.');
    } else {
      const changed = await tx.inventoryRoomStock.updateMany({
        where: { roomId: pick.roomId, productId, quantity: { gte: pick.quantity }, room: { active: true } },
        data: { quantity: { decrement: pick.quantity } },
      });
      if (changed.count !== 1) throw new RoomInventoryError('The selected room has insufficient stock or is inactive. Refresh and choose again.');
    }
    await tx.inventoryRoomMovement.create({ data: {
      productId, fromRoomId: pick.roomId, quantity: pick.quantity, reason,
      referenceId, actorId,
    } });
  }
}

/** Lock the aggregate row first, then room rows, using the sale's lock order. */
export async function lockRoomProduct(tx: Prisma.TransactionClient, productId: string) {
  if (productId.startsWith('wholesale-')) {
    const rows = await tx.$queryRaw<Array<{ stock: number }>>`
      SELECT "stock" FROM "WholesaleItem" WHERE "id" = ${productId.slice(10)}`;
    if (!rows[0]) throw new RoomInventoryError('Product not found.');
    return Number(rows[0].stock);
  }
  const rows = await tx.$queryRaw<Array<{ totalStock: number }>>`
    SELECT "totalStock" FROM "Inventory" WHERE "productId" = ${productId}`;
  if (!rows[0]) throw new RoomInventoryError('Product has no stock record.');
  return Number(rows[0].totalStock);
}
