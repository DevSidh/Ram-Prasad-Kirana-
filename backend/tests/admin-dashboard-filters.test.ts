import assert from 'node:assert/strict';
import express, { type RequestHandler } from 'express';
import type { PrismaClient } from '@prisma/client';
import { createAdminRouter } from '../src/routes/admin.js';

async function main(): Promise<void> {
  const calls: Array<{ kind: string; args: any }> = [];
  const prisma = {
    product: { count: async () => 4 },
    user: { count: async () => 2 },
    $queryRaw: async () => [{ outOfStock: 0n, lowStock: 1n }],
    order: {
      groupBy: async (args: any) => { calls.push({ kind: 'orders', args }); return [{ status: 'DELIVERED', _count: { _all: 1 } }]; },
      aggregate: async (args: any) => { calls.push({ kind: 'sales', args }); return { _sum: { total: 100 } }; },
      findMany: async (args: any) => { calls.push({ kind: 'recent', args }); return []; },
    },
  } as unknown as PrismaClient;
  const allow: RequestHandler = (_req, _res, next) => next();
  const app = express();
  app.use('/admin', createAdminRouter(prisma, allow, allow));
  const server = app.listen(0);
  try {
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const address = server.address();
    assert(address && typeof address !== 'string');
    const endpoint = `http://127.0.0.1:${address.port}/admin/dashboard`;
    assert.equal((await fetch(`${endpoint}?day=2026-11-04`)).status, 200);
    for (const { args } of calls) {
      assert.equal(args.where.createdAt.gte.toISOString(), '2026-11-03T18:15:00.000Z');
      assert.equal(args.where.createdAt.lt.toISOString(), '2026-11-04T18:15:00.000Z');
    }
    for (const { args } of calls.filter((call) => call.kind === 'sales')) {
      assert.equal(args.where.status.not, 'CANCELLED');
    }
    calls.length = 0;
    assert.equal((await fetch(`${endpoint}?day=2026-02-30`)).status, 400);
    assert.equal((await fetch(`${endpoint}?day=bad`)).status, 400);
    assert.equal(calls.length, 0);
    assert.equal((await fetch(endpoint)).status, 200);
    assert.equal(calls.find((call) => call.kind === 'orders')?.args.where.createdAt, undefined);
    assert.equal(calls.filter((call) => call.kind === 'sales')[1].args.where.createdAt, undefined);
    console.log('Dashboard filters apply Nepal calendar dates to sales and orders.');
  } finally {
    await new Promise<void>((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  }
}

void main().catch((error: unknown) => { console.error(error); process.exitCode = 1; });
