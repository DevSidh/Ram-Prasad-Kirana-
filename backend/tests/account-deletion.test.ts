import assert from 'node:assert/strict';
import bcrypt from 'bcryptjs';
import express, { type RequestHandler } from 'express';
import type { PrismaClient } from '@prisma/client';
import { createAccountRouter } from '../src/routes/account.js';

interface TestUser {
  id: string;
  email: string;
  passwordHash: string;
  role: string;
  isActive: boolean;
  tokenVersion: number;
}

interface TestState {
  user: TestUser;
  activeOrderCount: number;
  calls: string[];
  anonymizedOrder: Record<string, unknown> | null;
  anonymizedPayment: Record<string, unknown> | null;
}

function createApp(state: TestState) {
  const transaction = {
    user: {
      updateMany: async ({
        where,
        data,
      }: {
        where: { id: string; isActive: boolean; role: string };
        data: Record<string, unknown>;
      }) => {
        if (
          state.user.id !== where.id ||
          state.user.isActive !== where.isActive ||
          state.user.role !== where.role
        ) {
          return { count: 0 };
        }
        const tokenVersion = data.tokenVersion as { increment: number };
        state.user = {
          ...state.user,
          email: data.email as string,
          passwordHash: data.passwordHash as string,
          role: data.role as string ?? state.user.role,
          isActive: data.isActive as boolean,
          tokenVersion: state.user.tokenVersion + tokenVersion.increment,
        };
        state.calls.push('user.update');
        return { count: 1 };
      },
    },
    order: {
      count: async () => state.activeOrderCount,
      updateMany: async ({
        data,
      }: {
        where: { userId: string };
        data: Record<string, unknown>;
      }) => {
        state.anonymizedOrder = data;
        state.calls.push('order.update');
        return { count: 1 };
      },
    },
    payment: {
      updateMany: async ({
        data,
      }: {
        where: { order: { userId: string } };
        data: Record<string, unknown>;
      }) => {
        state.anonymizedPayment = data;
        state.calls.push('payment.update');
        return { count: 1 };
      },
    },
    passwordResetOtp: {
      deleteMany: async () => state.calls.push('password-reset.delete'),
    },
    address: { deleteMany: async () => state.calls.push('address.delete') },
    cart: { deleteMany: async () => state.calls.push('cart.delete') },
    wishlist: { deleteMany: async () => state.calls.push('wishlist.delete') },
    review: { deleteMany: async () => state.calls.push('review.delete') },
    notification: {
      deleteMany: async () => state.calls.push('notification.delete'),
    },
    deviceToken: {
      deleteMany: async () => state.calls.push('device-token.delete'),
    },
  };
  const prisma = {
    user: { findUnique: async () => state.user },
    $transaction: async <T>(
      callback: (client: typeof transaction) => Promise<T>,
    ) => {
      const snapshot = { ...state.user };
      try {
        return await callback(transaction);
      } catch (error) {
        state.user = snapshot;
        state.calls = [];
        state.anonymizedOrder = null;
        state.anonymizedPayment = null;
        throw error;
      }
    },
  } as unknown as PrismaClient;
  const authenticate: RequestHandler = (req, res, next) => {
    const userId = req.header('x-test-user');
    if (userId) res.locals.authenticatedUserId = userId;
    next();
  };
  const app = express();
  app.use(express.json());
  app.use('/account', createAccountRouter(prisma, authenticate));
  return app;
}

async function run(): Promise<void> {
  const passwordHash = await bcrypt.hash('correct-password', 4);
  const state: TestState = {
    user: {
      id: 'customer-1',
      email: 'customer@example.com',
      passwordHash,
      role: 'CUSTOMER',
      isActive: true,
      tokenVersion: 2,
    },
    activeOrderCount: 0,
    calls: [],
    anonymizedOrder: null,
    anonymizedPayment: null,
  };
  const app = createApp(state);
  const server = app.listen(0);
  try {
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const address = server.address();
    assert(address && typeof address !== 'string');
    const url = `http://127.0.0.1:${address.port}/account/delete-account`;
    const headers = {
      'content-type': 'application/json',
      'x-test-user': 'customer-1',
    };

    const unauthenticated = await fetch(url, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ password: 'correct-password' }),
    });
    assert.equal(unauthenticated.status, 401);

    const incorrectPassword = await fetch(url, {
      method: 'POST',
      headers,
      body: JSON.stringify({ password: 'wrong-password' }),
    });
    assert.equal(incorrectPassword.status, 401);
    assert.equal(state.user.isActive, true);
    assert.deepEqual(state.calls, []);

    state.activeOrderCount = 1;
    const activeOrder = await fetch(url, {
      method: 'POST',
      headers,
      body: JSON.stringify({ password: 'correct-password' }),
    });
    assert.equal(activeOrder.status, 409);
    assert.equal(state.user.isActive, true);
    assert.deepEqual(state.calls, []);
    state.activeOrderCount = 0;

    const deleted = await fetch(url, {
      method: 'POST',
      headers,
      body: JSON.stringify({ password: 'correct-password' }),
    });
    assert.equal(deleted.status, 200);
    assert.equal(state.user.isActive, false);
    assert.equal(state.user.tokenVersion, 3);
    assert.equal(state.user.email.endsWith('@accounts.invalid'), true);
    assert.notEqual(state.user.passwordHash, passwordHash);
    assert.equal(state.anonymizedOrder?.shippingPhone, 'Removed');
    assert.equal(state.anonymizedOrder?.notes, null);
    assert.equal(state.anonymizedPayment?.transactionId, null);
    assert.deepEqual(state.calls, [
      'user.update',
      'order.update',
      'payment.update',
      'password-reset.delete',
      'address.delete',
      'cart.delete',
      'wishlist.delete',
      'review.delete',
      'notification.delete',
      'device-token.delete',
    ]);
    console.log('Customer account deletion and order anonymization tests passed.');
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
