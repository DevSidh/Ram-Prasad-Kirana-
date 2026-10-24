import assert from 'node:assert/strict';
import express, { type RequestHandler } from 'express';
import type { PrismaClient } from '@prisma/client';
import { createAccountRouter } from '../src/routes/account.js';
import {
  calculateCurrentBuyingStreak,
  calculateLongestBuyingStreak,
  getBuyingStreakSnapshot,
} from '../src/services/buying-streak.js';

const now = new Date('2026-11-02T01:00:00.000Z');
assert.equal(
  calculateCurrentBuyingStreak(
    ['2026-11-02', '2026-11-01', '2026-10-31'],
    now,
  ),
  3,
);
assert.equal(calculateCurrentBuyingStreak(['2026-11-01'], now), 1);
assert.equal(calculateCurrentBuyingStreak(['2026-11-02', '2026-10-31'], now), 1);
assert.equal(calculateCurrentBuyingStreak(['2026-10-31'], now), 0);
assert.equal(calculateCurrentBuyingStreak([], now), 0);
assert.equal(
  calculateLongestBuyingStreak([
    '2026-11-02',
    '2026-11-01',
    '2026-10-30',
    '2026-10-29',
    '2026-10-28',
    '2026-10-28',
  ]),
  3,
);
assert.equal(calculateLongestBuyingStreak([]), 0);

async function verifyNewMilestonesReconcileWithHistory(): Promise<void> {
  const dayKeys = [
    '2026-11-02',
    '2026-11-01',
    '2026-10-31',
    '2026-10-30',
    '2026-10-29',
    '2026-10-28',
    '2026-10-27',
    '2026-10-26',
    '2026-10-25',
    '2026-10-24',
  ];
  const progressByDay = new Map<number, Record<string, unknown>>([
    [10, {
      day: 10,
      title: 'Ten day reward',
      description: 'Reward for ten days.',
      unlockedAt: new Date('2026-11-02T01:00:00.000Z'),
      claimedAt: new Date('2026-11-02T01:00:00.000Z'),
      coupon: { code: 'STREAK10' },
    }],
  ]);
  const client = {
    buyingStreakPurchaseDay: {
      findMany: async () => dayKeys.map((dayKey) => ({ dayKey })),
    },
    buyingStreakRewardConfig: {
      findMany: async () => [
        {
          day: 4,
          title: 'Four day reward',
          description: 'Reward for four days.',
          couponId: 'coupon-4',
          coupon: { code: 'DAY4' },
        },
        {
          day: 10,
          title: 'Ten day reward',
          description: 'Reward for ten days.',
          couponId: 'coupon-10',
          coupon: { code: 'DAY10' },
        },
      ],
    },
    buyingStreakRewardProgress: {
      upsert: async ({ where, create }: {
        where: { userId_day: { day: number } };
        create: Record<string, unknown>;
      }) => {
        if (!progressByDay.has(where.userId_day.day)) {
          progressByDay.set(where.userId_day.day, {
            ...create,
            unlockedAt: now,
            claimedAt: null,
            coupon: null,
          });
        }
      },
      findMany: async () =>
        [...progressByDay.values()].sort(
          (left, right) => Number(left.day) - Number(right.day),
        ),
    },
  };
  const snapshot = await getBuyingStreakSnapshot(
    client as never,
    'customer-1',
    now,
  );
  assert.equal(snapshot.rewards.find((reward) => reward.day === 4)?.isUnlocked, true);
  assert.equal(snapshot.rewards.find((reward) => reward.day === 10)?.claimedAt, now.toISOString());
}

async function verifyOneTimeClaim(): Promise<void> {
  let claimedAt: Date | null = null;
  const progress = {
    userId: 'customer-1',
    day: 2,
    title: 'Free drink',
    description: 'Choose one drink at the counter.',
    unlockedAt: new Date('2026-11-02T01:00:00.000Z'),
    claimedAt: null as Date | null,
    couponId: null as string | null,
  };
  let createdCoupons = 0;
  const prisma = {
    buyingStreakRewardProgress: {
      findUnique: async () => ({
        ...progress,
        claimedAt,
        couponTemplate: {
          id: 'template-1',
          code: 'STREAK10',
          productId: null,
          assignedUserId: null,
          discountType: 'PERCENTAGE',
          discountPercent: 10,
          discountAmount: null,
          minOrderAmount: 0,
          maxDiscount: 150,
          usageLimit: 10,
          perUserLimit: 1,
          expiresAt: null,
          isActive: true,
          isDeleted: false,
        },
        coupon: null,
      }),
      updateMany: async ({ data }: { data: { claimedAt: Date } }) => {
        if (claimedAt !== null) return { count: 0 };
        claimedAt = data.claimedAt;
        return { count: 1 };
      },
      update: async ({ data }: { data: { couponId: string } }) => {
        progress.couponId = data.couponId;
      },
    },
    coupon: {
      create: async ({ data }: { data: { code: string } }) => {
        createdCoupons++;
        return { id: 'gift-1', code: data.code };
      },
    },
    $transaction: async <T>(work: (tx: unknown) => Promise<T>) =>
      work(prisma),
  } as unknown as PrismaClient;
  const authenticate: RequestHandler = (_req, res, next) => {
    res.locals.authenticatedUserId = 'customer-1';
    next();
  };
  const app = express();
  app.use(express.json());
  app.use('/account', createAccountRouter(prisma, authenticate));
  const server = app.listen(0);

  try {
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const address = server.address();
    assert(address && typeof address !== 'string');
    const endpoint =
      `http://127.0.0.1:${address.port}/account/buying-streak/rewards/2/claim`;
    const claim = () => fetch(endpoint, { method: 'POST' });
    const results = await Promise.all([claim(), claim()]);
    assert.deepEqual(
      results.map(({ status }) => status).sort(),
      [200, 409],
    );
    assert.ok(claimedAt);
    assert.equal(createdCoupons, 1);
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => (error ? reject(error) : resolve()));
    });
  }
}

void Promise.all([
  verifyNewMilestonesReconcileWithHistory(),
  verifyOneTimeClaim(),
])
  .then(() => console.log('Buying streak tests passed.'))
  .catch((error: unknown) => {
    console.error(error);
    process.exitCode = 1;
  });
