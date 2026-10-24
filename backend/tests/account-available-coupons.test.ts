import assert from 'node:assert/strict';
import express, { type RequestHandler } from 'express';
import type { PrismaClient } from '@prisma/client';
import { createAccountRouter } from '../src/routes/account.js';

async function main(): Promise<void> {
  const coupons = [
    {
      code: 'ANNOUNCED',
      assignedUserId: null,
      usageLimit: 10,
      perUserLimit: 2,
      usedCount: 5,
    },
    {
      code: 'GLOBAL-LIMIT',
      assignedUserId: null,
      usageLimit: 5,
      perUserLimit: null,
      usedCount: 5,
    },
    {
      code: 'CUSTOMER-LIMIT',
      assignedUserId: null,
      usageLimit: null,
      perUserLimit: 1,
      usedCount: 1,
    },
    {
      code: 'OTHER-CUSTOMER',
      assignedUserId: 'customer-2',
      usageLimit: 1,
      perUserLimit: 1,
      usedCount: 0,
    },
    {
      code: 'OWN-COUPON',
      assignedUserId: 'customer-1',
      usageLimit: 1,
      perUserLimit: 1,
      usedCount: 0,
    },
    {
      code: 'STREAK-CLAIMED',
      assignedUserId: 'customer-1',
      usageLimit: 1,
      perUserLimit: 1,
      usedCount: 0,
    },
  ];
  const prisma = {
    notification: {
      findMany: async () => [
        { metadata: { couponCode: 'ANNOUNCED' } },
        { metadata: { couponCode: 'GLOBAL-LIMIT' } },
        { metadata: { couponCode: 'CUSTOMER-LIMIT' } },
        { metadata: { couponCode: 'OTHER-CUSTOMER' } },
        { metadata: { couponCode: 'OWN-COUPON' } },
      ],
    },
    coupon: {
      findMany: async () => coupons,
    },
    order: {
      groupBy: async ({ where }: {
        where: { couponCode: { in: string[] } };
      }) => {
        assert.ok(where.couponCode.in.includes('STREAK-CLAIMED'));
        return [
          { couponCode: 'ANNOUNCED', _count: { couponCode: 1 } },
          { couponCode: 'CUSTOMER-LIMIT', _count: { couponCode: 1 } },
        ];
      },
    },
  } as unknown as PrismaClient;
  const authenticate: RequestHandler = (_req, res, next) => {
    res.locals.authenticatedUserId = 'customer-1';
    next();
  };
  const app = express();
  app.use('/account', createAccountRouter(prisma, authenticate));
  const server = app.listen(0);

  try {
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const address = server.address();
    assert(address && typeof address !== 'string');
    const response = await fetch(
      `http://127.0.0.1:${address.port}/account/coupons/available`,
    );
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), {
      availableCouponCodes: ['ANNOUNCED', 'OWN-COUPON', 'STREAK-CLAIMED'],
    });
    console.log('Customer coupons include claimed gifts and enforce limits.');
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
