import assert from 'node:assert/strict';
import express from 'express';
import jwt from 'jsonwebtoken';
import type { PrismaClient } from '@prisma/client';
import { createAuthMiddleware } from '../src/middleware/auth.js';

const secret = 'admin-auth-tests-use-a-random-independent-secret';
const users = new Map<string, {
  role: string;
  isActive: boolean;
  tokenVersion: number;
}>([
  ['admin-user', { role: 'ADMIN', isActive: true, tokenVersion: 0 }],
  ['customer-user', { role: 'CUSTOMER', isActive: true, tokenVersion: 0 }],
  ['delivery-user', { role: 'DELIVERY_PERSON', isActive: true, tokenVersion: 0 }],
  ['inactive-user', { role: 'ADMIN', isActive: false, tokenVersion: 0 }],
]);
const prisma = {
  user: {
    findUnique: async ({ where }: { where: { id: string } }) => users.get(where.id) ?? null,
  },
} as unknown as PrismaClient;
const { authenticateToken, requireAdmin, requireDeliveryPerson } =
  createAuthMiddleware(prisma, secret);
const app = express();
app.get('/admin', authenticateToken, requireAdmin, (_req, res) => res.sendStatus(204));
app.get('/delivery', authenticateToken, requireDeliveryPerson, (_req, res) => res.sendStatus(204));

async function run(): Promise<void> {
  const server = app.listen(0);
  try {
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const address = server.address();
    assert(address && typeof address !== 'string');
    const endpoint = `http://127.0.0.1:${address.port}/admin`;
    const request = (token?: string) => fetch(endpoint, {
      headers: token ? { authorization: `Bearer ${token}` } : {},
    });

    assert.equal((await request()).status, 401, 'missing token is unauthenticated');
    assert.equal((await request('not-a-jwt')).status, 401, 'invalid token is unauthenticated');
    assert.equal(
      (await request(jwt.sign({ id: 'admin-user' }, secret, { expiresIn: -1 }))).status,
      401,
      'expired token is unauthenticated',
    );
    assert.equal((await request(jwt.sign({ id: 'customer-user' }, secret))).status, 403);
    const deliveryEndpoint = endpoint.replace('/admin', '/delivery');
    const requestDelivery = (token: string) => fetch(deliveryEndpoint, {
      headers: { authorization: `Bearer ${token}` },
    });
    assert.equal(
      (await requestDelivery(jwt.sign({ id: 'customer-user' }, secret))).status,
      403,
      'customers cannot access delivery operations',
    );
    assert.equal(
      (await requestDelivery(jwt.sign({ id: 'delivery-user' }, secret))).status,
      204,
      'active delivery staff can access delivery operations',
    );
    assert.equal((await request(jwt.sign({ id: 'inactive-user' }, secret))).status, 401);
    assert.equal((await request(jwt.sign({ id: 'admin-user' }, secret))).status, 204);
    const oldToken = jwt.sign({ id: 'admin-user', tokenVersion: 0 }, secret);
    users.get('admin-user')!.tokenVersion = 1;
    assert.equal((await request(oldToken)).status, 401, 'revoked tokens are rejected');
    assert.equal(
      (await request(jwt.sign({ id: 'admin-user', tokenVersion: 1 }, secret))).status,
      204,
      'a token with the current version remains valid',
    );
    console.log('Admin authentication middleware tests passed.');
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
