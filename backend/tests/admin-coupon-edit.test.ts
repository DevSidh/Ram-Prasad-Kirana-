import assert from 'node:assert/strict';
import express, { type RequestHandler } from 'express';
import type { PrismaClient } from '@prisma/client';
import { createAdminRouter } from '../src/routes/admin.js';

async function main(): Promise<void> {
  const coupon = {
    id: 'coupon-1',
    code: 'SAVE10',
    discountType: 'PERCENTAGE',
    discountPercent: 10,
    discountAmount: null,
    minOrderAmount: 100,
    maxDiscount: 50,
    usageLimit: 20,
    perUserLimit: 2,
    usedCount: 3,
    isActive: true,
    expiresAt: null as Date | null,
    createdAt: new Date('2026-01-01T00:00:00.000Z'),
  };
  let updateCount = 0;
  const prisma = {
    coupon: {
      findUnique: async ({ select }: {
        select?: { id?: boolean; usedCount?: boolean };
      }) => select ? { id: coupon.id, usedCount: coupon.usedCount } : coupon,
      updateMany: async ({ data }: {
        data: Record<string, unknown>;
      }) => {
        updateCount++;
        Object.assign(coupon, data);
        return { count: 1 };
      },
    },
  } as unknown as PrismaClient;
  const adminOnly: RequestHandler = (req, res, next) =>
    req.header('x-admin') === 'allowed'
      ? next()
      : res.status(403).json({ error: 'Admin access is required.' });
  const allow: RequestHandler = (_req, _res, next) => next();
  const app = express();
  app.use(express.json());
  app.use('/admin', createAdminRouter(prisma, allow, adminOnly));
  const server = app.listen(0);

  try {
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const address = server.address();
    assert(address && typeof address !== 'string');
    const endpoint = `http://127.0.0.1:${address.port}/admin/coupons/coupon-1`;
    const patch = (body: unknown) => fetch(endpoint, {
      method: 'PATCH',
      headers: {
        'content-type': 'application/json',
        'x-admin': 'allowed',
      },
      body: JSON.stringify(body),
    });
    const base = {
      code: 'SAVE20',
      discountType: 'PERCENTAGE',
      discountPercent: 20,
      discountAmount: null,
      minOrderAmount: 250,
      maxDiscount: 100,
      usageLimit: 10,
      perUserLimit: 1,
      expiresAt: '2027-01-01T12:30:00.000Z',
    };

    const lowerLimit = await patch({ ...base, usageLimit: 2 });
    assert.equal(lowerLimit.status, 400);
    assert.equal(updateCount, 0);

    const response = await patch(base);
    assert.equal(response.status, 200);
    const result = await response.json() as { coupon: Record<string, unknown> };
    assert.equal(result.coupon.code, 'SAVE20');
    assert.equal(result.coupon.usageLimit, 10);
    assert.equal(result.coupon.perUserLimit, 1);
    assert.equal(result.coupon.expiresAt, '2027-01-01T12:30:00.000Z');
    assert.equal(updateCount, 1);

    const removed = await fetch(endpoint, {
      method: 'DELETE',
      headers: { 'x-admin': 'allowed' },
    });
    assert.equal(removed.status, 200);
    assert.equal(coupon.isActive, false);
    assert.equal(coupon.isDeleted, true);
    assert.equal(updateCount, 2);
    console.log('Admin coupon editing tests passed.');
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
    });
  }
}

void main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
