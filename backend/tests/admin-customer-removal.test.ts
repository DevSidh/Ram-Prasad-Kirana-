import assert from 'node:assert/strict';
import express, { type RequestHandler } from 'express';
import type { PrismaClient } from '@prisma/client';
import { createAdminRouter } from '../src/routes/admin.js';

async function main(): Promise<void> {
  const changedUser: Array<Record<string, unknown>> = [];
  const changedOrders: Array<Record<string, unknown>> = [];
  const changedPayments: Array<Record<string, unknown>> = [];
  const deletedRelations: string[] = [];
  let transactions = 0;
  const tx = {
    user: {
      updateMany: async ({ data }: { data: Record<string, unknown> }) => {
        changedUser.push(data);
        return { count: 1 };
      },
    },
    order: {
      updateMany: async ({ data }: { data: Record<string, unknown> }) => {
        changedOrders.push(data);
        return { count: 2 };
      },
    },
    payment: {
      updateMany: async ({ data }: { data: Record<string, unknown> }) => {
        changedPayments.push(data);
        return { count: 1 };
      },
    },
    passwordResetOtp: {
      deleteMany: async () => {
        deletedRelations.push('passwordResetOtp');
        return { count: 0 };
      },
    },
    address: { deleteMany: async () => { deletedRelations.push('address'); } },
    cart: { deleteMany: async () => { deletedRelations.push('cart'); } },
    wishlist: { deleteMany: async () => { deletedRelations.push('wishlist'); } },
    review: { deleteMany: async () => { deletedRelations.push('review'); } },
    notification: { deleteMany: async () => { deletedRelations.push('notification'); } },
    deviceToken: { deleteMany: async () => { deletedRelations.push('deviceToken'); } },
    buyingStreakPurchaseDay: {
      deleteMany: async () => { deletedRelations.push('buyingStreakPurchaseDay'); },
    },
    buyingStreakRewardProgress: {
      deleteMany: async () => { deletedRelations.push('buyingStreakRewardProgress'); },
    },
  };
  const prisma = {
    user: {
      findFirst: async ({ where }: {
        where: { id: string; role: string };
      }) => where.id === 'customer-1' && where.role === 'CUSTOMER'
        ? { id: 'customer-1', email: 'asha@example.com' }
        : null,
    },
    $transaction: async <T>(work: (transaction: unknown) => Promise<T>) => {
      transactions++;
      return work(tx);
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
    const endpoint =
      `http://127.0.0.1:${address.port}/admin/customers/customer-1`;
    const request = (confirmation: string) => fetch(endpoint, {
      method: 'DELETE',
      headers: {
        'content-type': 'application/json',
        'x-admin': 'allowed',
      },
      body: JSON.stringify({ confirmation }),
    });

    assert.equal((await request('DELETE')).status, 400);
    assert.equal(transactions, 0);
    const response = await request('REMOVE USER');
    assert.equal(response.status, 200);
    assert.equal(transactions, 1);
    assert.equal(changedUser.length, 1);
    assert.equal(changedUser[0].name, 'Removed customer');
    assert.equal(changedUser[0].phone, null);
    assert.equal(changedUser[0].isActive, false);
    assert.deepEqual(changedUser[0].tokenVersion, { increment: 1 });
    assert.match(String(changedUser[0].email), /^removed-.+@accounts\.invalid$/);
    assert.equal(typeof changedUser[0].passwordHash, 'string');
    assert.equal(changedOrders.length, 1);
    assert.equal(changedOrders[0].shippingName, 'Removed customer');
    assert.equal(changedOrders[0].addressId, null);
    assert.equal(changedPayments.length, 1);
    assert.deepEqual(
      deletedRelations.sort(),
      [
        'address',
        'buyingStreakPurchaseDay',
        'buyingStreakRewardProgress',
        'cart',
        'deviceToken',
        'notification',
        'passwordResetOtp',
        'review',
        'wishlist',
      ],
    );
    console.log('Admin customer removal tests passed.');
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
