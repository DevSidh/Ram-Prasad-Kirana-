import assert from 'node:assert/strict';
import express, { type RequestHandler } from 'express';
import type { PrismaClient } from '@prisma/client';
import { createAdminRouter } from '../src/routes/admin.js';

async function main(): Promise<void> {
  const updatedAt = new Date('2026-11-10T10:00:00.000Z');
  const expiresAt = new Date('2026-11-12T00:00:00.000Z');
  const queries: string[] = [];
  const queryValues: unknown[][] = [];
  const batch = {
    id: 'batch-1',
    productId: 'product-1',
    productName: 'Milk',
    sku: 'MILK-1L',
    barcode: null,
    imageUrl: null,
    imageMimeType: null,
    updatedAt,
    categoryName: 'Dairy',
    unitLabel: '1 kg',
    lowStockThreshold: 2n,
    lotNumber: 'LOT-1',
    manufacturedAt: null,
    expiresAt,
    noExpiry: false,
    datesVerified: true,
    receivedQuantity: 5000n,
    remainingQuantity: 3000n,
    purchasePrice: null,
  };
  const prisma = {
    $queryRaw: async (query: { sql: string; values: unknown[] }) => {
      queries.push(query.sql);
      queryValues.push(query.values);
      return query.sql.includes('COUNT(*)')
        ? [{ count: 1n }]
        : [batch];
    },
    inventoryBatch: {
      count: async () => 1,
      groupBy: async () => [{ productId: 'product-1' }],
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
    const response = await fetch(
      `http://127.0.0.1:${address.port}/admin/inventory/expiry?status=all`,
    );
    assert.equal(response.status, 200);
    const body = await response.json() as {
      batches: Array<Record<string, unknown>>;
      summary: { expiringSoonBatches: number };
      pagination: { total: number };
    };
    assert.equal(queries.length, 2);
    assert.equal(body.pagination.total, 1);
    assert.equal(body.summary.expiringSoonBatches, 1);
    assert.equal(body.batches[0].lowStockThreshold, 2);
    assert.equal(body.batches[0].receivedQuantity, 5);
    assert.equal(body.batches[0].remainingQuantity, 3);
    const search = "LOT-1' OR 1=1 --";
    const filtered = await fetch(`http://127.0.0.1:${address.port}/admin/inventory/expiry?search=${encodeURIComponent(search)}&categoryId=dairy&status=expiring`);
    assert.equal(filtered.status, 200);
    assert(queries.at(-1)?.includes('POSITION('));
    assert(!queries.at(-1)?.includes(search));
    assert(queryValues.at(-1)?.includes(search.toLowerCase()));
    console.log('Admin expiry inventory serializes CockroachDB integer values.');
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
