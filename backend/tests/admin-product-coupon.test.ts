import assert from 'node:assert/strict';
import express, { type RequestHandler } from 'express';
import type { PrismaClient } from '@prisma/client';
import { createAdminRouter } from '../src/routes/admin.js';

let storedNotification: Record<string, unknown> | undefined;
const product = { id: 'product-1', name: 'Mango juice', price: 120 };
const transaction = {
  coupon: {
    create: async ({ data }: { data: Record<string, unknown> }) => ({
      ...data,
      id: 'coupon-1',
      usedCount: 0,
      isActive: true,
      createdAt: new Date('2026-10-23T00:00:00.000Z'),
      updatedAt: new Date('2026-10-23T00:00:00.000Z'),
    }),
  },
  notification: {
    create: async ({ data }: { data: Record<string, unknown> }) => {
      storedNotification = data;
      return { id: 'notification-1' };
    },
  },
};
const prisma = {
  $transaction: async <T>(
    callback: (client: typeof transaction) => Promise<T>,
  ) => callback(transaction),
  user: {
    findFirst: async ({ where }: { where: { id: string } }) =>
      where.id === 'customer-1' ? { id: 'customer-1' } : null,
  },
  product: {
    findFirst: async ({ where }: { where: { id: string } }) =>
      where.id === product.id ? product : null,
  },
} as unknown as PrismaClient;
const authenticate: RequestHandler = (_req, _res, next) => next();
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
    const response = await fetch(
      `http://127.0.0.1:${address.port}/admin/coupons/product`,
      {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          customerId: 'customer-1',
          productId: product.id,
          discountType: 'PERCENTAGE',
          discountValue: 25,
        }),
      },
    );
    assert.equal(response.status, 201);
    const result = await response.json() as {
      coupon: {
        code: string;
        productId: string;
        assignedUserId: string;
        usageLimit: number;
        perUserLimit: number;
      };
    };
    assert.match(result.coupon.code, /^PRODUCT-[A-F0-9]{10}$/);
    assert.equal(result.coupon.productId, product.id);
    assert.equal(result.coupon.assignedUserId, 'customer-1');
    assert.equal(result.coupon.usageLimit, 1);
    assert.equal(result.coupon.perUserLimit, 1);
    assert.equal(storedNotification?.userId, 'customer-1');
    assert.deepEqual(storedNotification?.metadata, {
      couponCode: result.coupon.code,
      productId: product.id,
    });

    const invalidDiscount = await fetch(
      `http://127.0.0.1:${address.port}/admin/coupons/product`,
      {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          customerId: 'customer-1',
          productId: product.id,
          discountType: 'FIXED',
          discountValue: 121,
        }),
      },
    );
    assert.equal(invalidDiscount.status, 400);
    console.log('Admin product coupon tests passed.');
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
