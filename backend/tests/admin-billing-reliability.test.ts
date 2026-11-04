import assert from 'node:assert/strict';
import express from 'express';
import type { PrismaClient } from '@prisma/client';
import type { InventoryService } from '../src/services/inventory.js';
import { createAdminBillingRouter } from '../src/routes/admin-billing.js';

// In-memory isolated transaction harness; never connects to a business database.
type Row = Record<string, any>;
async function main(): Promise<void> {
  let stock = 10;
  let price = 10;
  let stockWrites = 0;
  let sequence = 0;
  let sales = new Map<string, Row>();
  let payments = new Map<string, Row>();
  let shifts: Row[] = [];
  const tx = {
    posSale: {
      findUnique: async ({ where }: Row) => [...sales.values()].find((sale) =>
        where.id ? sale.id === where.id : sale.receiptNumber === where.receiptNumber) ?? null,
      create: async ({ data }: Row) => {
        const sale: Row = { ...data, id: `sale-${sales.size + 1}`, status: 'COMPLETED',
          refundedAmount: 0, createdAt: data.createdAt ?? new Date(),
          shift: { cashierId: 'admin-1' },
          items: data.items.create.map((item: Row, i: number) => ({ ...item, id: `item-${i}` })),
          paymentCollections: [], refunds: [], exchanges: [],
        };
        if (data.paymentCollections) {
          const payment = { ...data.paymentCollections.create, id: `initial-${sale.id}`,
            saleId: sale.id, note: null, createdAt: data.paymentCollections.create.createdAt ?? new Date() };
          payments.set(payment.id, payment);
          sale.paymentCollections = [payment];
        }
        sales.set(sale.id, sale);
        return sale;
      },
      updateMany: async ({ where, data }: Row) => {
        const sale = sales.get(where.id);
        if (!sale || sale.paidAmount !== where.paidAmount || sale.paymentStatus !== 'PENDING') return { count: 0 };
        Object.assign(sale, data);
        return { count: 1 };
      },
    },
    posShift: {
      findFirst: async () => shifts.find((shift) => shift.status === 'OPEN') ?? null,
      create: async ({ data }: Row) => {
        const shift = { id: `shift-${shifts.length}`, status: 'OPEN', ...data };
        shifts.push(shift);
        return shift;
      },
    },
    product: { findMany: async () => [{ id: 'tea', name: 'Tea', sku: 'TEST-TEA',
      price, unitLabel: '1 pc', inventory: { totalStock: stock, reservedStock: 0 } }] },
    invoiceSequence: { upsert: async () => ({ nextNumber: ++sequence }) },
    posPaymentCollection: {
      findUnique: async ({ where }: Row) => payments.get(where.id) ?? null,
      create: async ({ data }: Row) => {
        const payment = { ...data, note: data.note ?? null, createdAt: new Date() };
        payments.set(data.id, payment);
        return payment;
      },
    },
    posRefund: { create: async ({ data }: Row) => {
      const refund = { ...data, id: 'refund-test', status: 'REQUESTED' };
      sales.get(data.saleId)!.refunds.push(refund);
      return refund;
    } },
  };
  const prisma = {
    ...tx,
    $transaction: async (operation: (transaction: unknown) => Promise<unknown>) => {
      const before = structuredClone({ stock, stockWrites, sequence, sales, payments, shifts });
      try { return await operation(tx); } catch (error) {
        ({ stock, stockWrites, sequence, sales, payments, shifts } = before);
        throw error;
      }
    },
  } as unknown as PrismaClient;
  const inventory = { consumeStockForPosSale: async (_tx: unknown, items: Row[]) => {
    stock -= items.reduce((sum, item) => sum + item.quantity, 0); stockWrites++;
  } } as unknown as InventoryService;
  const app = express();
  app.use(express.json());
  app.use('/billing', (_req, res, next) => {
    res.locals.authenticatedUserId = _req.header('x-actor') ?? 'admin-1';
    res.locals.authenticatedUserRole = _req.header('x-role') ?? 'ADMIN';
    next();
  }, createAdminBillingRouter(prisma, inventory, (req, res, next) =>
    req.header('x-role') === 'BILLING_STAFF'
      ? res.status(403).json({ error: 'Administrator access required' }) : next()));
  const server = app.listen(0);
  try {
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const address = server.address();
    assert(address && typeof address !== 'string');
    const post = (path: string, body: Row, headers: Row = {}) => fetch(
      `http://127.0.0.1:${address.port}/billing${path}`, {
        method: 'POST', headers: { 'content-type': 'application/json', ...headers }, body: JSON.stringify(body),
      });
    const key = '550e8400-e29b-41d4-a716-446655440000';
    const offline = (id = key) => ({
      idempotencyKey: id, items: [{ productId: 'tea', quantity: 2 }],
      discount: 0, paymentMethod: 'CASH',
      offlineSale: { invoiceNumber: `RPGS-INV-2020-L-${id.replaceAll('-', '').toUpperCase()}`,
        occurredAt: '2020-01-02T06:00:00.000Z', expectedTotal: 20, unitPrices: { tea: 10 } },
    });
    const first = await post('/sales', offline());
    assert.equal(first.status, 201);
    const committed = (await first.json() as Row).sale;
    assert.equal(committed.invoiceNumber, offline().offlineSale.invoiceNumber);
    assert.equal(committed.createdAt, '2020-01-02T06:00:00.000Z');
    assert.equal(shifts[0].status, 'CLOSED');
    assert.equal(shifts[0].expectedClosingCash, 20);
    assert.equal(shifts[0].actualClosingCash, undefined);
    assert.equal((await post('/sales', offline())).status, 200);
    assert.equal(stock, 8);
    assert.equal(stockWrites, 1);
    assert.equal((await post('/sales', { ...offline(), items: [{ productId: 'tea', quantity: 1 }] })).status, 409);
    price = 12;
    assert.equal((await post('/sales', offline('550e8400-e29b-41d4-a716-446655440001'))).status, 409);
    assert.equal(stockWrites, 1);
    assert.equal(committed.items[0].unitPrice, 10);
    assert.equal((await post('/sales', offline(), { 'x-role': 'BILLING_STAFF' })).status, 403);
    assert.equal((await post('/sales', { ...offline(), paymentMethod: 'DIGITAL' })).status, 403);

    price = 10;
    // Cached lookups are fast, but a sale must retain the cashier's quote.
    const quoted = {
      idempotencyKey: '550e8400-e29b-41d4-a716-446655440010',
      items: [{ productId: 'tea', quantity: 1 }], paymentMethod: 'CASH',
      quote: { expectedTotal: 10, unitPrices: { tea: 9 } },
    };
    assert.equal((await post('/sales', quoted)).status, 409);
    assert.equal(stockWrites, 1);
    assert.equal((await post('/sales', { ...quoted,
      quote: { expectedTotal: 9, unitPrices: { tea: 10 } },
    })).status, 409);
    assert.equal(stockWrites, 1);
    assert.equal((await post('/sales', { ...quoted,
      quote: { expectedTotal: 10, unitPrices: { tea: 10 } },
    })).status, 201);
    assert.equal(stockWrites, 2);
    const pending = await post('/sales', {
      idempotencyKey: '550e8400-e29b-41d4-a716-446655440002', items: [{ productId: 'tea', quantity: 2 }],
      paymentMethod: 'PENDING', paidAmount: 5, customerName: 'Test', customerPhone: '9800000000',
    });
    assert.equal(pending.status, 201);
    const sale = (await pending.json() as Row).sale;
    assert.equal((await post(`/sales/${sale.id}/refunds`, { amount: 6, reason: 'Test refund' })).status, 409);
    assert.equal((await post(`/sales/${sale.id}/refunds`, { amount: 3, reason: 'Test refund' })).status, 201);
    assert.equal((await post(`/sales/${sale.id}/refunds`, { amount: 3, reason: 'Test retry refund' })).status, 409);
    assert.equal(sales.get(sale.id)?.refunds.length, 1);
    assert.equal((await post(`/sales/${sale.id}/refunds`, { amount: 1, reason: 'Test refund' }, { 'x-role': 'BILLING_STAFF' })).status, 403);
    const payment = { amount: 15, paymentMethod: 'CASH',
      idempotencyKey: '550e8400-e29b-41d4-a716-446655440003' };
    assert.equal((await post(`/sales/${sale.id}/payments`, payment)).status, 201);
    assert.equal((await post(`/sales/${sale.id}/payments`, payment)).status, 200);
    assert.equal(sales.get(sale.id)?.paidAmount, 20);
    assert.equal(sales.get(sale.id)?.paymentStatus, 'COMPLETED');
    assert.equal((await post(`/sales/${sale.id}/payments`, { ...payment, amount: 10 })).status, 409);
    assert.equal((await post(`/sales/${sale.id}/payments`, payment, { 'x-actor': 'other' })).status, 409);
    assert.equal([...payments.keys()].filter((id) => id.startsWith('PPC-')).length, 1);
    console.log('Offline replay, price conflicts, staff restrictions, payment idempotency and received-funds refund limits passed.');
  } finally {
    await new Promise<void>((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  }
}
main().catch((error) => { console.error(error); process.exitCode = 1; });
