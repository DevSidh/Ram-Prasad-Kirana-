import assert from 'node:assert/strict';
import express, { type RequestHandler } from 'express';
import type { PrismaClient } from '@prisma/client';
import { createReviewRouter } from '../src/routes/reviews.js';

async function main(): Promise<void> {
  const reviewUpserts: unknown[] = [];
  const productUpdates: unknown[] = [];
  const wholesaleUpdates: unknown[] = [];
  const prisma = {
    $transaction: async (operation: (transaction: unknown) => unknown) =>
      operation(prisma),
    product: {
      findFirst: async ({ where }: { where: { id: string } }) =>
        where.id === 'missing' ? null : { id: where.id },
      update: async (args: unknown) => productUpdates.push(args),
    },
    wholesaleItem: {
      findFirst: async ({ where }: { where: { id: string } }) =>
        where.id === 'missing' ? null : { id: where.id },
      update: async (args: unknown) => wholesaleUpdates.push(args),
    },
    review: {
      upsert: async (args: unknown) => reviewUpserts.push(args),
      aggregate: async ({ where }: { where: { productId?: string } }) => ({
        _avg: { rating: where.productId ? 4.5 : 3.5 },
        _count: { _all: where.productId ? 2 : 1 },
      }),
    },
  } as unknown as PrismaClient;
  const authenticate: RequestHandler = (_req, res, next) => {
    res.locals.authenticatedUserId = 'customer-1';
    next();
  };
  const app = express();
  app.use(express.json());
  app.use('/reviews', createReviewRouter(prisma, authenticate));
  const server = app.listen(0);

  try {
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const address = server.address();
    assert(address && typeof address !== 'string');
    const endpoint = `http://127.0.0.1:${address.port}/reviews`;

    const invalid = await fetch(`${endpoint}/products/product-1`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ rating: 6 }),
    });
    assert.equal(invalid.status, 400);
    assert.equal(reviewUpserts.length, 0);

    const productResponse = await fetch(`${endpoint}/products/product-1`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ rating: 5 }),
    });
    assert.equal(productResponse.status, 200);
    assert.deepEqual(await productResponse.json(), {
      data: { rating: 4.5, reviewCount: 2 },
    });
    assert.deepEqual(reviewUpserts[0], {
      where: {
        productId_userId: { productId: 'product-1', userId: 'customer-1' },
      },
      create: { productId: 'product-1', userId: 'customer-1', rating: 5 },
      update: { rating: 5 },
    });

    const wholesaleResponse = await fetch(`${endpoint}/wholesale/item-1`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ rating: 4 }),
    });
    assert.equal(wholesaleResponse.status, 200);
    assert.deepEqual(await wholesaleResponse.json(), {
      data: { rating: 3.5, reviewCount: 1 },
    });
    assert.deepEqual(reviewUpserts[1], {
      where: {
        wholesaleItemId_userId: {
          wholesaleItemId: 'item-1',
          userId: 'customer-1',
        },
      },
      create: {
        wholesaleItemId: 'item-1',
        userId: 'customer-1',
        rating: 4,
      },
      update: { rating: 4 },
    });

    const missing = await fetch(`${endpoint}/products/missing`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ rating: 5 }),
    });
    assert.equal(missing.status, 404);
    assert.equal(productUpdates.length, 1);
    assert.equal(wholesaleUpdates.length, 1);
    console.log('Product and wholesale rating tests passed.');
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
