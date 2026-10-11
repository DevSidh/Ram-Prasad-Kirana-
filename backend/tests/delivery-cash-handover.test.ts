import assert from 'node:assert/strict';
import express, { type RequestHandler } from 'express';
import type { PrismaClient } from '@prisma/client';
import { createAdminRouter } from '../src/routes/admin.js';

const deliveries = [
  {
    id: 'delivery-1',
    status: 'DELIVERED',
    cashCollected: 1250,
    cashHandedOver: 0,
    cashHandedOverAt: null as Date | null,
    deliveredAt: new Date('2026-10-12T10:00:00.000Z'),
    deliveryPerson: { id: 'rider-1', name: 'Ram' },
    order: { orderNumber: 'FH-1001' },
  },
];
const auditEntries: Array<{ changedById: string; note: string }> = [];
const prisma = {
  delivery: {
    findMany: async () => deliveries.filter((delivery) =>
      delivery.status === 'DELIVERED' && delivery.cashHandedOverAt === null),
    findUnique: async ({ where }: { where: { id: string } }) =>
      deliveries.find((delivery) => delivery.id === where.id) ?? null,
    updateMany: async ({
      where,
      data,
    }: {
      where: { id: string; status: string; cashHandedOverAt: null };
      data: { cashHandedOver: number; cashHandedOverAt: Date };
    }) => {
      const delivery = deliveries.find((candidate) =>
        candidate.id === where.id &&
        candidate.status === where.status &&
        candidate.cashHandedOverAt === where.cashHandedOverAt);
      if (!delivery) return { count: 0 };
      Object.assign(delivery, data);
      return { count: 1 };
    },
  },
  deliveryStatusHistory: {
    create: async ({ data }: {
      data: { changedById: string; note: string };
    }) => {
      auditEntries.push(data);
    },
  },
  $transaction: async (callback: (tx: unknown) => Promise<unknown>) =>
    callback(prisma),
} as unknown as PrismaClient;
const adminMiddleware: RequestHandler = (_req, res, next) => {
  res.locals.authenticatedUserId = 'admin-1';
  next();
};
const app = express();
app.use(express.json());
app.use('/admin', createAdminRouter(prisma, adminMiddleware, adminMiddleware));

async function run(): Promise<void> {
  const server = app.listen(0);
  try {
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const address = server.address();
    assert(address && typeof address !== 'string');
    const base = `http://127.0.0.1:${address.port}/admin/delivery`;

    const pendingResponse = await fetch(`${base}/cash-pending`);
    assert.equal(pendingResponse.status, 200);
    const pendingBody = await pendingResponse.json() as {
      deliveries: Array<{
        id: string;
        orderNumber: string;
        deliveryPersonName: string;
        cashCollected: number;
      }>;
    };
    assert.deepEqual(pendingBody.deliveries, [{
      id: 'delivery-1',
      orderNumber: 'FH-1001',
      deliveryPersonName: 'Ram',
      cashCollected: 1250,
      deliveredAt: '2026-10-12T10:00:00.000Z',
    }]);

    const confirmResponse = await fetch(
      `${base}/delivery-1/cash-handover`,
      { method: 'PATCH' },
    );
    assert.equal(confirmResponse.status, 200);
    assert.equal(deliveries[0].cashHandedOver, 1250);
    assert(deliveries[0].cashHandedOverAt instanceof Date);
    assert.equal(auditEntries.length, 1);
    assert.equal(auditEntries[0].changedById, 'admin-1');
    assert.match(auditEntries[0].note, /Rs\. 1250\.00/);

    const repeatResponse = await fetch(
      `${base}/delivery-1/cash-handover`,
      { method: 'PATCH' },
    );
    assert.equal(repeatResponse.status, 409);
    assert.equal(auditEntries.length, 1, 'repeat confirmation must not duplicate the receipt');

    console.log('Delivery customer-cash handover tests passed.');
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
    });
  }
}

void run().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
