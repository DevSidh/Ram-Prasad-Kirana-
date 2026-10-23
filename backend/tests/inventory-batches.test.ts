import assert from 'node:assert/strict';
import type { Prisma } from '@prisma/client';
import { InventoryService } from '../src/services/inventory.js';

async function run(): Promise<void> {
  const service = new InventoryService({} as never);
  const batchDates: Array<Record<string, unknown>> = [];
  const allocations: Array<Record<string, unknown>> = [];
  const decremented: Array<{ id: string; quantity: number }> = [];
  const sqlQueries: string[] = [];
  const orderedBatches = [
    { id: 'earliest', remainingQuantity: 2 },
    { id: 'next', remainingQuantity: 4 },
  ];
  const tx = {
    $queryRaw: async (
      strings: TemplateStringsArray,
      ..._values: unknown[]
    ) => {
      const query = strings.join('?');
      sqlQueries.push(query);
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
    inventoryBatch: {
      create: async ({ data }: { data: Record<string, unknown> }) => {
        batchDates.push(data);
        return { id: 'received-batch' };
      },
      updateMany: async ({
        where,
        data,
      }: {
        where: { id: string };
        data: { remainingQuantity: { decrement: number } };
      }) => {
        decremented.push({
          id: where.id,
          quantity: data.remainingQuantity.decrement,
        });
        return { count: 1 };
      },
    },
    orderBatchAllocation: {
      create: async ({ data }: { data: Record<string, unknown> }) => {
        allocations.push(data);
        return data;
      },
    },
    inventoryTransaction: {
      create: async () => ({ id: 'transaction-1' }),
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

  await service.commitReservedStock(
    tx,
    [{ productId: 'product-1', quantity: 5 }],
    'order-1',
  );
  assert.deepEqual(decremented, [
    { id: 'earliest', quantity: 2 },
    { id: 'next', quantity: 3 },
  ]);
  assert.deepEqual(
    allocations.map(({ batchId, quantity }) => ({ batchId, quantity })),
    [
      { batchId: 'earliest', quantity: 2 },
      { batchId: 'next', quantity: 3 },
    ],
  );
  const allocationQuery = sqlQueries.find((query) =>
    query.includes('"InventoryBatch"'),
  );
  assert.match(allocationQuery ?? '', /"expiresAt" IS NULL OR "expiresAt" >=/);
  assert.match(allocationQuery ?? '', /"expiresAt" ASC/);

  console.log('Inventory batches preserve dates and allocate stock FEFO.');
}

run().catch((error: unknown) => {
  console.error('Inventory batch tests failed:', error);
  process.exitCode = 1;
});
