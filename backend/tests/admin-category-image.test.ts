import assert from 'node:assert/strict';
import express, { type RequestHandler } from 'express';
import type { PrismaClient } from '@prisma/client';
import { createAdminRouter } from '../src/routes/admin.js';

let savedCategory: Record<string, unknown> | null = null;

const prisma = {
  category: {
    findMany: async () => savedCategory ? [savedCategory] : [],
    create: async ({ data }: { data: Record<string, unknown> }) => {
      savedCategory = {
        id: 'category-1',
        isActive: true,
        ...data,
        _count: { products: 0 },
      };
      return savedCategory;
    },
    update: async ({
      data,
    }: {
      where: { id: string };
      data: Record<string, unknown>;
    }) => {
      assert.equal(savedCategory?.id, 'category-1');
      savedCategory = {
        ...savedCategory,
        ...data,
        _count: { products: 0 },
      };
      return savedCategory;
    },
  },
} as unknown as PrismaClient;

const allow: RequestHandler = (_req, _res, next) => next();
const app = express();
app.use(express.json());
app.use('/admin', createAdminRouter(prisma, allow, allow));

async function run(): Promise<void> {
  const server = app.listen(0);
  try {
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const address = server.address();
    assert(address && typeof address !== 'string');
    const baseUrl = `http://127.0.0.1:${address.port}/admin/categories`;

    const create = await fetch(baseUrl, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        name: 'Fresh Produce',
        slug: 'fresh-produce',
        imageUrl: 'https://cdn.example.test/aisles/fresh-produce.webp',
      }),
    });
    assert.equal(create.status, 201);
    const created = await create.json() as {
      category: { imageUrl: string };
    };
    assert.equal(
      created.category.imageUrl,
      'https://cdn.example.test/aisles/fresh-produce.webp',
    );

    const update = await fetch(`${baseUrl}/category-1`, {
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ imageUrl: null }),
    });
    assert.equal(update.status, 200);
    assert.equal(savedCategory?.imageUrl, null);

    const list = await fetch(baseUrl);
    const result = await list.json() as {
      categories: Array<{ imageUrl: string | null }>;
    };
    assert.equal(result.categories[0]?.imageUrl, null);
    console.log('Admin category image tests passed.');
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
