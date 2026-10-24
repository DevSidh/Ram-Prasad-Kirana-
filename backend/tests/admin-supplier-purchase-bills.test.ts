import assert from 'node:assert/strict';
import express, { type RequestHandler } from 'express';
import type { PrismaClient } from '@prisma/client';
import { createAdminRouter } from '../src/routes/admin.js';

async function main(): Promise<void> {
  const inventoryBatches: Array<Record<string, unknown>> = [];
  const inventoryTransactions: Array<Record<string, unknown>> = [];
  let savedPhoto: Buffer | null = null;
  let savedPhotoMimeType: string | null = null;
  let availableProducts = [
    { id: 'rice', name: 'Rice', sku: 'RICE-1', unitLabel: '1 kg' },
    { id: 'soda', name: 'Soda', sku: 'SODA-1', unitLabel: '1 pc' },
  ];
  const transaction = {
    product: {
      findMany: async ({ where }: {
        where: { id: { in: string[] } };
      }) => availableProducts.filter((product) =>
        where.id.in.includes(product.id),
      ),
    },
    supplierPurchaseBill: {
      create: async ({ data }: {
        data: {
          items: { create: Array<Record<string, unknown>> };
          [key: string]: unknown;
        };
      }) => {
        savedPhoto = data.photoData as Buffer | null;
        savedPhotoMimeType = data.photoMimeType as string | null;
        const items = data.items.create.map((item) => ({
          id: `bill-item-${String(item.productId)}`,
          ...item,
        }));
        return {
          id: 'supplier-bill-1',
          ...data,
          items,
          createdAt: new Date('2026-10-24T05:00:00.000Z'),
        };
      },
    },
    $queryRaw: async () => [{ totalStock: 10, reservedStock: 0 }],
    $executeRaw: async () => 1,
    inventory: {
      create: async ({ data }: { data: Record<string, unknown> }) => ({
        id: 'inventory-1',
        ...data,
      }),
    },
    inventoryBatch: {
      create: async ({ data }: { data: Record<string, unknown> }) => {
        inventoryBatches.push(data);
        return data;
      },
    },
    inventoryTransaction: {
      create: async ({ data }: { data: Record<string, unknown> }) => {
        inventoryTransactions.push(data);
        return data;
      },
    },
  };
  const prisma = {
    $transaction: async <T>(
      callback: (tx: unknown) => Promise<T>,
    ) => callback(transaction),
    supplierPurchaseBill: {
      findUnique: async () => ({
        photoData: savedPhoto,
        photoMimeType: savedPhotoMimeType,
      }),
    },
  } as unknown as PrismaClient;
  const authenticate: RequestHandler = (_req, res, next) => {
    res.locals.authenticatedUserId = 'admin-1';
    res.locals.authenticatedUserRole = 'ADMIN';
    next();
  };
  const requireAdmin: RequestHandler = (_req, _res, next) => next();
  const app = express();
  app.use(express.json());
  app.use('/admin', createAdminRouter(prisma, authenticate, requireAdmin));
  const server = app.listen(0);

  try {
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const address = server.address();
    assert(address && typeof address !== 'string');
    const endpoint =
      `http://127.0.0.1:${address.port}/admin/inventory/purchase-bills`;
    const form = new FormData();
    form.set('bill', JSON.stringify({
      supplierName: 'Local Dealer',
      invoiceNumber: 'INV-204',
      invoiceDate: '2026-10-24T00:00:00.000Z',
      deliveryPerson: 'Hari',
      notes: 'Received in full',
      items: [
        { productId: 'rice', quantity: 1.25, unitCost: 80 },
        { productId: 'soda', quantity: 4, unitCost: 20 },
      ],
    }));
    const photoBytes = Buffer.from([
      0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
    ]);
    form.set('image', new Blob([photoBytes], { type: 'image/png' }), 'bill.png');
    const response = await fetch(endpoint, {
      method: 'POST',
      body: form,
    });
    assert.equal(response.status, 201);
    const body = await response.json() as {
      bill: {
        status: string;
        totalCost: number;
        deliveryPerson: string;
        hasPhoto: boolean;
        items: Array<{ quantity: number; lineTotal: number }>;
      };
    };
    assert.equal(body.bill.status, 'RECEIVED');
    assert.equal(body.bill.totalCost, 180);
    assert.equal(body.bill.deliveryPerson, 'Hari');
    assert.equal(body.bill.hasPhoto, true);
    assert.deepEqual(
      body.bill.items.map((item) => item.lineTotal),
      [100, 80],
    );
    assert.deepEqual(
      inventoryBatches.map((batch) => batch.receivedQuantity),
      [1250, 4],
    );
    assert.equal(inventoryTransactions.length, 2);
    assert.equal(
      inventoryTransactions[0].referenceId,
      'supplier-bill:supplier-bill-1',
    );

    const photoResponse = await fetch(`${endpoint}/supplier-bill-1/photo`);
    assert.equal(photoResponse.status, 200);
    assert.equal(photoResponse.headers.get('content-type'), 'image/png');
    assert.deepEqual(
      Buffer.from(await photoResponse.arrayBuffer()),
      photoBytes,
    );

    const fractionalCountable = await fetch(endpoint, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        supplierName: 'Local Dealer',
        invoiceNumber: 'INV-205',
        invoiceDate: '2026-10-24T00:00:00.000Z',
        items: [{ productId: 'soda', quantity: 1.5, unitCost: 20 }],
      }),
    });
    assert.equal(fractionalCountable.status, 400);

    availableProducts = [];
    const unavailableProduct = await fetch(endpoint, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        supplierName: 'Local Dealer',
        invoiceNumber: 'INV-206',
        invoiceDate: '2026-10-24T00:00:00.000Z',
        items: [{ productId: 'inactive', quantity: 3, unitCost: 15 }],
      }),
    });
    assert.equal(unavailableProduct.status, 409);
    assert.equal(inventoryTransactions.length, 2);
    console.log('Supplier bill inventory receipt transaction tests passed.');
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
