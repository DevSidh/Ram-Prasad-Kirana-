import assert from 'node:assert/strict';
import express, { type RequestHandler } from 'express';
import type { PrismaClient } from '@prisma/client';
import { createAdminRouter } from '../src/routes/admin.js';

async function main(): Promise<void> {
  let query: unknown;
  const createdAt = new Date('2026-10-22T01:00:00.000Z');
  const prisma = {
    order: {
      findMany: async (args: unknown) => {
        query = args;
        return [{ id: 'order-1', orderNumber: 'FH-1001', createdAt }];
      },
    },
  } as unknown as PrismaClient;
  const adminOnly: RequestHandler = (req, res, next) => {
    if (req.header('x-admin') !== 'allowed') {
      return res.status(403).json({ error: 'Admin access is required.' });
    }
    return next();
  };
  const allow: RequestHandler = (_req, _res, next) => next();
  const app = express();
  app.use('/admin', createAdminRouter(prisma, allow, adminOnly));
  const server = app.listen(0);

  try {
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const address = server.address();
    assert(address && typeof address !== 'string');
    const endpoint = `http://127.0.0.1:${address.port}/admin/orders/alerts`;
    const denied = await fetch(endpoint);
    assert.equal(denied.status, 403);

    const invalidLimit = await fetch(`${endpoint}?limit=101`, {
      headers: { 'x-admin': 'allowed' },
    });
    assert.equal(invalidLimit.status, 400);

    const response = await fetch(`${endpoint}?limit=25`, {
      headers: { 'x-admin': 'allowed' },
    });
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), {
      orders: [{
        id: 'order-1',
        orderNumber: 'FH-1001',
        createdAt: createdAt.toISOString(),
      }],
    });
    assert.deepEqual(query, {
      orderBy: { createdAt: 'desc' },
      take: 25,
      select: { id: true, orderNumber: true, createdAt: true },
    });
    console.log('Admin order alert endpoint tests passed.');
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
