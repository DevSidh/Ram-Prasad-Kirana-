import assert from 'node:assert/strict';
import express, { type RequestHandler } from 'express';
import type { PrismaClient } from '@prisma/client';
import { createAccountRouter } from '../src/routes/account.js';
import { calculateCurrentBuyingStreak } from '../src/services/buying-streak.js';

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

async function verifyOneTimeClaim(): Promise<void> {
  let claimedAt: Date | null = null;
  const progress = {
    userId: 'customer-1',
    day: 2,
    title: 'Free drink',
    description: 'Choose one drink at the counter.',
    unlockedAt: new Date('2026-11-02T01:00:00.000Z'),
    claimedAt: null as Date | null,
  };
  const prisma = {
    buyingStreakRewardProgress: {
      findUnique: async () => ({ ...progress, claimedAt }),
      updateMany: async () => {
        if (claimedAt !== null) return { count: 0 };
        claimedAt = new Date();
        return { count: 1 };
      },
    },
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
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => (error ? reject(error) : resolve()));
    });
  }
}

void verifyOneTimeClaim()
  .then(() => console.log('Buying streak tests passed.'))
  .catch((error: unknown) => {
    console.error(error);
    process.exitCode = 1;
  });
