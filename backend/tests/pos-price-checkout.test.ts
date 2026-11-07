import assert from 'node:assert/strict';
import express, {type RequestHandler} from 'express';
import type {PrismaClient} from '@prisma/client';
import {createAdminBillingRouter} from '../src/routes/admin-billing.js';
import type {InventoryService} from '../src/services/inventory.js';

async function main() {
  let price = 100;
  let stock = 50;
  let sequence = 0;
  let writes = 0;
  const sales = new Map<string, any>();
  const ledger = new Map<string, any>();
  const tx = {
    product: {
      findMany: async () => [{id: 'bhujiya', name: 'Bhujiya', sku: 'BHUJIYA', price, unitLabel: 'pcs', inventory: {totalStock: stock, reservedStock: 0}}],
      updateMany: async ({where, data}: any) => {if (where.price !== price) return {count: 0}; price = data.price; return {count: 1};},
    },
    posCataloguePriceChange: {
      findUnique: async ({where}: any) => ledger.get(where.requestId),
      create: async ({data}: any) => {ledger.set(data.requestId, data); return data;},
    },
    posShift: {findFirst: async () => ({id: 'shift', cashierId: 'admin', status: 'OPEN'})},
    invoiceSequence: {upsert: async ({create}: any) => ({year: create.year, nextNumber: ++sequence})},
    posSale: {
      findUnique: async ({where}: any) => sales.get(where.receiptNumber),
      create: async ({data}: any) => {
        writes++;
        const sale = {...data, id: `sale-${writes}`, createdAt: new Date(), refundedAmount: 0,
          shift: {cashierId: 'admin'}, items: data.items.create,
          paymentCollections: data.paymentCollections?.create ? [{...data.paymentCollections.create, id: 'payment', createdAt: new Date()}] : []};
        sales.set(data.receiptNumber, sale); return sale;
      },
    },
  };
  const prisma = {$transaction: async (work: (tx: any) => unknown) => {
    const old = {price, stock, sequence, writes, sales: new Map(sales), ledger: new Map(ledger)};
    try {return await work(tx);} catch (error) {
      ({price, stock, sequence, writes} = old);
      sales.clear(); old.sales.forEach((v, k) => sales.set(k, v));
      ledger.clear(); old.ledger.forEach((v, k) => ledger.set(k, v));
      throw error;
    }
  }} as unknown as PrismaClient;
  const inventory = {consumeStockForPosSale: async (_tx: unknown, items: Array<{quantity: number}>) => {
    stock -= items.reduce((sum, item) => sum + item.quantity, 0);
  }} as unknown as InventoryService;
  const adminOnly: RequestHandler = (_req, res, next) => res.locals.authenticatedUserRole === 'ADMIN' ? next() : res.sendStatus(403);
  const app = express(); app.use(express.json());
  app.use((req, res, next) => {res.locals.authenticatedUserId = 'admin'; res.locals.authenticatedUserRole = req.header('x-role') ?? 'ADMIN'; next();});
  app.use('/billing', createAdminBillingRouter(prisma, inventory, adminOnly));
  const server = app.listen(0);
  try {
    await new Promise<void>(resolve => server.once('listening', resolve));
    const address = server.address(); assert(address && typeof address !== 'string');
    const base = `http://127.0.0.1:${address.port}/billing`;
    const request = (path: string, body: unknown, role = 'ADMIN') => fetch(`${base}/${path}`, {
      method: 'POST', headers: {'content-type': 'application/json', 'x-role': role}, body: JSON.stringify(body),
    });
    const bill = {idempotencyKey: '550e8400-e29b-41d4-a716-446655440001',
      items: [{productId: 'bhujiya', quantity: 10}], discount: 0, vatRate: 0, paymentMethod: 'CASH',
      cataloguePriceChanges: [{productId: 'bhujiya', expectedPrice: 100, price: 110}],
      quote: {expectedTotal: 1100, unitPrices: {bhujiya: 110}}};
    assert.equal((await request('sales', bill, 'BILLING_STAFF')).status, 403);
    assert.equal(price, 100);
    assert.equal((await request('sales', {...bill, quote: {...bill.quote, expectedTotal: 1000}})).status, 409);
    assert.equal(price, 100, 'An invalid total must roll back catalogue changes.');
    assert.equal(ledger.size, 0);
    const result = await request('sales', bill);
    assert.equal(result.status, 201, await result.clone().text());
    const saved = (await result.json() as any).sale;
    assert.equal(saved.total, 1100);
    assert.equal(Number(saved.items[0].unitPrice), 110);
    assert.equal(price, 110);
    assert.equal(stock, 40);
    assert.equal((await request('sales', bill)).status, 200);
    assert.equal(writes, 1); assert.equal(stock, 40);
    assert.equal((await request('catalogue-price-changes', {requestId: bill.idempotencyKey, changes: bill.cataloguePriceChanges})).status, 200);
    assert.equal((await request('catalogue-price-changes', {requestId: bill.idempotencyKey, changes: bill.cataloguePriceChanges}, 'BILLING_STAFF')).status, 403);
    assert.equal(writes, 1);
    console.log('POS checkout price changes: totals, stock, rollback, replay, local sync and staff authorization passed (isolated transaction fixture).');
  } finally {await new Promise<void>((resolve, reject) => server.close(error => error ? reject(error) : resolve()));}
}
main().catch(error => {console.error(error); process.exitCode = 1;});
