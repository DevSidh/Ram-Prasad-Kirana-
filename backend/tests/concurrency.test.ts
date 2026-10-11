import assert from 'node:assert/strict';
import type { Prisma, PrismaClient } from '@prisma/client';
import { InventoryService } from '../src/services/inventory.js';

let totalStock = 1;
let reservedStock = 0;
const transactions: Array<Record<string, unknown>> = [];

const transaction = {
  $executeRaw: async (query: TemplateStringsArray, ...values: unknown[]) => {
    const statement = query.join('?');
    const quantity = Number(values[0]);
    if (statement.includes('"reservedStock" = "reservedStock" +')) {
      if (totalStock - reservedStock < quantity) return 0;
      reservedStock += quantity;
      return 1;
    }
    if (statement.includes('"totalStock" = "totalStock" -')) {
      totalStock -= quantity;
      reservedStock -= quantity;
      return 1;
    }
    throw new Error(`Unexpected inventory update: ${statement}`);
  },
  inventory: {
    findUnique: async () => ({ totalStock, reservedStock }),
  },
  inventoryTransaction: {
    create: async ({ data }: { data: Record<string, unknown> }) => {
      transactions.push(data);
    },
  },
} as unknown as Prisma.TransactionClient;

const inventory = new InventoryService({} as PrismaClient);

async function runConcurrencyTest(): Promise<void> {
  console.log('=== STARTING INVENTORY SERVICE CONCURRENCY TEST ===');
  const attempts = await Promise.allSettled([
    inventory.reserveStockForOrder(
      transaction,
      [{ productId: 'prod-apple-1', quantity: 1 }],
      'order-1',
    ),
    inventory.reserveStockForOrder(
      transaction,
      [{ productId: 'prod-apple-1', quantity: 1 }],
      'order-2',
    ),
  ]);

  assert.equal(attempts.filter(({ status }) => status === 'fulfilled').length, 1);
  assert.equal(attempts.filter(({ status }) => status === 'rejected').length, 1);
  assert.equal(totalStock - reservedStock, 0);
  assert.equal(totalStock, 1, 'reserving stock does not deduct it before commit');
  assert.equal(transactions.length, 1);

  await inventory.commitReservedStock(
    transaction,
    [{ productId: 'prod-apple-1', quantity: 1 }],
    'order-1',
  );

  assert.equal(totalStock, 0);
  assert.equal(reservedStock, 0);
  assert.equal(totalStock - reservedStock, 0);
  assert.equal(transactions.length, 2);
  assert.deepEqual(
    transactions.map(({ type }) => type),
    ['RESERVED', 'PURCHASED'],
  );

  console.log('Inventory service prevents overselling and records committed stock.');
}

void runConcurrencyTest().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
