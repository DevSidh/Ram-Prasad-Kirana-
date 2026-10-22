import assert from 'node:assert/strict';
import express, { type RequestHandler } from 'express';
import type { PrismaClient } from '@prisma/client';
import { createAdminRouter } from '../src/routes/admin.js';

async function main(): Promise<void> {
  let capturedWhere: Record<string, unknown> | undefined;
  const prisma = {
    user: {
      count: async () => 1,
      findMany: async ({ where }: { where: Record<string, unknown> }) => {
        capturedWhere = where;
        return [{
          id: 'customer-internal-id',
          userNumber: 42n,
          name: 'Asha Customer',
          email: 'asha@example.com',
          phone: null,
          isActive: true,
          createdAt: new Date('2026-10-01T00:00:00.000Z'),
          _count: { orders: 0 },
          addresses: [],
          orders: [],
        }];
      },
    },
    order: { groupBy: async () => [] },
  } as unknown as PrismaClient;
  const adminOnly: RequestHandler = (req, res, next) =>
    req.header('x-admin') === 'allowed'
      ? next()
      : res.status(403).json({ error: 'Admin access is required.' });
  const allow: RequestHandler = (_req, _res, next) => next();
  const app = express();
  app.use('/admin', createAdminRouter(prisma, allow, adminOnly));
  const server = app.listen(0);

  try {
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const address = server.address();
    assert(address && typeof address !== 'string');
    const response = await fetch(
      `http://127.0.0.1:${address.port}/admin/customers?search=USR-000042`,
      { headers: { 'x-admin': 'allowed' } },
    );
    assert.equal(response.status, 200);
    const body = await response.json() as {
      customers: Array<{ id: string; profileId: string }>;
    };
    assert.equal(body.customers[0].id, 'customer-internal-id');
    assert.equal(body.customers[0].profileId, 'USR-000042');
    const where = capturedWhere as {
      OR: Array<Record<string, unknown>>;
    };
    assert.ok(where.OR.some((entry) => entry.userNumber === 42n));
    console.log('Admin customer ID search tests passed.');
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => (error ? reject(error) : resolve()));
    });
  }
}

void main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
