import assert from 'node:assert/strict';
import express, { type RequestHandler } from 'express';
import type { PrismaClient } from '@prisma/client';
import { createAdminBillingRouter } from '../src/routes/admin-billing.js';
import type { InventoryService } from '../src/services/inventory.js';

async function main(): Promise<void> {
  const exchanges: Array<Record<string, any>> = [];
  let inventoryReturns = 0;
  let inventorySales = 0;
  const sale = {
    id: 'sale-1',
    shiftId: 'shift-1',
    receiptNumber: 'POS-1',
    status: 'COMPLETED',
    paymentStatus: 'COMPLETED',
    subtotal: 20,
    total: 20,
    refundedAmount: 0,
    shift: { cashierId: 'cashier-1' },
    items: [{
      id: 'sale-item-1',
      productId: 'product-1',
      productName: 'Tea',
      sku: 'TEA-1',
      quantity: 2,
      weightGrams: null,
      unitPrice: 10,
      lineTotal: 20,
    }],
    refunds: [],
  };
  const transaction = {
    posShift: {
      findFirst: async () => ({ id: 'shift-1' }),
    },
    posHeldSale: {
      count: async () => 0,
    },
    posSale: {
      findUnique: async () => ({
        ...sale,
        exchanges: exchanges
          .filter((exchange) => exchange.saleId === sale.id)
          .map((exchange) => ({ ...exchange, items: exchange.items })),
      }),
    },
    posExchange: {
      findUnique: async ({ where }: {
        where: { id?: string; idempotencyKey?: string };
      }) => exchanges.find((exchange) =>
        (where.id && exchange.id === where.id) ||
        (where.idempotencyKey &&
          exchange.idempotencyKey === where.idempotencyKey)) ?? null,
      create: async ({ data }: {
        data: Record<string, any>;
      }) => {
        const created = {
          id: `exchange-${exchanges.length + 1}`,
          requestedAt: new Date('2026-11-12T08:00:00.000Z'),
          ...data,
          items: data.items.create.map((item: Record<string, unknown>, index: number) => ({
            id: `exchange-item-${exchanges.length + 1}-${index + 1}`,
            ...item,
          })),
          sale: { receiptNumber: sale.receiptNumber },
        };
        exchanges.push(created);
        return created;
      },
      update: async ({ where, data }: {
        where: { id: string };
        data: Record<string, unknown>;
      }) => {
        const exchange = exchanges.find((item) => item.id === where.id);
        assert(exchange);
        Object.assign(exchange, data);
        return exchange;
      },
      findMany: async () => exchanges,
    },
    product: {
      findMany: async ({ where }: {
        where: { id: { in: string[] } };
      }) => where.id.in.map((id) => ({
        id,
        name: 'Replacement',
        sku: id.toUpperCase(),
        price: id === 'product-cheaper' ? 5 : 15,
        unitLabel: '1 pc',
        inventory: { totalStock: 20, reservedStock: 0 },
      })),
    },
  };
  const prisma = {
    $transaction: async <T>(callback: (tx: unknown) => Promise<T>) =>
      callback(transaction),
  } as unknown as PrismaClient;
  const inventory = {
    restockPosSale: async () => {
      inventoryReturns += 1;
    },
    consumeStockForPosSale: async () => {
      inventorySales += 1;
    },
  } as unknown as InventoryService;
  const authenticate: RequestHandler = (req, res, next) => {
    res.locals.authenticatedUserId = 'cashier-1';
    res.locals.authenticatedUserRole =
      req.header('x-test-role') ?? 'BILLING_STAFF';
    next();
  };
  const adminOnly: RequestHandler = (req, res, next) =>
    req.header('x-test-role') === 'ADMIN'
      ? next()
      : res.status(403).json({ error: 'Administrator access required.' });
  const app = express();
  app.use(express.json());
  app.use(
    '/billing',
    authenticate,
    createAdminBillingRouter(prisma, inventory, adminOnly),
  );
  const server = app.listen(0);

  try {
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const address = server.address();
    assert(address && typeof address !== 'string');
    const endpoint = `http://127.0.0.1:${address.port}/billing/sales/sale-1/exchanges`;
    const exchange = (idempotencyKey: string, productId: string) =>
      fetch(endpoint, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          idempotencyKey,
          returnedItems: [{ saleItemId: 'sale-item-1', quantity: 1 }],
          replacementItems: [{ productId, quantity: 1 }],
          paymentMethod: productId === 'product-cheaper' ? undefined : 'CASH',
          restockReturnedItems: true,
        }),
      });

    const positiveResponse = await exchange(
      '550e8400-e29b-41d4-a716-446655440001',
      'product-costlier',
    );
    assert.equal(positiveResponse.status, 201);
    const positiveBody = await positiveResponse.json() as {
      exchange: { difference: number; status: string };
    };
    assert.equal(positiveBody.exchange.difference, 5);
    assert.equal(positiveBody.exchange.status, 'COMPLETED');
    assert.equal(inventoryReturns, 1);
    assert.equal(inventorySales, 1);

    const replay = await exchange(
      '550e8400-e29b-41d4-a716-446655440001',
      'product-costlier',
    );
    assert.equal(replay.status, 200);
    assert.equal(inventoryReturns, 1);
    assert.equal(inventorySales, 1);

    const negativeResponse = await exchange(
      '550e8400-e29b-41d4-a716-446655440002',
      'product-cheaper',
    );
    assert.equal(negativeResponse.status, 201);
    const negativeBody = await negativeResponse.json() as {
      exchange: { id: string; difference: number; status: string };
    };
    assert.equal(negativeBody.exchange.difference, -5);
    assert.equal(negativeBody.exchange.status, 'REFUND_REQUESTED');
    assert.equal(inventoryReturns, 1);
    assert.equal(inventorySales, 1);

    const unapproved = await fetch(
      `${endpoint.replace('/sales/sale-1/exchanges', '')}/exchanges/${negativeBody.exchange.id}`,
      {
        method: 'PATCH',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          decision: 'APPROVE',
          refundPaymentMethod: 'CASH',
        }),
      },
    );
    assert.equal(unapproved.status, 403);

    const approved = await fetch(
      `${endpoint.replace('/sales/sale-1/exchanges', '')}/exchanges/${negativeBody.exchange.id}`,
      {
        method: 'PATCH',
        headers: {
          'content-type': 'application/json',
          'x-test-role': 'ADMIN',
        },
        body: JSON.stringify({
          decision: 'APPROVE',
          refundPaymentMethod: 'CASH',
        }),
      },
    );
    assert.equal(approved.status, 200);
    assert.equal(inventoryReturns, 2);
    assert.equal(inventorySales, 2);

    const duplicateReturn = await exchange(
      '550e8400-e29b-41d4-a716-446655440003',
      'product-costlier',
    );
    assert.equal(duplicateReturn.status, 409);
    console.log('POS exchange stock, approval, and idempotency checks passed.');
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
