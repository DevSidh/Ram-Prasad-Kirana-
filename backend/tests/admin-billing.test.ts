import assert from 'node:assert/strict';
import express, { type RequestHandler } from 'express';
import type { PrismaClient } from '@prisma/client';
import { createAdminBillingRouter } from '../src/routes/admin-billing.js';
import type { InventoryService } from '../src/services/inventory.js';

async function main(): Promise<void> {
  let activeShift: Record<string, unknown> | null = null;
  let stockWasConsumed = false;
  let committedSale: Record<string, unknown> | null = null;
  let saleWrites = 0;
  let stockConsumptionCount = 0;
  let stockConsumptionCashierId: string | null = null;
  const transaction = {
    posShift: {
      findFirst: async ({ where }: {
        where: { cashierId: string; status: string };
      }) => activeShift?.cashierId === where.cashierId &&
          activeShift.status === where.status
        ? activeShift
        : null,
      create: async ({ data }: {
        data: { cashierId: string; openingCash: number };
      }) => {
        activeShift = {
          id: 'shift-1',
          cashierId: data.cashierId,
          status: 'OPEN',
          openingCash: data.openingCash,
          openedAt: new Date('2026-11-10T05:00:00.000Z'),
          cashier: { id: data.cashierId, name: 'Store Admin' },
        };
        return activeShift;
      },
    },
    product: {
      findMany: async () => [{
        id: 'product-1',
        name: 'Tea',
        sku: 'TEA-1',
        price: 10,
        unitLabel: '1 pc',
        inventory: { totalStock: 10, reservedStock: 0 },
      }],
    },
    posHeldSale: {
      create: async ({ data }: {
        data: { shiftId: string };
      }) => {
        assert.equal(data.shiftId, activeShift?.id);
        return { id: 'held-1' };
      },
    },
    invoiceSequence: {
      upsert: async ({ create }: {
        create: { year: number; nextNumber: number };
      }) => ({
        year: create.year,
        nextNumber: create.nextNumber,
      }),
    },
    posSale: {
      findUnique: async ({ where }: { where: { receiptNumber: string } }) =>
        committedSale?.receiptNumber === where.receiptNumber
          ? { ...committedSale, shift: { cashierId: 'admin-1' } }
          : null,
      create: async ({ data }: {
        data: {
          receiptNumber: string;
          invoiceNumber: string;
          shiftId: string;
          paymentMethod: string;
          paymentStatus: string;
          subtotal: number;
          discount: number;
          total: number;
          items: { create: Array<Record<string, unknown>> };
        };
      }) => {
        saleWrites += 1;
        committedSale = {
          id: 'sale-1',
          receiptNumber: data.receiptNumber,
          invoiceNumber: data.invoiceNumber,
          shiftId: data.shiftId,
          customerName: null,
          customerPhone: null,
          status: 'COMPLETED',
          paymentMethod: data.paymentMethod,
          paymentStatus: data.paymentStatus,
          subtotal: data.subtotal,
          discount: data.discount,
          total: data.total,
          refundedAmount: 0,
          createdAt: new Date('2026-11-10T05:10:00.000Z'),
          items: data.items.create.map((item, index) => ({
            id: `sale-item-${index}`,
            ...item,
          })),
        };
        return committedSale;
      },
    },
  };
  const prisma = {
    $transaction: async <T>(
      callback: (tx: unknown) => Promise<T>,
    ) => callback(transaction),
  } as unknown as PrismaClient;
  const inventory = {
    consumeStockForPosSale: async (
      _tx: unknown,
      _items: unknown,
      _saleId: string,
      cashierId: string,
    ) => {
      stockWasConsumed = true;
      stockConsumptionCount += 1;
      stockConsumptionCashierId = cashierId;
    },
  } as unknown as InventoryService;
  const authenticateAdmin: RequestHandler = (_req, res, next) => {
    res.locals.authenticatedUserId = 'admin-1';
    res.locals.authenticatedUserRole = _req.header('x-test-role') ?? 'ADMIN';
    next();
  };
  const app = express();
  app.use(express.json());
  const adminOnly: RequestHandler = (req, res, next) => {
    if (req.header('x-test-role') !== 'ADMIN') {
      return res.status(403).json({ error: 'Administrator access required.' });
    }
    return next();
  };
  app.use(
    '/billing',
    authenticateAdmin,
    createAdminBillingRouter(prisma, inventory, adminOnly),
  );
  const server = app.listen(0);

  try {
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const address = server.address();
    assert(address && typeof address !== 'string');
    const endpoint = `http://127.0.0.1:${address.port}/billing`;
    const removedOpenRoute = await fetch(`${endpoint}/shifts/open`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ openingCash: 500 }),
    });
    assert.equal(removedOpenRoute.status, 404);
    assert.equal((await fetch(`${endpoint}/shifts`)).status, 404);
    const saleEndpoint = `${endpoint}/sales`;
    const saleResponse = await fetch(saleEndpoint, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        idempotencyKey: '550e8400-e29b-41d4-a716-446655440000',
        items: [{ productId: 'product-1', quantity: 2 }],
        discount: 0,
        paymentMethod: 'CASH',
      }),
    });
    assert.equal(saleResponse.status, 201);
    assert.equal(stockWasConsumed, true);
    const saleBody = await saleResponse.json() as {
      sale: { total: number; items: Array<{ lineTotal: number }> };
    };
    assert.equal(saleBody.sale.total, 20);
    assert.equal(saleBody.sale.items[0].lineTotal, 20);
    const replayResponse = await fetch(saleEndpoint, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        idempotencyKey: '550e8400-e29b-41d4-a716-446655440000',
        items: [{ productId: 'product-1', quantity: 9 }],
        discount: 0,
        paymentMethod: 'CASH',
      }),
    });
    assert.equal(replayResponse.status, 200);
    const replayBody = await replayResponse.json() as {
      sale: { total: number };
    };
    assert.equal(replayBody.sale.total, 20);
    assert.equal(saleWrites, 1);
    assert.equal(stockConsumptionCount, 1);
    assert.equal(stockConsumptionCashierId, 'admin-1');

    activeShift = null;
    const staffSaleResponse = await fetch(saleEndpoint, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-test-role': 'BILLING_STAFF',
      },
      body: JSON.stringify({
        idempotencyKey: '550e8400-e29b-41d4-a716-446655440002',
        items: [{ productId: 'product-1', quantity: 1 }],
        discount: 0,
        paymentMethod: 'CASH',
      }),
    });
    assert.equal(staffSaleResponse.status, 201);
    assert.equal(activeShift?.cashierId, 'admin-1');

    const heldSaleResponse = await fetch(
      `${endpoint}/held-sales`,
      {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-test-role': 'ADMIN',
        },
        body: JSON.stringify({
          items: [{
            productId: 'product-1',
            quantity: 1,
            productName: 'Tea',
            sku: 'TEA-1',
            price: 10,
            unitLabel: '1 pc',
          }],
        }),
      },
    );
    assert.equal(heldSaleResponse.status, 201);
    assert.equal(activeShift?.cashierId, 'admin-1');
    assert.equal(activeShift?.openingCash, 0);

    activeShift = null;
    const adminSaleResponse = await fetch(saleEndpoint, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-test-role': 'ADMIN',
      },
      body: JSON.stringify({
        idempotencyKey: '550e8400-e29b-41d4-a716-446655440003',
        items: [{ productId: 'product-1', quantity: 1 }],
        discount: 0,
        paymentMethod: 'CASH',
      }),
    });
    assert.equal(adminSaleResponse.status, 201);
    assert.equal(activeShift?.cashierId, 'admin-1');
    assert.equal(activeShift?.openingCash, 0);
    assert.equal(committedSale?.shiftId, activeShift?.id);
    assert.equal(stockConsumptionCashierId, 'admin-1');

    assert.equal(
      (await fetch(`${endpoint}/refunds`)).status,
      403,
    );
    assert.equal(
      (await fetch(`${endpoint}/staff`)).status,
      403,
    );
    console.log('POS billing works without cashier shift management.');
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
