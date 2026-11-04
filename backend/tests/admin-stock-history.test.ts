import assert from 'node:assert/strict';
import express, { type RequestHandler } from 'express';
import type { PrismaClient } from '@prisma/client';
import { createAdminRouter } from '../src/routes/admin.js';

async function main(): Promise<void> {
  let query: Record<string, any> = {};
  const prisma = { inventoryTransaction: {
    count: async () => 1,
    findMany: async (input: Record<string, any>) => {
      query = input;
      return [{ id: 'movement-test', quantity: 2000, balanceAfter: 5000,
        type: 'PURCHASED', referenceId: 'sale-test', notes: 'Test sale',
        createdAt: new Date('2020-01-02T06:00:00.000Z'),
        performedBy: { id: 'test-admin', name: 'Cashier test' },
        inventory: { product: { id: 'tea', name: 'Tea', sku: 'TEST-TEA', unitLabel: '1 kg' } },
      }];
    },
  } } as unknown as PrismaClient;
  const allow: RequestHandler = (_req, _res, next) => next();
  const admin: RequestHandler = (req, res, next) => req.header('x-role') === 'staff'
    ? res.status(403).json({ error: 'Administrator access required' }) : next();
  const app = express();
  app.use('/admin', createAdminRouter(prisma, allow, admin));
  const server = app.listen(0);
  try {
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const address = server.address();
    assert(address && typeof address !== 'string');
    const url = `http://127.0.0.1:${address.port}/admin/inventory/restock-history`;
    assert.equal((await fetch(url)).status, 200);
    assert.equal(query.where.type, 'RESTOCKED');
    const all = await fetch(`${url}?movementType=ALL&search=Tea&day=2020-01-02`);
    assert.equal(all.status, 200);
    assert.equal(query.where.type, undefined);
    assert.equal(query.where.OR.length, 5);
    assert.equal(query.where.createdAt.gte.toISOString(), '2020-01-01T18:15:00.000Z');
    assert.equal(query.select.type, true);
    assert.equal(query.select.referenceId, true);
    const body = await all.json() as Record<string, any>;
    assert.equal(body.receipts[0].quantity, 2);
    assert.equal(body.receipts[0].balanceAfter, 5);
    assert.equal(body.receipts[0].referenceId, 'sale-test');
    assert.equal(body.receipts[0].staff.name, 'Cashier test');
    assert.equal((await fetch(`${url}?movementType=INVALID`)).status, 400);
    assert.equal((await fetch(url, { headers: { 'x-role': 'staff' } })).status, 403);
    console.log('Stock movement filters, actor/reference, units and permissions passed.');
  } finally {
    await new Promise<void>((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  }
}
main().catch((error) => { console.error(error); process.exitCode = 1; });
