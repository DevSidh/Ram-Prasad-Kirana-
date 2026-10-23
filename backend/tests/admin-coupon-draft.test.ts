import assert from 'node:assert/strict';
import express, { type RequestHandler } from 'express';
import type { PrismaClient } from '@prisma/client';
import { createAdminRouter } from '../src/routes/admin.js';

async function main(): Promise<void> {
  const createdCoupons: Array<Record<string, unknown>> = [];
  let notificationsCreated = false;
  const prisma = {
    coupon: {
      create: async ({ data }: { data: Record<string, unknown> }) => {
        createdCoupons.push(data);
        return {
          ...data,
          id: 'coupon-1',
          usedCount: 0,
          isAnnounced: false,
          createdAt: new Date('2026-10-23T00:00:00.000Z'),
        };
      },
    },
    notification: {
      create: async () => {
        notificationsCreated = true;
      },
      createMany: async () => {
        notificationsCreated = true;
      },
    },
  } as unknown as PrismaClient;
  const allow: RequestHandler = (_req, _res, next) => next();
  const app = express();
  app.use(express.json());
  app.use('/admin', createAdminRouter(prisma, allow, allow));
  const server = app.listen(0);

  try {
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const address = server.address();
    assert(address && typeof address !== 'string');
    const response = await fetch(
      `http://127.0.0.1:${address.port}/admin/coupons`,
      {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          code: 'SAVE10',
          discountType: 'PERCENTAGE',
          discountPercent: 10,
          discountAmount: null,
          minOrderAmount: 100,
          maxDiscount: 50,
          usageLimit: 20,
          perUserLimit: 2,
          expiresAt: null,
        }),
      },
    );
    assert.equal(response.status, 201);
    const result = await response.json() as {
      coupon: { code: string; isAnnounced: boolean };
    };
    assert.equal(result.coupon.code, 'SAVE10');
    assert.equal(result.coupon.isAnnounced, false);
    assert.equal(createdCoupons.length, 1);
    assert.equal(notificationsCreated, false);
    console.log('Admin coupon creation leaves codes as unsent drafts.');
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
