import assert from 'node:assert/strict';
import express from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import type { PrismaClient } from '@prisma/client';
import { createAuthMiddleware } from '../src/middleware/auth.js';
import { createPasswordResetRouter } from '../src/routes/password-reset.js';
import { StoreEmailDeliveryError } from '../src/services/email-sender.js';

interface StoredOtp {
  email: string;
  otpHash: string;
  expiresAt: Date;
  attempts: number;
}

async function run(): Promise<void> {
  let userPasswordHash = 'existing-password-hash';
  let userTokenVersion = 0;
  let storedOtp: StoredOtp | null = null;
  let deliveredCode: string | null = null;
  let prisma: PrismaClient;
  const fake: Record<string, any> = {
    user: {
      findUnique: async () => ({
        isActive: true,
        tokenVersion: userTokenVersion,
      }),
      updateMany: async ({ data }: {
        data: {
          passwordHash: string;
          tokenVersion: { increment: number };
        };
      }) => {
        userPasswordHash = data.passwordHash;
        userTokenVersion += data.tokenVersion.increment;
        return { count: 1 };
      },
    },
    passwordResetOtp: {
      upsert: async ({
        create,
        update,
      }: {
        create: StoredOtp;
        update: Partial<StoredOtp>;
      }) => {
        storedOtp = storedOtp
          ? { ...storedOtp, ...update }
          : { ...create, attempts: 0 };
        return storedOtp;
      },
      findUnique: async () => storedOtp,
      updateMany: async ({
        where,
      }: {
        where: { otpHash: string; attempts: { lt: number } };
      }) => {
        if (
          storedOtp?.otpHash === where.otpHash &&
          storedOtp.attempts < where.attempts.lt
        ) {
          storedOtp.attempts++;
          return { count: 1 };
        }
        return { count: 0 };
      },
      deleteMany: async ({
        where,
      }: {
        where: {
          email: string;
          otpHash?: string;
          expiresAt?: { gt: Date };
          attempts?: { lt: number };
        };
      }) => {
        const matches = storedOtp?.email === where.email &&
          (!where.otpHash || storedOtp.otpHash === where.otpHash) &&
          (!where.expiresAt || storedOtp.expiresAt > where.expiresAt.gt) &&
          (!where.attempts || storedOtp.attempts < where.attempts.lt);
        if (!matches) return { count: 0 };
        storedOtp = null;
        return { count: 1 };
      },
    },
    $transaction: async (operation: (transaction: unknown) => Promise<unknown>) =>
      operation(fake),
  };
  prisma = fake as unknown as PrismaClient;

  const secret = 'password-reset-tests-use-a-random-independent-secret';
  const { authenticateToken } = createAuthMiddleware(prisma, secret);
  const app = express();
  app.use(express.json());
  app.use(
    '/reset',
    createPasswordResetRouter(prisma, async (_email, code) => {
      deliveredCode = code;
    }),
  );
  app.use(
    '/reset-failure',
    createPasswordResetRouter(prisma, async () => {
      throw new StoreEmailDeliveryError('ETIMEDOUT');
    }),
  );
  app.get('/protected', authenticateToken, (_req, res) => res.sendStatus(204));

  const server = app.listen(0);
  try {
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const address = server.address();
    assert(address && typeof address !== 'string');
    const baseUrl = `http://127.0.0.1:${address.port}/reset`;
    const oldToken = jwt.sign(
      { id: 'customer-1', tokenVersion: userTokenVersion },
      secret,
    );
    const protectedRequest = () => fetch(
      `http://127.0.0.1:${address.port}/protected`,
      { headers: { authorization: `Bearer ${oldToken}` } },
    );
    assert.equal((await protectedRequest()).status, 204);

    const requestCode = await fetch(`${baseUrl}/request`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email: 'Customer@example.com' }),
    });
    assert.equal(requestCode.status, 200);
    assert.equal(typeof deliveredCode, 'string');
    assert.match(deliveredCode!, /^\d{6}$/);
    assert.notEqual(storedOtp?.otpHash, deliveredCode);
    assert.equal(storedOtp?.email, 'customer@example.com');

    const wrongCode = await fetch(`${baseUrl}/confirm`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        email: 'customer@example.com',
        code: deliveredCode === '000000' ? '000001' : '000000',
        password: 'new-secure-password',
      }),
    });
    assert.equal(wrongCode.status, 400);
    assert.equal(storedOtp?.attempts, 1);

    const confirmation = await fetch(`${baseUrl}/confirm`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        email: 'customer@example.com',
        code: deliveredCode,
        password: 'new-secure-password',
      }),
    });
    assert.equal(confirmation.status, 200);
    assert.equal(storedOtp, null, 'successful codes are consumed');
    assert.equal(await bcrypt.compare('new-secure-password', userPasswordHash), true);
    assert.equal(userTokenVersion, 1, 'password resets increment the session version');
    assert.equal(
      (await protectedRequest()).status,
      401,
      'a token issued before the password reset is revoked',
    );

    const replay = await fetch(`${baseUrl}/confirm`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        email: 'customer@example.com',
        code: deliveredCode,
        password: 'another-secure-password',
      }),
    });
    assert.equal(replay.status, 400, 'a reset code cannot be reused');

    const failedDelivery = await fetch(
      `http://127.0.0.1:${address.port}/reset-failure/request`,
      {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'customer@example.com' }),
      },
    );
    assert.equal(failedDelivery.status, 503);
    const failureBody = await failedDelivery.json() as { error: string };
    assert.match(failureBody.error, /cannot reach Gmail SMTP/);
    assert.equal(storedOtp, null, 'failed delivery removes its unusable code');
    console.log('Password reset OTP tests passed.');
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
