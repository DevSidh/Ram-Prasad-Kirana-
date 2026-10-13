import assert from 'node:assert/strict';
import express, { type RequestHandler } from 'express';
import type { PrismaClient } from '@prisma/client';
import { createAccountRouter } from '../src/routes/account.js';

let deleteWhere: { userId: string; id?: string } | undefined;
let deleteCalls = 0;
const prisma = {
  notification: {
    deleteMany: async ({
      where,
    }: {
      where: { userId: string; id?: string };
    }) => {
      deleteCalls++;
      deleteWhere = where;
      return {
        count:
          where.id === undefined
            ? 2
            : where.id === 'notification-1' && where.userId === 'customer-1'
              ? 1
              : 0,
      };
    },
  },
} as unknown as PrismaClient;

const authenticate: RequestHandler = (req, res, next) => {
  const userId = req.header('x-test-user');
  if (userId) res.locals.authenticatedUserId = userId;
  next();
};
const app = express();
app.use('/account', createAccountRouter(prisma, authenticate));

async function run(): Promise<void> {
  const server = app.listen(0);
  try {
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const address = server.address();
    assert(address && typeof address !== 'string');
    const endpoint =
      `http://127.0.0.1:${address.port}/account/notifications`;

    const unauthorized = await fetch(endpoint, { method: 'DELETE' });
    assert.equal(unauthorized.status, 401);
    assert.equal(deleteCalls, 0);

    const response = await fetch(endpoint, {
      method: 'DELETE',
      headers: { 'x-test-user': 'customer-1' },
    });
    assert.equal(response.status, 204);
    assert.equal(deleteCalls, 1);
    assert.deepEqual(deleteWhere, { userId: 'customer-1' });

    const deleteOne = await fetch(`${endpoint}/notification-1`, {
      method: 'DELETE',
      headers: { 'x-test-user': 'customer-1' },
    });
    assert.equal(deleteOne.status, 204);
    assert.deepEqual(deleteWhere, {
      id: 'notification-1',
      userId: 'customer-1',
    });

    const anotherUsersNotification = await fetch(`${endpoint}/notification-1`, {
      method: 'DELETE',
      headers: { 'x-test-user': 'customer-2' },
    });
    assert.equal(anotherUsersNotification.status, 404);
    assert.deepEqual(deleteWhere, {
      id: 'notification-1',
      userId: 'customer-2',
    });
    console.log('Account notification deletion tests passed.');
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
