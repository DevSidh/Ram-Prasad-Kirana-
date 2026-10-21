import assert from 'node:assert/strict';
import express from 'express';
import type { PrismaClient } from '@prisma/client';
import { createEmailVerificationRouter } from '../src/routes/email-verification.js';
import {
  StoreEmailDeliveryError,
  type StoreEmail,
} from '../src/services/email-sender.js';

interface StoredOtp {
  email: string;
  otpHash: string;
  expiresAt: Date;
  attempts: number;
}

async function run(): Promise<void> {
  let otp: StoredOtp | null = null;
  let emailVerified = false;
  let deliveredCode: string | null = null;
  const user = {
    id: 'customer-1',
    email: 'customer@example.com',
    name: 'Store Customer',
    phone: null,
    role: 'CUSTOMER',
    avatarUrl: null,
    tokenVersion: 0,
    isActive: true,
    emailVerified: false,
  };
  const fake: Record<string, any> = {
    user: {
      findUnique: async () => ({
        ...user,
        emailVerified,
      }),
      updateMany: async ({
        where,
      }: {
        where: { email: string; emailVerified: boolean; isActive: boolean };
      }) => {
        if (
          where.email !== user.email ||
          where.emailVerified !== emailVerified ||
          !user.isActive
        ) {
          return { count: 0 };
        }
        emailVerified = true;
        return { count: 1 };
      },
    },
    emailVerificationOtp: {
      upsert: async ({
        create,
        update,
      }: {
        create: StoredOtp;
        update: Partial<StoredOtp>;
      }) => {
        otp = otp ? { ...otp, ...update } : { ...create, attempts: 0 };
        return otp;
      },
      findUnique: async () => otp,
      updateMany: async ({
        where,
      }: {
        where: { email: string; otpHash: string; attempts: { lt: number } };
      }) => {
        if (
          otp?.email === where.email &&
          otp.otpHash === where.otpHash &&
          otp.attempts < where.attempts.lt
        ) {
          otp.attempts++;
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
        const matches = otp?.email === where.email &&
          (!where.otpHash || otp.otpHash === where.otpHash) &&
          (!where.expiresAt || otp.expiresAt > where.expiresAt.gt) &&
          (!where.attempts || otp.attempts < where.attempts.lt);
        if (!matches) return { count: 0 };
        otp = null;
        return { count: 1 };
      },
    },
    $transaction: async (
      operation: (transaction: unknown) => Promise<unknown>,
    ) => operation(fake),
  };

  const app = express();
  app.use(express.json());
  app.use(
    '/verification',
    createEmailVerificationRouter(
      fake as unknown as PrismaClient,
      'email-verification-tests-use-a-random-independent-secret',
      60 * 60,
      async (email: StoreEmail) => {
        assert.equal(email.to, user.email);
        deliveredCode = email.text.match(/\b\d{6}\b/)?.[0] ?? null;
      },
    ),
  );
  app.use(
    '/verification-failure',
    createEmailVerificationRouter(
      fake as unknown as PrismaClient,
      'email-verification-tests-use-a-random-independent-secret',
      60 * 60,
      async () => {
        throw new StoreEmailDeliveryError('EAUTH', 535);
      },
    ),
  );
  const server = app.listen(0);

  try {
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const address = server.address();
    assert(address && typeof address !== 'string');
    const baseUrl = `http://127.0.0.1:${address.port}/verification`;

    const request = await fetch(`${baseUrl}/request`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email: 'Customer@Example.com' }),
    });
    assert.equal(request.status, 200);
    assert.match(deliveredCode ?? '', /^\d{6}$/);
    assert.notEqual(otp?.otpHash, deliveredCode);
    assert.equal(otp?.email, user.email);

    const wrongCode = await fetch(`${baseUrl}/confirm`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        email: user.email,
        code: deliveredCode === '000000' ? '000001' : '000000',
      }),
    });
    assert.equal(wrongCode.status, 400);
    assert.equal(otp?.attempts, 1);
    assert.equal(emailVerified, false);

    const confirmation = await fetch(`${baseUrl}/confirm`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email: user.email, code: deliveredCode }),
    });
    assert.equal(confirmation.status, 200);
    const response = await confirmation.json() as {
      token: string;
      user: { email: string };
    };
    assert.ok(response.token);
    assert.equal(response.user.email, user.email);
    assert.equal(emailVerified, true);
    assert.equal(otp, null);

    const replay = await fetch(`${baseUrl}/confirm`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email: user.email, code: deliveredCode }),
    });
    assert.equal(replay.status, 400);

    emailVerified = false;
    const failedDelivery = await fetch(
      `http://127.0.0.1:${address.port}/verification-failure/request`,
      {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: user.email }),
      },
    );
    assert.equal(failedDelivery.status, 503);
    const failureBody = await failedDelivery.json() as { error: string };
    assert.match(failureBody.error, /Google App Password/);
    assert.equal(otp, null, 'failed delivery removes its undeliverable code');
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
    });
  }
}

run().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
