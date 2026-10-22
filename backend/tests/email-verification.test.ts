import assert from 'node:assert/strict';
import bcrypt from 'bcryptjs';
import express from 'express';
import type { PrismaClient } from '@prisma/client';
import {
  beginPendingRegistration,
  cleanupExpiredRegistrations,
  createEmailVerificationRouter,
  normalizeRegistrationPhone,
} from '../src/routes/email-verification.js';
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

interface StoredRegistration {
  email: string;
  name: string;
  phone: string;
  passwordHash: string;
  expiresAt: Date;
}

interface StoredUser {
  id: string;
  userNumber: bigint;
  email: string;
  name: string;
  phone: string | null;
  role: string;
  avatarUrl: string | null;
  tokenVersion: number;
  isActive: boolean;
  emailVerified: boolean;
  passwordHash: string;
}

async function run(): Promise<void> {
  const state: {
    otp: StoredOtp | null;
    pending: StoredRegistration | null;
    user: StoredUser | null;
  } = {
    otp: null,
    pending: null,
    user: {
      id: 'customer-1',
      userNumber: 1n,
      email: 'customer@example.com',
      name: 'Store Customer',
      phone: null,
      role: 'CUSTOMER',
      avatarUrl: null,
      tokenVersion: 0,
      isActive: true,
      emailVerified: false,
      passwordHash: 'legacy-password-hash',
    },
  };

  const fake: Record<string, any> = {
    user: {
      findUnique: async ({ where }: { where: { email: string } }) =>
        state.user?.email === where.email ? { ...state.user } : null,
      updateMany: async ({
        where,
        data,
      }: {
        where: { email: string; emailVerified: boolean; isActive: boolean };
        data: { emailVerified: boolean };
      }) => {
        if (
          state.user?.email !== where.email ||
          state.user.emailVerified !== where.emailVerified ||
          state.user.isActive !== where.isActive
        ) {
          return { count: 0 };
        }
        state.user.emailVerified = data.emailVerified;
        return { count: 1 };
      },
      create: async ({ data }: {
        data: Omit<StoredUser, 'id' | 'userNumber' | 'avatarUrl' | 'tokenVersion' | 'isActive' | 'role'>;
      }) => {
        if (
          state.user?.email === data.email ||
          (state.user?.phone !== null && state.user?.phone === data.phone)
        ) {
          throw { code: 'P2002' };
        }
        state.user = {
          ...data,
          id: 'registered-customer',
          userNumber: 2n,
          role: 'CUSTOMER',
          avatarUrl: null,
          tokenVersion: 0,
          isActive: true,
        };
        return { ...state.user };
      },
    },
    pendingRegistration: {
      create: async ({ data }: { data: StoredRegistration }) => {
        if (state.pending?.email === data.email) {
          throw { code: 'P2002' };
        }
        state.pending = { ...data };
        return state.pending;
      },
      findUnique: async ({ where }: { where: { email: string } }) =>
        state.pending?.email === where.email ? { ...state.pending } : null,
      updateMany: async ({
        where,
        data,
      }: {
        where: { email: string; expiresAt: { gt: Date } };
        data: { expiresAt: Date };
      }) => {
        if (
          state.pending?.email !== where.email ||
          state.pending.expiresAt <= where.expiresAt.gt
        ) {
          return { count: 0 };
        }
        state.pending.expiresAt = data.expiresAt;
        return { count: 1 };
      },
      deleteMany: async ({
        where,
      }: {
        where: {
          email?: string;
          passwordHash?: string;
          expiresAt?: { gt?: Date; lte?: Date; equals?: Date };
        };
      }) => {
        const pending = state.pending;
        if (!pending ||
          (where.email !== undefined && pending.email !== where.email) ||
          (where.passwordHash !== undefined &&
            pending.passwordHash !== where.passwordHash) ||
          (where.expiresAt?.gt && pending.expiresAt <= where.expiresAt.gt) ||
          (where.expiresAt?.lte && pending.expiresAt > where.expiresAt.lte) ||
          (where.expiresAt?.equals &&
            pending.expiresAt.getTime() !== where.expiresAt.equals.getTime())) {
          return { count: 0 };
        }
        state.pending = null;
        return { count: 1 };
      },
      findFirst: async ({
        where,
      }: {
        where: { phone: string; email: { not: string } };
      }) => state.pending?.phone === where.phone &&
          state.pending.email !== where.email.not
        ? { email: state.pending.email }
        : null,
    },
    emailVerificationOtp: {
      upsert: async ({
        create,
        update,
      }: {
        create: StoredOtp;
        update: Partial<StoredOtp>;
      }) => {
        state.otp = state.otp
          ? { ...state.otp, ...update }
          : { ...create, attempts: 0 };
        return state.otp;
      },
      findUnique: async ({ where }: { where: { email: string } }) =>
        state.otp?.email === where.email ? { ...state.otp } : null,
      updateMany: async ({
        where,
      }: {
        where: { email: string; otpHash: string; attempts: { lt: number } };
      }) => {
        if (
          state.otp?.email === where.email &&
          state.otp.otpHash === where.otpHash &&
          state.otp.attempts < where.attempts.lt
        ) {
          state.otp.attempts++;
          return { count: 1 };
        }
        return { count: 0 };
      },
      deleteMany: async ({
        where,
      }: {
        where: {
          email?: string;
          otpHash?: string;
          expiresAt?: { gt?: Date; lte?: Date };
          attempts?: { lt: number };
        };
      }) => {
        const otp = state.otp;
        if (!otp ||
          (where.email !== undefined && otp.email !== where.email) ||
          (where.otpHash !== undefined && otp.otpHash !== where.otpHash) ||
          (where.expiresAt?.gt && otp.expiresAt <= where.expiresAt.gt) ||
          (where.expiresAt?.lte && otp.expiresAt > where.expiresAt.lte) ||
          (where.attempts && otp.attempts >= where.attempts.lt)) {
          return { count: 0 };
        }
        state.otp = null;
        return { count: 1 };
      },
    },
    $transaction: async (
      operation: (transaction: unknown) => Promise<unknown>,
    ) => {
      const previous = {
        otp: state.otp && { ...state.otp },
        pending: state.pending && { ...state.pending },
        user: state.user && { ...state.user },
      };
      try {
        return await operation(fake);
      } catch (error) {
        state.otp = previous.otp;
        state.pending = previous.pending;
        state.user = previous.user;
        throw error;
      }
    },
  };
  const prisma = fake as unknown as PrismaClient;

  assert.equal(normalizeRegistrationPhone('9812345678'), '9812345678');
  assert.equal(normalizeRegistrationPhone('+9779812345678'), '9812345678');
  assert.equal(normalizeRegistrationPhone('9712345678'), '9712345678');
  assert.equal(normalizeRegistrationPhone('+977 9812345678'), '9812345678');
  assert.equal(normalizeRegistrationPhone('+977 98 1234 5678'), '9812345678');
  assert.equal(normalizeRegistrationPhone('9612345678'), null);
  assert.equal(normalizeRegistrationPhone('981234567'), null);
  assert.equal(normalizeRegistrationPhone('98123456789'), null);

  let deliveredCode: string | null = null;
  const captureEmail = async (email: StoreEmail) => {
    assert.equal(email.to, 'customer@example.com');
    deliveredCode = email.text.match(/\b\d{6}\b/)?.[0] ?? null;
  };
  const secret = 'email-verification-tests-use-a-random-independent-secret';
  const app = express();
  app.use(express.json());
  app.use(
    '/verification',
    createEmailVerificationRouter(prisma, secret, 60 * 60, captureEmail),
  );
  app.use(
    '/verification-verified',
    createEmailVerificationRouter(prisma, secret, 60 * 60, captureEmail),
  );
  app.use(
    '/verification-failure',
    createEmailVerificationRouter(
      prisma,
      secret,
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

    const legacyResend = await fetch(`${baseUrl}/request`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email: 'Customer@Example.com' }),
    });
    assert.equal(legacyResend.status, 200);
    assert.match(deliveredCode ?? '', /^\d{6}$/);
    assert.notEqual(state.otp?.otpHash, deliveredCode);
    assert.equal(state.otp?.email, 'customer@example.com');

    const wrongLegacyCode = await fetch(`${baseUrl}/confirm`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        email: 'customer@example.com',
        code: deliveredCode === '000000' ? '000001' : '000000',
      }),
    });
    assert.equal(wrongLegacyCode.status, 400);
    assert.equal(state.otp?.attempts, 1);
    assert.equal(state.user?.emailVerified, false);

    const legacyConfirmation = await fetch(`${baseUrl}/confirm`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email: 'customer@example.com', code: deliveredCode }),
    });
    assert.equal(legacyConfirmation.status, 200);
    const legacyBody = await legacyConfirmation.json() as {
      token: string;
      user: { email: string; profileId: string };
    };
    assert.ok(legacyBody.token);
    assert.equal(legacyBody.user.email, 'customer@example.com');
    assert.equal(legacyBody.user.profileId, 'USR-000001');
    assert.equal(state.user?.emailVerified, true);
    assert.equal(state.otp, null);

    deliveredCode = null;
    const verifiedResend = await fetch(
      `http://127.0.0.1:${address.port}/verification-verified/request`,
      {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'customer@example.com' }),
      },
    );
    assert.equal(verifiedResend.status, 200);
    assert.equal(deliveredCode, null);
    assert.equal(state.otp, null, 'verified users are not re-verified');

    const legacyReplay = await fetch(`${baseUrl}/confirm`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email: 'customer@example.com', code: deliveredCode }),
    });
    assert.equal(legacyReplay.status, 400);

    state.user = null;
    state.otp = null;
    state.pending = null;
    deliveredCode = null;
    const password = 'secure-registration-password';
    const passwordHash = await bcrypt.hash(password, 12);
    await beginPendingRegistration(
      prisma,
      {
        name: 'New Customer',
        email: 'customer@example.com',
        phone: '9812345678',
        passwordHash,
      },
      captureEmail,
    );
    assert.equal(state.user, null, 'registration does not create a User');
    assert.equal(state.pending?.email, 'customer@example.com');
    assert.equal(state.pending?.name, 'New Customer');
    assert.equal(state.pending?.phone, '9812345678');
    assert.equal(state.pending?.passwordHash, passwordHash);
    assert.notEqual(state.pending?.passwordHash, password);
    assert.equal(await bcrypt.compare(password, state.pending!.passwordHash), true);
    assert.match(deliveredCode ?? '', /^\d{6}$/);
    assert.notEqual(state.otp?.otpHash, deliveredCode);

    const pendingResend = await fetch(`${baseUrl}/request`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email: 'CUSTOMER@example.com' }),
    });
    assert.equal(pendingResend.status, 200);
    assert.match(deliveredCode ?? '', /^\d{6}$/);
    assert.equal(state.pending?.email, 'customer@example.com');

    const invalidRegistrationCode = await fetch(`${baseUrl}/confirm`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        email: 'customer@example.com',
        code: deliveredCode === '000000' ? '000001' : '000000',
      }),
    });
    assert.equal(invalidRegistrationCode.status, 400);
    assert.equal(state.otp?.attempts, 1);
    assert.equal(state.user, null);
    assert.ok(state.pending);

    state.otp!.attempts = 4;
    const fifthInvalidCode = await fetch(`${baseUrl}/confirm`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        email: 'customer@example.com',
        code: deliveredCode === '000000' ? '000001' : '000000',
      }),
    });
    assert.equal(fifthInvalidCode.status, 400);
    assert.equal(state.otp?.attempts, 5);
    const exhaustedCode = await fetch(`${baseUrl}/confirm`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email: 'customer@example.com', code: deliveredCode }),
    });
    assert.equal(exhaustedCode.status, 400);
    assert.equal(state.otp, null, 'a code is invalidated after five failed attempts');
    assert.ok(state.pending, 'attempt exhaustion does not create or delete the pending user');

    const resentAfterLockout = await fetch(`${baseUrl}/request`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email: 'customer@example.com' }),
    });
    assert.equal(resentAfterLockout.status, 200);
    assert.match(deliveredCode ?? '', /^\d{6}$/);

    const registrationConfirmation = await fetch(`${baseUrl}/confirm`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email: 'customer@example.com', code: deliveredCode }),
    });
    assert.equal(registrationConfirmation.status, 200);
    const registrationBody = await registrationConfirmation.json() as {
      message: string;
      token: string;
      user: { email: string; fullName: string; phone: string; profileId: string };
    };
    assert.equal(registrationBody.message, 'Email verified successfully.');
    assert.ok(registrationBody.token);
    assert.equal(registrationBody.user.email, 'customer@example.com');
    assert.equal(registrationBody.user.fullName, 'New Customer');
    assert.equal(registrationBody.user.phone, '9812345678');
    assert.equal(registrationBody.user.profileId, 'USR-000002');
    assert.equal(await bcrypt.compare(password, state.user!.passwordHash), true);
    assert.equal(state.user?.emailVerified, true);
    assert.equal(state.pending, null, 'successful confirmation consumes pending registration');
    assert.equal(state.otp, null, 'successful confirmation consumes OTP');

    const registrationReplay = await fetch(`${baseUrl}/confirm`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email: 'customer@example.com', code: deliveredCode }),
    });
    assert.equal(registrationReplay.status, 400);

    state.user = null;
    state.otp = null;
    state.pending = null;
    deliveredCode = null;
    await beginPendingRegistration(
      prisma,
      {
        name: 'Collision Customer',
        email: 'customer@example.com',
        phone: '9812345678',
        passwordHash,
      },
      captureEmail,
    );
    state.user = {
      id: 'racing-customer',
      userNumber: 3n,
      email: 'other@example.com',
      name: 'Other Customer',
      phone: '9812345678',
      role: 'CUSTOMER',
      avatarUrl: null,
      tokenVersion: 0,
      isActive: true,
      emailVerified: true,
      passwordHash,
    };
    const collision = await fetch(`${baseUrl}/confirm`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email: 'customer@example.com', code: deliveredCode }),
    });
    assert.equal(collision.status, 409);
    assert.match((await collision.json() as { error: string }).error, /account/);
    assert.ok(state.pending, 'uniqueness collision does not consume pending data');
    assert.ok(state.otp, 'uniqueness collision does not consume the verification code');

    state.user = null;
    state.otp = null;
    state.pending = null;
    await assert.rejects(
      beginPendingRegistration(
        prisma,
        {
          name: 'Undeliverable Customer',
          email: 'customer@example.com',
          phone: '9812345678',
          passwordHash,
        },
        async () => {
          throw new StoreEmailDeliveryError('EAUTH', 535);
        },
      ),
      StoreEmailDeliveryError,
    );
    assert.equal(state.pending, null, 'failed delivery removes pending registration data');
    assert.equal(state.otp, null, 'failed delivery removes the unusable OTP');

    state.pending = {
      email: 'customer@example.com',
      name: 'Expired Customer',
      phone: '9812345678',
      passwordHash,
      expiresAt: new Date(Date.now() - 1),
    };
    state.otp = {
      email: 'customer@example.com',
      otpHash: 'expired-hash',
      expiresAt: new Date(Date.now() - 1),
      attempts: 0,
    };
    await cleanupExpiredRegistrations(prisma);
    assert.equal(state.pending, null, 'expired pending registrations are cleaned up');
    assert.equal(state.otp, null, 'expired verification codes are cleaned up');

    state.user = {
      id: 'customer-1',
      userNumber: 1n,
      email: 'customer@example.com',
      name: 'Store Customer',
      phone: null,
      role: 'CUSTOMER',
      avatarUrl: null,
      tokenVersion: 0,
      isActive: true,
      emailVerified: false,
      passwordHash: 'legacy-password-hash',
    };
    const failedDelivery = await fetch(
      `http://127.0.0.1:${address.port}/verification-failure/request`,
      {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ email: 'customer@example.com' }),
      },
    );
    assert.equal(failedDelivery.status, 503);
    const failureBody = await failedDelivery.json() as { error: string };
    assert.match(failureBody.error, /OAuth client, refresh token/);
    assert.equal(state.otp, null, 'failed resend removes its undeliverable code');
    console.log('Email verification and pending registration tests passed.');
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
