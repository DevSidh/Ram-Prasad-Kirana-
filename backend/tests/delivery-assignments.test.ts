import assert from 'node:assert/strict';
import express from 'express';
import jwt from 'jsonwebtoken';
import type { PrismaClient } from '@prisma/client';
import { createAuthMiddleware } from '../src/middleware/auth.js';
import { createDeliveryRouter } from '../src/routes/delivery.js';

const secret = 'delivery-tests-use-a-random-independent-secret';
const users = new Map([
  ['rider-1', { role: 'DELIVERY_PERSON', isActive: true, tokenVersion: 0 }],
  ['rider-2', { role: 'DELIVERY_PERSON', isActive: true, tokenVersion: 0 }],
  ['customer-1', { role: 'CUSTOMER', isActive: true, tokenVersion: 0 }],
]);
const date = new Date('2026-10-09T10:00:00.000Z');
const deliveryRecord = {
  id: 'delivery-1',
  deliveryPersonId: 'rider-1',
  status: 'ASSIGNED',
  assignedAt: date,
  pickedUpAt: null as Date | null,
  deliveredAt: null as Date | null,
  cashCollected: 0,
  cashCollectedAt: null as Date | null,
  cashHandedOver: 0,
  cashHandedOverAt: null as Date | null,
  statusHistory: [] as Array<{ status: string; note: string | null; createdAt: Date }>,
  order: {
    id: 'order-1',
    orderNumber: 'FH-1001',
    status: 'PROCESSING',
    paymentMethod: 'COD',
    paymentStatus: 'PENDING',
    total: 1250,
    shippingName: 'Asha',
    shippingPhone: '9800000000',
    shippingAddress: 'Main Road',
    shippingCity: 'Janakpur',
    shippingDistrict: null,
    shippingProvince: null,
    shippingPostalCode: null,
    notes: null,
    createdAt: date,
    user: { name: 'Asha', phone: '9800000000' },
    address: { latitude: 26.728, longitude: 85.925 },
    payments: [],
    items: [{ productName: 'Rice', quantity: 2 }],
  },
};
const records = [
  deliveryRecord,
  {
    id: 'delivery-2',
    status: 'ASSIGNED',
    assignedAt: date,
    pickedUpAt: null,
    deliveredAt: null,
    cashCollected: 0,
    cashCollectedAt: null,
    cashHandedOver: 0,
    cashHandedOverAt: null,
    statusHistory: [],
    order: {
      id: 'order-2',
      orderNumber: 'FH-1002',
      status: 'PROCESSING',
      paymentMethod: 'COD',
      paymentStatus: 'PENDING',
      total: 150,
      shippingName: 'Bikash',
      shippingPhone: '9800000001',
      shippingAddress: 'Market Street',
      shippingCity: 'Janakpur',
      shippingDistrict: null,
      shippingProvince: null,
      shippingPostalCode: null,
      notes: null,
      createdAt: date,
      user: { name: 'Bikash', phone: '9800000001' },
      address: null,
      payments: [],
      items: [],
    },
  },
];
let lastWhere: Record<string, unknown> | undefined;
const prisma = {
  user: {
    findUnique: async ({ where }: { where: { id: string } }) =>
      users.get(where.id) ?? null,
  },
  delivery: {
    findMany: async ({ where }: { where: Record<string, unknown> }) => {
      lastWhere = where;
      return records.filter(
        (record) => record.id === (where.deliveryPersonId === 'rider-1'
          ? 'delivery-1'
          : 'delivery-2'),
      );
    },
    aggregate: async () => ({
      _sum: {
        cashCollected: deliveryRecord.status === 'DELIVERED' &&
            deliveryRecord.cashHandedOverAt === null
          ? deliveryRecord.cashCollected
          : 0,
      },
    }),
    findFirst: async ({ where }: { where: { id: string; deliveryPersonId: string } }) =>
      deliveryRecord.id === where.id &&
        deliveryRecord.deliveryPersonId === where.deliveryPersonId
        ? deliveryRecord
        : null,
    updateMany: async ({
      where,
      data,
    }: {
      where: { id: string; deliveryPersonId: string; status: string };
      data: Record<string, unknown>;
    }) => {
      if (
        where.id !== deliveryRecord.id ||
        where.deliveryPersonId !== deliveryRecord.deliveryPersonId ||
        where.status !== deliveryRecord.status
      ) return { count: 0 };
      Object.assign(deliveryRecord, data);
      return { count: 1 };
    },
    statusHistory: {
      create: async ({ data }: { data: { status: string; note: string } }) => {
        deliveryRecord.statusHistory.unshift({
          ...data,
          createdAt: new Date(),
        });
      },
    },
  },
  deliveryStatusHistory: {
    create: async ({ data }: {
      data: { status: string; note: string };
    }) => {
      deliveryRecord.statusHistory.unshift({
        ...data,
        createdAt: new Date(),
      });
    },
  },
  order: {
    update: async ({ where, data }: {
      where: { id: string };
      data: { status: string; paymentStatus?: string };
    }) => {
      assert.equal(where.id, deliveryRecord.order.id);
      Object.assign(deliveryRecord.order, data);
    },
  },
  orderStatusHistory: { create: async () => undefined },
  notification: { create: async () => undefined },
  $transaction: async (callback: (tx: unknown) => Promise<unknown>) =>
    callback(prisma),
} as unknown as PrismaClient;
const { authenticateToken, requireDeliveryPerson } =
  createAuthMiddleware(prisma, secret);
const app = express();
app.use(express.json());
app.use(
  '/delivery',
  createDeliveryRouter(prisma, authenticateToken, requireDeliveryPerson),
);

async function run(): Promise<void> {
  const server = app.listen(0);
  try {
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const address = server.address();
    assert(address && typeof address !== 'string');
    const endpoint = `http://127.0.0.1:${address.port}/delivery/assignments`;
    const request = (userId: string) => fetch(endpoint, {
      headers: {
        authorization: `Bearer ${jwt.sign({ id: userId }, secret)}`,
      },
    });

    const riderResponse = await request('rider-1');
    assert.equal(riderResponse.status, 200);
    const riderBody = await riderResponse.json() as {
      assignments: Array<{
        order: {
          orderNumber: string;
          cashDue: number;
          customerName: string;
          customerPhone: string;
          address: string;
          latitude: number | null;
          longitude: number | null;
          instructions: string;
          items: Array<{ name: string; quantity: number }>;
        };
      }>;
      summary: { cashToCollect: number };
    };
    assert.deepEqual(riderBody.assignments.map(({ order }) => order.orderNumber), ['FH-1001']);
    assert.equal(riderBody.assignments[0].order.cashDue, 1250);
    assert.equal(riderBody.assignments[0].order.customerName, 'Asha');
    assert.equal(riderBody.assignments[0].order.customerPhone, '9800000000');
    assert.equal(riderBody.assignments[0].order.address, 'Main Road, Janakpur');
    assert.equal(riderBody.assignments[0].order.latitude, 26.728);
    assert.equal(riderBody.assignments[0].order.longitude, 85.925);
    assert.deepEqual(riderBody.assignments[0].order.items, [{ name: 'Rice', quantity: 2 }]);
    assert.equal(riderBody.summary.cashToCollect, 1250);
    assert.equal(lastWhere?.deliveryPersonId, 'rider-1');
    assert.equal((await request('customer-1')).status, 403);

    const assignmentEndpoint = `${endpoint}/delivery-1`;
    const patch = (body: Record<string, unknown>) => fetch(assignmentEndpoint, {
      method: 'PATCH',
      headers: {
        authorization: `Bearer ${jwt.sign({ id: 'rider-1' }, secret)}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify(body),
    });
    assert.equal((await patch({ status: 'ACCEPTED' })).status, 200);
    assert.equal((await patch({ status: 'PICKED_UP' })).status, 200);
    assert.equal((await patch({ status: 'OUT_FOR_DELIVERY' })).status, 200);
    const wrongCash = await patch({
      status: 'DELIVERED',
      recipientName: 'Asha',
      cashCollected: 1200,
    });
    assert.equal(wrongCash.status, 400, 'COD must match the amount due exactly');
    assert.equal(deliveryRecord.status, 'OUT_FOR_DELIVERY');
    assert.equal((await patch({
      status: 'DELIVERED',
      recipientName: 'Asha',
      cashCollected: 1250,
    })).status, 200);
    assert.equal(deliveryRecord.status, 'DELIVERED');
    assert.equal(deliveryRecord.order.status, 'DELIVERED');
    assert.equal(deliveryRecord.order.paymentStatus, 'COMPLETED');
    assert.equal(deliveryRecord.cashCollected, 1250);
    const deliveredOverview = await request('rider-1');
    const deliveredBody = await deliveredOverview.json() as {
      summary: { cashToHandOver: number };
      assignments: Array<{ cashHandedOver: number; cashHandedOverAt: string | null }>;
    };
    assert.equal(deliveredBody.summary.cashToHandOver, 1250);
    assert.equal(deliveredBody.assignments[0].cashHandedOver, 0);
    assert.equal(deliveredBody.assignments[0].cashHandedOverAt, null);

    console.log('Delivery assignment scoping tests passed.');
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
    });
  }
}

void run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
