import assert from 'node:assert/strict';
import express from 'express';
import type { Prisma, PrismaClient } from '@prisma/client';
import { consumeRoomStock, RoomInventoryError, allocateOpeningRoomStock } from '../src/services/room-inventory.js';
import { InventoryService } from '../src/services/inventory.js';
import { createRoomInventoryRouter } from '../src/routes/admin-rooms.js';
import { createAdminBillingRouter } from '../src/routes/admin-billing.js';

// Isolated rollback-capable fixture. No database connection or real stock.
type Row = Record<string, any>;
async function main() {
  const openingRows: Row[] = [], openingMovements: Row[] = [];
  const openingTx = {
    inventoryRoom: { count: async ({where}: Row) => where.id.in.filter((id: string) => ['a', 'b'].includes(id)).length },
    inventoryRoomStock: { create: async ({data}: Row) => { openingRows.push(data); } },
    inventoryRoomMovement: { create: async ({data}: Row) => { openingMovements.push(data); } },
  } as unknown as Prisma.TransactionClient;
  await allocateOpeningRoomStock(openingTx, 'new-product', 5,
    [{roomId: 'a', quantity: 2}, {roomId: 'b', quantity: 3}], 'cashier', '1 pc');
  assert.deepEqual(openingRows.map((r) => [r.roomId, r.quantity]), [['a', 2], ['b', 3]]);
  assert.equal(openingMovements.length, 2);
  openingRows.length = 0;
  await allocateOpeningRoomStock(openingTx, 'rice', 1500,
    [{roomId: 'a', quantity: 1.25}, {roomId: 'b', quantity: .25}], 'cashier', '1 kg');
  assert.deepEqual(openingRows.map((r) => r.quantity), [1250, 250]);
  for (const allocations of [
    [{roomId: 'a', quantity: 1}],
    [{roomId: 'a', quantity: 2}, {roomId: 'a', quantity: 3}],
    [{roomId: 'inactive', quantity: 5}],
    [{roomId: 'a', quantity: 2.5}, {roomId: 'b', quantity: 2.5}],
  ]) {
    const before = openingRows.length;
    await assert.rejects(allocateOpeningRoomStock(openingTx, 'bad', 5, allocations, 'cashier', '1 pc'), RoomInventoryError);
    assert.equal(openingRows.length, before, 'invalid opening allocations never create partial room stock');
  }
  let stocks: Row[] = [{ productId: 'p', roomId: 'a', quantity: 6 }, { productId: 'p', roomId: 'b', quantity: 2 }];
  let movements: Row[] = [];
  let receipts: Row[] = [];
  let total = 10;
  const rooms: Row[] = [{ id: 'a', name: 'Main room', number: '01', active: true }, { id: 'b', name: 'Back room', number: '02', active: true }];
  const tx = {
    inventoryRoom: {
      findMany: async () => rooms,
      count: async ({ where }: Row) => rooms.filter((r) => where.id.in.includes(r.id) && r.active).length,
    },
    inventoryRoomStock: {
      findMany: async ({ where }: Row) => stocks.filter((r) => (!where.productId || (typeof where.productId === 'string' ? r.productId === where.productId : where.productId.in.includes(r.productId))) && (!where.quantity || r.quantity > 0)).map((r) => ({ ...r })),
      updateMany: async ({ where, data }: Row) => {
        const row = stocks.find((r) => r.productId === where.productId && r.roomId === where.roomId && r.quantity >= where.quantity.gte);
        if (!row) return { count: 0 };
        row.quantity -= data.quantity.decrement; return { count: 1 };
      },
      upsert: async ({ where, create, update }: Row) => {
        const row = stocks.find((r) => r.productId === where.roomId_productId.productId && r.roomId === where.roomId_productId.roomId);
        if (row) { row.quantity += update.quantity.increment; } else { stocks.push({ ...create }); }
      },
    },
    inventoryRoomMovement: {
      findUnique: async ({ where }: Row) => movements.find((r) => r.requestId === where.requestId) ?? null,
      create: async ({ data }: Row) => { const row = { ...data, fromRoomId: data.fromRoomId ?? null, toRoomId: data.toRoomId ?? null }; movements.push(row); return row; },
      findMany: async () => movements,
    },
    inventoryLocalStockReceipt: {
      findUnique: async ({ where }: Row) => receipts.find((r) => r.id === where.id) ?? null,
      create: async ({ data }: Row) => { receipts.push(data); return data; },
    },
    inventoryRoomCheckout: { findUnique: async ({where}: Row) => where.saleId === 'replay-sale' ? {picks: [{productId: 'p', roomId: 'a', quantity: 3}]} : null },
    posSale: { findUnique: async ({where}: Row) => where.receiptNumber === 'POS-33333333-3333-4333-8333-333333333333' ? {
      id: 'replay-sale', receiptNumber: where.receiptNumber, invoiceNumber: 'RPGS-INV-2026-000001',
      customerName: null, customerPhone: null, status: 'COMPLETED', paymentMethod: 'CASH', paymentStatus: 'COMPLETED',
      subtotal: 30, total: 30, paidAmount: 30, discount: 0, vatRate: 0, vatAmount: 0, refundedAmount: 0,
      createdAt: new Date(), shift: {cashierId: 'fixture-cashier'}, paymentCollections: [],
      items: [{id:'line', productId:'p', productName:'Fixture', sku:'P', quantity:3, weightGrams:null, unitPrice:10, lineTotal:30}],
    } : null },
    inventory: { findUnique: async () => ({ totalStock: total, reservedStock: 0 }), findMany: async () => [{ productId: 'p', totalStock: total, reservedStock: 0, product: { id: 'p', name: 'Fixture', sku: 'P', barcode: null, price: 10, unitLabel: 'pcs' } }] },
    wholesaleItem: { findMany: async () => [] },
    inventoryBatch: { updateMany: async () => ({ count: 1 }) },
    inventoryTransaction: { create: async () => ({}) },
    $queryRaw: async (query: TemplateStringsArray) => query.join('').includes('InventoryBatch') ? [{ id: 'batch', remainingQuantity: total + 20 }] : [{ totalStock: total }],
    $executeRaw: async (_query: unknown, ...values: unknown[]) => { const q = Number(values[0]); if (q > total) return 0; total -= q; return 1; },
  };
  const prisma = { ...tx, $transaction: async (work: (t: unknown) => Promise<unknown>) => {
    const before = structuredClone({ stocks, movements, receipts, total });
    try { return await work(tx); } catch (error) { ({ stocks, movements, receipts, total } = before); throw error; }
  } } as unknown as PrismaClient;
  const transaction = tx as unknown as Prisma.TransactionClient;
  const original = structuredClone(stocks);
  await consumeRoomStock(transaction, 'p', 4, 10, 'order', undefined, undefined, 'ORDER');
  assert.equal(stocks[0].quantity, 4, 'automatic orders use two unassigned units first');
  assert.equal(stocks[1].quantity, 2);
  stocks = structuredClone(original); movements = [];
  await assert.rejects(consumeRoomStock(transaction, 'p', 2, 10, 'bad', 'cashier', [{ productId: 'p', roomId: 'a', quantity: 1 }]), RoomInventoryError);
  await assert.rejects(consumeRoomStock(transaction, 'p', 7, 10, 'bad', 'cashier', [{ productId: 'p', roomId: 'a', quantity: 7 }]), RoomInventoryError);
  await assert.rejects(consumeRoomStock(transaction, 'p', 2, 10, 'bad', 'cashier', [{ productId: 'p', roomId: 'a', quantity: 1 }, { productId: 'p', roomId: 'a', quantity: 1 }]), RoomInventoryError);
  assert.equal(movements.length, 0);
  await new InventoryService(prisma).consumeStockForPosSale(transaction, [{ productId: 'p', quantity: 3 }], 'sale', 'cashier', [
    { productId: 'p', roomId: 'a', quantity: 2 }, { productId: 'p', roomId: 'b', quantity: 1 },
  ]);
  assert.equal(total, 7); assert.deepEqual(stocks.map((r) => r.quantity), [4, 1]);
  await assert.rejects(prisma.$transaction((t) => new InventoryService(prisma).consumeStockForPosSale(t, [{ productId: 'p', quantity: 2 }], 'bad', 'cashier', [{ productId: 'p', roomId: 'b', quantity: 2 }])));
  assert.equal(total, 7, 'room failure rolls back aggregate stock too');

  stocks = structuredClone(original); movements = []; total = 10;
  const app = express(); app.use(express.json());
  app.use((req, res, next) => { res.locals.authenticatedUserId = 'fixture-cashier'; res.locals.role = req.headers['x-role']; next(); });
  app.use('/rooms', createRoomInventoryRouter(prisma, (_req, res, next) => res.locals.role === 'admin' ? next() : void res.status(403).json({ error: 'Administrator access required.' })));
  app.use('/billing', createAdminBillingRouter(prisma, new InventoryService(prisma)));
  const server = app.listen(0, '127.0.0.1');
  await new Promise<void>((resolve) => server.once('listening', resolve));
  const address = server.address(); assert(address && typeof address === 'object');
  const base = `http://127.0.0.1:${address.port}/rooms`;
  const post = (path: string, body: Row, role = 'admin') => fetch(base + path, { method: 'POST', headers: { 'content-type': 'application/json', 'x-role': role }, body: JSON.stringify(body) });
  try {
    assert.equal((await fetch(base)).status, 200);
    assert.equal((await post('', { name: 'Secret', number: '03' }, 'staff')).status, 403);
    assert.equal((await post('/transfers', { quantity: -1 }, 'admin')).status, 400);
    const move = { requestId: '11111111-1111-4111-8111-111111111111', productId: 'p', fromRoomId: 'a', toRoomId: 'b', quantity: 2 };
    assert.equal((await post('/transfers', move)).status, 200);
    assert.equal((await post('/transfers', move)).status, 200);
    assert.deepEqual(stocks.map((r) => r.quantity), [4, 4]); assert.equal(total, 10);
    assert.equal((await post('/transfers', { ...move, quantity: 1 })).status, 409);
    const local = { requestId: '22222222-2222-4222-8222-222222222222', items: [{ productId: 'p', quantity: 2, sku: 'P' }], roomPicks: [{ productId: 'p', roomId: 'b', quantity: 2 }] };
    assert.equal((await post('/local-sales', local, 'staff')).status, 403);
    assert.equal((await post('/local-sales', local)).status, 200);
    assert.equal((await post('/local-sales', local)).status, 200);
    assert.equal(total, 8); assert.equal(receipts.length, 1); assert.equal(stocks[1].quantity, 2);
    assert.equal((await post('/local-sales', { ...local, items: [{ productId: 'p', quantity: 3, sku: 'P' }] })).status, 409);
    assert.equal(total, 8);
    assert(!JSON.stringify(receipts).includes('customerName'));
    const replayBody = { idempotencyKey:'33333333-3333-4333-8333-333333333333', items:[{productId:'p',quantity:3}], paymentMethod:'CASH', quote:{expectedTotal:30,unitPrices:{p:10}}, roomPicks:[{productId:'p',roomId:'a',quantity:3}] };
    const replay = (body: Row) => fetch(`http://127.0.0.1:${address.port}/billing/sales`, {method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(body)});
    assert.equal((await replay(replayBody)).status, 200);
    assert.equal((await replay({...replayBody,roomPicks:[{productId:'p',roomId:'b',quantity:3}]})).status, 409);
    assert.equal(total, 8, 'a sale replay never consumes room or total stock again');
  } finally { await new Promise<void>((resolve) => server.close(() => resolve())); }
  console.log('Room inventory: split picks, exact quantities, rollback, automatic order picking, permissions, transfers, stock-only receipts and duplicate protection passed.');
}
void main().catch((error) => { console.error(error); process.exitCode = 1; });
