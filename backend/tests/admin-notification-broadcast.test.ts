import assert from 'node:assert/strict';
import express, { type RequestHandler } from 'express';
import type { PrismaClient } from '@prisma/client';
import { createAdminRouter } from '../src/routes/admin.js';
import { splitIntoBatches } from '../src/services/push-notifications.js';

async function main(): Promise<void> {
  const previousServiceAccount = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  process.env.FIREBASE_SERVICE_ACCOUNT_JSON = '';
  const users = [
    ...Array.from({ length: 501 }, (_, index) => ({
      id: `customer-${index}`,
      role: 'CUSTOMER',
      isActive: true,
    })),
    { id: 'inactive-customer', role: 'CUSTOMER', isActive: false },
    { id: 'admin-user', role: 'ADMIN', isActive: true },
  ];
  const createdBatches: Array<Array<Record<string, unknown>>> = [];
  const customerNotifications: Array<Record<string, unknown>> = [];
  const announcedCoupons: Array<Record<string, unknown>> = [];
  let transactionCount = 0;
  const prisma = {
    user: {
      findFirst: async ({ where }: {
        where: { id: string; role: string; isActive: boolean };
      }) => where.id === 'customer-1' &&
        where.role === 'CUSTOMER' &&
        where.isActive
        ? { id: 'customer-1' }
        : null,
      findMany: async ({ where }: {
        where: { isActive: boolean };
        select: { id: boolean };
      }) => {
        assert.deepEqual(where, { isActive: true });
        return users
          .filter((user) => user.isActive === where.isActive)
          .map(({ id }) => ({ id }));
      },
    },
    notification: {
      create: async ({ data }: { data: Record<string, unknown> }) => {
        customerNotifications.push(data);
        return { id: 'notification-1' };
      },
      createMany: async ({ data }: {
        data: Array<Record<string, unknown>>;
      }) => {
        createdBatches.push(data);
        return { count: data.length };
      },
    },
    coupon: {
      findUnique: async ({ where }: { where: { code: string } }) => {
        if (where.code === 'EXPIRED') {
          return {
            isActive: false,
            expiresAt: null,
            usageLimit: null,
            usedCount: 0,
          };
        }
        assert.equal(where.code, 'DIWALI50');
        return {
          isActive: true,
          isDeleted: false,
          productId: null,
          assignedUserId: null,
          expiresAt: null,
          usageLimit: 100,
          usedCount: 2,
        };
      },
      updateMany: async ({ where, data }: {
        where: Record<string, unknown>;
        data: Record<string, unknown>;
      }) => {
        announcedCoupons.push({ where, data });
        return { count: 1 };
      },
    },
    $transaction: async <T>(work: (tx: unknown) => Promise<T>) => {
      transactionCount++;
      return work(prisma);
    },
  } as unknown as PrismaClient;
  const adminOnly: RequestHandler = (req, res, next) => {
    if (req.header('x-admin') !== 'allowed') {
      return res.status(403).json({ error: 'Admin access is required.' });
    }
    return next();
  };
  const allow: RequestHandler = (_req, _res, next) => next();
  const app = express();
  app.use(express.json());
  app.use('/admin', createAdminRouter(prisma, allow, adminOnly));
  const server = app.listen(0);

  try {
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const address = server.address();
    assert(address && typeof address !== 'string');
    const endpoint = `http://127.0.0.1:${address.port}/admin/notifications/broadcast`;
    const customerEndpoint =
      `http://127.0.0.1:${address.port}/admin/notifications/customer`;
    const request = (body: unknown, authorized = true) => fetch(endpoint, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        ...(authorized ? { 'x-admin': 'allowed' } : {}),
      },
      body: JSON.stringify(body),
    });

    assert.equal((await request({ title: 'Hi', body: 'There' }, false)).status, 403);
    assert.equal((await request({ title: ' ', body: 'Message' })).status, 400);
    assert.equal(
      (await request({ title: 'Title', body: 'Message', extra: true })).status,
      400,
    );
    assert.equal(
      (await request({
        title: 'Expired coupon',
        body: 'Use it now',
        couponCode: 'EXPIRED',
      })).status,
      400,
    );
    const response = await request({
      title: 'Store update',
      body: 'Fresh produce is available.',
      couponCode: 'diwali50',
    });
    assert.equal(response.status, 201);
    assert.deepEqual(await response.json(), {
      recipientCount: 502,
      notificationsCreated: 502,
      pushDelivery: { available: false, sent: 0, failed: 0 },
    });
    assert.equal(transactionCount, 1);
    assert.deepEqual(announcedCoupons, [{
      where: { code: 'DIWALI50', isDeleted: false },
      data: { isAnnounced: true },
    }]);
    assert.deepEqual(createdBatches.map((batch) => batch.length), [500, 2]);
    assert.ok(createdBatches.flat().every((notification) =>
      notification.type === 'PROMOTIONAL' &&
      notification.title === 'FASTSTORE' &&
      notification.body === 'Store update\n\nFresh produce is available.' &&
      JSON.stringify(notification.metadata) ===
        JSON.stringify({ couponCode: 'DIWALI50' })));

    const targeted = await fetch(customerEndpoint, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-admin': 'allowed',
      },
      body: JSON.stringify({
        userId: 'customer-1',
        title: 'A note for you',
        body: 'Your order is ready.',
      }),
    });
    assert.equal(targeted.status, 201);
    assert.deepEqual(await targeted.json(), {
      recipientCount: 1,
      notificationsCreated: 1,
      pushDelivery: { available: false, sent: 0, failed: 0 },
    });
    assert.deepEqual(customerNotifications, [{
      userId: 'customer-1',
      type: 'PROMOTIONAL',
      title: 'FASTSTORE',
      body: 'A note for you\n\nYour order is ready.',
    }]);
    const inactiveTarget = await fetch(customerEndpoint, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-admin': 'allowed',
      },
      body: JSON.stringify({
        userId: 'inactive-customer',
        title: 'A note',
        body: 'A message',
      }),
    });
    assert.equal(inactiveTarget.status, 404);

    assert.deepEqual(
      splitIntoBatches(Array.from({ length: 1001 }, (_, index) => index), 500)
        .map((batch) => batch.length),
      [500, 500, 1],
    );
    assert.throws(() => splitIntoBatches([1], 0), /positive integer/);
    console.log('Admin broadcast notification tests passed.');
  } finally {
    if (previousServiceAccount === undefined) {
      delete process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    } else {
      process.env.FIREBASE_SERVICE_ACCOUNT_JSON = previousServiceAccount;
    }
    await new Promise<void>((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
    });
  }
}

void main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
