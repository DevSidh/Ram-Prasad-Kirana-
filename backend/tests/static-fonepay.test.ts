import assert from 'node:assert/strict';
import express, { type RequestHandler } from 'express';
import type { PrismaClient } from '@prisma/client';
import type { InventoryService } from '../src/services/inventory.js';
import { createAdminBillingRouter } from '../src/routes/admin-billing.js';
import { manualFonepayReference } from '../src/services/manual-fonepay.js';

async function main(): Promise<void> {
  const sales = new Map<string, any>();
  let writes = 0, stockDeductions = 0, sequence = 0, gatewayCalls = 0;
  const tx = {
    invoiceSequence: { upsert: async () => ({ nextNumber: ++sequence }) },
    product: { findMany: async () => [{ id: 'tea', name: 'Tea', sku: 'TEA', price: 100, unitLabel: 'pcs', inventory: { totalStock: 20, reservedStock: 0 } }] },
    posShift: { findFirst: async () => ({ id: 'shift', cashierId: 'cashier-1' }) },
    posSale: {
      findUnique: async ({ where }: any) => sales.get(where.receiptNumber) ?? null,
      create: async ({ data }: any) => {
        writes++;
        const sale = { ...data, id: `sale-${writes}`, refundedAmount: 0, createdAt: new Date(),
          shift: { cashierId: 'cashier-1' },
          items: data.items.create.map((item: any, index: number) => ({ ...item, id: `item-${index}` })),
          paymentCollections: [{ ...data.paymentCollections.create, id: `payment-${writes}` }],
        };
        sales.set(data.receiptNumber, sale);
        return sale;
      },
    },
  };
  const prisma = { $transaction: async (work: any) => work(tx) } as unknown as PrismaClient;
  const inventory = { consumeStockForPosSale: async (_tx: unknown, items: any[]) => { stockDeductions++; assert.equal(items[0].quantity, 2); } } as unknown as InventoryService;
  const app = express();
  app.use(express.json());
  const auth: RequestHandler = (req, res, next) => {
    res.locals.authenticatedUserId = req.header('x-user') ?? 'cashier-1';
    res.locals.authenticatedUserRole = req.header('x-role') ?? 'BILLING_STAFF';
    next();
  };
  app.use('/billing', auth, createAdminBillingRouter(prisma, inventory, undefined, () => { gatewayCalls++; throw new Error('No API should be used'); }));
  const server = app.listen(0);
  try {
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const address = server.address(); assert(address && typeof address !== 'string');
    const endpoint = `http://127.0.0.1:${address.port}/billing/sales`;
    const payload = { idempotencyKey: '550e8400-e29b-41d4-a716-446655440000', items: [{ productId: 'tea', quantity: 2 }],
      discount: 10, vatRate: 13, paymentMethod: 'FONEPAY', quote: { expectedTotal: 214.70, unitPrices: { tea: 100 } },
      manualVerification: { verificationMethod: 'MANUAL', confirmed: true, transactionReference: 'BANK-REF-001' } };
    const post = (body: unknown, headers = {}) => fetch(endpoint, { method: 'POST', headers: { 'content-type': 'application/json', ...headers }, body: JSON.stringify(body) });
    const response = await post(payload); assert.equal(response.status, 201);
    const { sale } = await response.json() as any;
    assert.equal(sale.paymentStatus, 'COMPLETED'); assert.equal(sale.paymentMethod, 'FONEPAY');
    assert.equal(sale.total, 214.7); assert.equal(sale.paidAmount, 214.7); assert.equal(sale.outstandingAmount, 0);
    assert.equal(sale.status, 'COMPLETED'); assert.match(sale.invoiceNumber, /^RPGS-INV-/);
    assert.equal(sale.autoPrintAllowed, true);
    const payment = sale.paymentCollections[0];
    assert.equal(manualFonepayReference(payment.note), 'BANK-REF-001');
    const audit = JSON.parse(payment.note.split('FASTSTORE_MANUAL_FONEPAY_V1:')[1]);
    assert.equal(audit.verifiedById, 'cashier-1'); assert.equal(audit.currency, 'NPR');
    assert.equal(audit.amount, 214.7); assert.equal(audit.verificationMethod, 'MANUAL');
    assert(Number.isFinite(Date.parse(audit.verifiedAt)));
    const retry = await post(payload); assert.equal(retry.status, 200);
    const replay = await retry.json() as any;
    assert.equal(replay.sale.id, sale.id); assert.equal(replay.sale.autoPrintAllowed, false);
    assert.equal(writes, 1); assert.equal(sequence, 1); assert.equal(stockDeductions, 1); assert.equal(gatewayCalls, 0);
    assert.equal((await post({ ...payload, manualVerification: { ...payload.manualVerification, transactionReference: 'DIFFERENT-REF' } })).status, 409);
    assert.equal((await post({ ...payload, manualVerification: { ...payload.manualVerification, confirmed: false } })).status, 400);
    assert.equal((await post(payload, { 'x-role': 'CUSTOMER' })).status, 403);
    assert.equal((await post(payload, { 'x-user': 'another-cashier' })).status, 409);
    assert.equal((await post({ ...payload, idempotencyKey: '550e8400-e29b-41d4-a716-446655440001', quote: { ...payload.quote, expectedTotal: 100 } })).status, 409);
    assert.equal(writes, 1); assert.equal(stockDeductions, 1);
    console.log('Manual static Fonepay verifies cashier access, exact totals, audit records and idempotency without a merchant API.');
  } finally {
    await new Promise<void>((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  }
}
void main().catch((error: unknown) => { console.error(error); process.exitCode = 1; });
