import assert from 'node:assert/strict';
import express, { type RequestHandler } from 'express';
import type { PrismaClient } from '@prisma/client';
import { createAdminBillingRouter } from '../src/routes/admin-billing.js';
import type { InventoryService } from '../src/services/inventory.js';

async function main(): Promise<void> {
  let sale = {
    id: 'sale-1',
    receiptNumber: 'POS-1001',
    customerName: 'Ram',
    customerPhone: '9800000000',
    status: 'COMPLETED',
    paymentMethod: 'PENDING',
    paymentStatus: 'PENDING',
    subtotal: 100,
    discount: 0,
    total: 100,
    paidAmount: 10,
    refundedAmount: 0,
    createdAt: new Date('2026-11-10T05:10:00.000Z'),
    shift: { cashierId: 'admin-1' },
    items: [{
      id: 'item-1',
      productId: 'product-1',
      productName: 'Tea',
      sku: 'TEA-1',
      quantity: 1,
      weightGrams: null,
      unitPrice: 100,
      lineTotal: 100,
    }],
    paymentCollections: [{
      id: 'payment-old',
      amount: 10,
      method: 'CASH',
      note: null,
      createdAt: new Date('2026-11-10T05:11:00.000Z'),
    }],
  };
  let pendingQuery: Record<string, unknown> | undefined;
  const transaction = {
    posSale: {
      findUnique: async ({ where }: { where: { id: string } }) =>
        where.id === sale.id ? sale : null,
      updateMany: async ({ data }: {
        data: Record<string, unknown>;
      }) => {
        sale = { ...sale, ...data };
        return { count: 1 };
      },
    },
    posPaymentCollection: {
      create: async ({ data }: {
        data: Record<string, unknown>;
      }) => ({
        id: 'payment-new',
        amount: data.amount,
        method: data.method,
        note: data.note,
        createdAt: new Date('2026-11-10T05:12:00.000Z'),
      }),
    },
  };
  const prisma = {
    posSale: {
      findMany: async ({ where }: { where: Record<string, unknown> }) => {
        pendingQuery = where;
        return [sale];
      },
      count: async () => 1,
    },
    $transaction: async <T>(
      callback: (tx: unknown) => Promise<T>,
    ) => callback(transaction),
  } as unknown as PrismaClient;
  const inventory = {} as InventoryService;
  const authenticateAdmin: RequestHandler = (req, res, next) => {
    res.locals.authenticatedUserId = 'admin-1';
    res.locals.authenticatedUserRole = req.header('x-test-role') ?? 'ADMIN';
    next();
  };
  const app = express();
  app.use(express.json());
  app.use(
    '/billing',
    authenticateAdmin,
    createAdminBillingRouter(prisma, inventory),
  );
  const server = app.listen(0);

  try {
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const address = server.address();
    assert(address && typeof address !== 'string');
    const endpoint = `http://127.0.0.1:${address.port}/billing`;

    const pendingResponse = await fetch(`${endpoint}/pending-payments`);
    assert.equal(pendingResponse.status, 200);
    assert.deepEqual(pendingQuery, {
      paymentStatus: 'PENDING',
      status: { not: 'CANCELLED' },
    });
    const pendingBody = await pendingResponse.json() as {
      sales: Array<{
        paidAmount: number;
        outstandingAmount: number;
        paymentCollections: Array<{ amount: number; method: string }>;
      }>;
    };
    assert.equal(pendingBody.sales[0].paidAmount, 10);
    assert.equal(pendingBody.sales[0].outstandingAmount, 90);
    assert.equal(pendingBody.sales[0].paymentCollections[0].amount, 10);

    const partialResponse = await fetch(
      `${endpoint}/sales/${sale.id}/payments`,
      {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          amount: 20,
          paymentMethod: 'CASH',
          note: 'Part payment',
        }),
      },
    );
    assert.equal(partialResponse.status, 201);
    assert.equal(sale.paidAmount, 30);
    assert.equal(sale.paymentStatus, 'PENDING');
    assert.equal(sale.paymentCollections.length, 1);

    const excessResponse = await fetch(
      `${endpoint}/sales/${sale.id}/payments`,
      {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ amount: 71, paymentMethod: 'DIGITAL' }),
      },
    );
    assert.equal(excessResponse.status, 409);
    assert.equal(sale.paidAmount, 30);

    const subCentResponse = await fetch(
      `${endpoint}/sales/${sale.id}/payments`,
      {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ amount: 0.004, paymentMethod: 'CASH' }),
      },
    );
    assert.equal(subCentResponse.status, 400);
    assert.equal(sale.paidAmount, 30);

    const settlementResponse = await fetch(
      `${endpoint}/sales/${sale.id}/payments`,
      {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          amount: 70,
          paymentMethod: 'DIGITAL',
        }),
      },
    );
    assert.equal(settlementResponse.status, 201);
    assert.equal(sale.paidAmount, 100);
    assert.equal(sale.paymentStatus, 'COMPLETED');
    assert.equal(sale.paymentMethod, 'DIGITAL');
    console.log('Pending-payment listing and partial settlement checks passed.');
  } finally {
    server.close();
  }
}

void main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
