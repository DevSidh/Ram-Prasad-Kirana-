import assert from 'node:assert/strict';
import type { Prisma } from '@prisma/client';
import { InventoryService } from '../src/services/inventory.js';

async function run(): Promise<void> {
  const service = new InventoryService({} as never);
  const batchDates: Array<Record<string, unknown>> = [];
  const orderedBatches = [
    { id: 'earliest', productId: 'product-1', remainingQuantity: 2 },
    { id: 'next', productId: 'product-1', remainingQuantity: 4 },
  ];
  const tx = {
    $queryRaw: async (
      strings: TemplateStringsArray,
      ..._values: unknown[]
    ) => {
      const query = strings.join('?');
      if (query.includes('"InventoryBatch"')) return orderedBatches;
      if (query.includes('FROM "Inventory"')) {
        return [{ totalStock: 10, reservedStock: 0 }];
      }
      return [];
    },
    $executeRaw: async () => 1,
    inventory: {
      findUnique: async () => ({ totalStock: 6, reservedStock: 6 }),
    },
    inventoryTransaction: {
      create: async () => ({ id: 'transaction-1' }),
    },
    inventoryBatch: {
      create: async ({ data }: { data: Record<string, unknown> }) => {
        batchDates.push(data);
        return { id: 'received-batch' };
      },
    },
  } as unknown as Prisma.TransactionClient;

  const manufacturedAt = new Date('2026-01-01T00:00:00.000Z');
  const expiresAt = new Date('2027-01-01T00:00:00.000Z');
  await service.receiveBatch(
    tx,
    'product-1',
    5,
    'admin:user-1',
    {
      lotNumber: 'LOT-1',
      manufacturedAt,
      expiresAt,
      noExpiry: false,
      datesVerified: true,
    },
    'user-1',
    'January receipt',
  );
  assert.equal(batchDates.length, 1);
  assert.equal(batchDates[0].lotNumber, 'LOT-1');
  assert.equal(batchDates[0].manufacturedAt, manufacturedAt);
  assert.equal(batchDates[0].expiresAt, expiresAt);
  assert.equal(batchDates[0].datesVerified, true);

  const reservedAllocations: Array<Record<string, unknown>> = [];
  const reservedTransactions: Array<Record<string, unknown>> = [];
  const reservedQueries: string[] = [];
  const reservedTx = {
    $queryRaw: async <T>(query: Prisma.Sql): Promise<T> => {
      reservedQueries.push(query.sql);
      if (query.sql.includes('FROM "InventoryBatch"')) {
        return orderedBatches as T;
      }
      if (query.sql.includes('UPDATE "InventoryBatch"')) {
        return [{ id: 'earliest' }, { id: 'next' }] as T;
      }
      if (query.sql.includes('UPDATE "Inventory"')) {
        return [{
          id: 'inventory-1',
          productId: 'product-1',
          totalStock: 5,
          reservedStock: 0,
        }] as T;
      }
      throw new Error(`Unexpected reserved stock query: ${query.sql}`);
    },
    orderBatchAllocation: {
      createMany: async ({ data }: { data: Array<Record<string, unknown>> }) => {
        reservedAllocations.push(...data);
        return { count: data.length };
      },
    },
    inventoryTransaction: {
      createMany: async ({ data }: { data: Array<Record<string, unknown>> }) => {
        reservedTransactions.push(...data);
        return { count: data.length };
      },
    },
  } as unknown as Prisma.TransactionClient;
  await service.commitReservedStock(
    reservedTx,
    [{ productId: 'product-1', quantity: 5 }],
    'order-1',
  );
  assert.deepEqual(
    reservedAllocations.map(({ batchId, quantity }) => ({ batchId, quantity })),
    [
      { batchId: 'earliest', quantity: 2 },
      { batchId: 'next', quantity: 3 },
    ],
  );
  assert.equal(reservedTransactions.length, 1);
  assert.equal(reservedTransactions[0].balanceAfter, 5);
  assert.equal(reservedQueries.length, 3);
  assert.match(reservedQueries[2], /"reservedStock" = inventory\."reservedStock" - requested\."quantity"/);
  assert.match(reservedQueries[2], /AND inventory\."reservedStock" >= requested\."quantity"/);
  const allocationQuery = reservedQueries.find((query) =>
    query.includes('"InventoryBatch"'),
  );
  assert.match(allocationQuery ?? '', /"expiresAt" IS NULL OR "expiresAt" >=/);
  assert.match(allocationQuery ?? '', /"expiresAt" ASC/);

  const optimizedAllocations: Array<Record<string, unknown>> = [];
  const inventoryTransactions: Array<Record<string, unknown>> = [];
  const optimizedQueries: string[] = [];
  const optimizedTx = {
    $queryRaw: async <T>(query: Prisma.Sql): Promise<T> => {
      optimizedQueries.push(query.sql);
      if (query.sql.includes('FROM "InventoryBatch"')) {
        return [
          { id: 'p1-earliest', productId: 'product-1', remainingQuantity: 2 },
          { id: 'p1-next', productId: 'product-1', remainingQuantity: 4 },
          { id: 'p2-only', productId: 'product-2', remainingQuantity: 3 },
        ] as T;
      }
      if (query.sql.includes('UPDATE "InventoryBatch"')) {
        return [
          { id: 'p1-earliest' },
          { id: 'p1-next' },
          { id: 'p2-only' },
        ] as T;
      }
      if (query.sql.includes('UPDATE "Inventory"')) {
        return [
          {
            id: 'inventory-1',
            productId: 'product-1',
            totalStock: 5,
            reservedStock: 0,
          },
          {
            id: 'inventory-2',
            productId: 'product-2',
            totalStock: 7,
            reservedStock: 0,
          },
        ] as T;
      }
      throw new Error(`Unexpected optimized inventory query: ${query.sql}`);
    },
    inventoryTransaction: {
      createMany: async ({ data }: {
        data: Array<Record<string, unknown>>;
      }) => {
        inventoryTransactions.push(...data);
        return { count: data.length };
      },
    },
    orderBatchAllocation: {
      createMany: async ({ data }: {
        data: Array<Record<string, unknown>>;
      }) => {
        optimizedAllocations.push(...data);
        return { count: data.length };
      },
    },
  } as unknown as Prisma.TransactionClient;
  await service.commitOrderStock(
    optimizedTx,
    [
      { productId: 'product-2', quantity: 3 },
      { productId: 'product-1', quantity: 5 },
    ],
    'order-optimized',
  );
  assert.equal(optimizedQueries.length, 3);
  assert.deepEqual(
    optimizedAllocations.map(({ productId, batchId, quantity }) => ({
      productId,
      batchId,
      quantity,
    })),
    [
      { productId: 'product-1', batchId: 'p1-earliest', quantity: 2 },
      { productId: 'product-1', batchId: 'p1-next', quantity: 3 },
      { productId: 'product-2', batchId: 'p2-only', quantity: 3 },
    ],
  );
  assert.deepEqual(
    inventoryTransactions.map(({ inventoryId, quantity, balanceAfter }) => ({
      inventoryId,
      quantity,
      balanceAfter,
    })),
    [
      { inventoryId: 'inventory-1', quantity: 5, balanceAfter: 5 },
      { inventoryId: 'inventory-2', quantity: 3, balanceAfter: 7 },
    ],
  );

  console.log('Inventory batches preserve dates and allocate stock FEFO.');
}

run().catch((error: unknown) => {
  console.error('Inventory batch tests failed:', error);
  process.exitCode = 1;
});
