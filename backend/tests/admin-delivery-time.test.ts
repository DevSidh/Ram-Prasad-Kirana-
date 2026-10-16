import assert from 'node:assert/strict';
import express, { type RequestHandler } from 'express';
import type { PrismaClient } from '@prisma/client';
import { createAdminRouter } from '../src/routes/admin.js';

let orderStatus = 'PROCESSING';
let savedTime: Date | null = null;
let updateCount = 1;

const transaction = {
  order: {
    findUnique: async () => ({ status: orderStatus }),
    updateMany: async ({
      data,
    }: {
      data: { scheduledDeliveryAt: Date | null };
    }) => {
      if (updateCount === 1) savedTime = data.scheduledDeliveryAt;
      return { count: updateCount };
    },
  },
};
const prisma = {
  $transaction: async <T>(
    callback: (client: typeof transaction) => Promise<T>,
  ) => callback(transaction),
} as unknown as PrismaClient;

const authenticate: RequestHandler = (_req, res, next) => {
  res.locals.authenticatedUserId = 'admin-1';
  next();
};

const requireAdmin: RequestHandler = (_req, _res, next) => next();
const app = express();
app.use(express.json());
app.use('/admin', createAdminRouter(prisma, authenticate, requireAdmin));

async function run(): Promise<void> {
  const server = app.listen(0);
  try {
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const address = server.address();
    assert(address && typeof address !== 'string');
    const endpoint =
      `http://127.0.0.1:${address.port}/admin/orders/order-1/delivery-time`;
    const future = new Date(Date.now() + 60_000);

    const saved = await fetch(endpoint, {
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ scheduledDeliveryAt: future.toISOString() }),
    });
    assert.equal(saved.status, 200);
    assert.equal(savedTime?.toISOString(), future.toISOString());
    assert.deepEqual(await saved.json(), {
      message: 'Delivery time updated.',
      id: 'order-1',
      scheduledDeliveryAt: future.toISOString(),
    });

    const past = await fetch(endpoint, {
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        scheduledDeliveryAt: new Date(Date.now() - 60_000).toISOString(),
      }),
    });
    assert.equal(past.status, 400);

    orderStatus = 'DELIVERED';
    const closed = await fetch(endpoint, {
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ scheduledDeliveryAt: future.toISOString() }),
    });
    assert.equal(closed.status, 409);

    orderStatus = 'PROCESSING';
    const cleared = await fetch(endpoint, {
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ scheduledDeliveryAt: null }),
    });
    assert.equal(cleared.status, 200);
    assert.equal(savedTime, null);
    console.log('Admin scheduled delivery time tests passed.');
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
    });
  }
}

run().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
