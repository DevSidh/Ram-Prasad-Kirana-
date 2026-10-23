import assert from 'node:assert/strict';
import type { Prisma } from '@prisma/client';
import {
  InventoryAdjustmentError,
  InventoryService,
} from '../src/services/inventory.js';

function createTransaction(initialInventory: {
  totalStock: number;
  reservedStock: number;
} | null) {
  let inventory = initialInventory;
  const transactions: Array<Record<string, unknown>> = [];
  let inventoryCreate: Record<string, unknown> | undefined;

  const tx = {
    $queryRaw: async () => inventory ? [{ ...inventory }] : [],
    $executeRaw: async (_strings: TemplateStringsArray, ...values: unknown[]) => {
      inventory = {
        totalStock: values[0] as number,
        reservedStock: inventory!.reservedStock,
      };
      return 1;
    },
    inventory: {
      create: async ({ data }: { data: Record<string, unknown> }) => {
        inventoryCreate = data;
        inventory = {
          totalStock: data.totalStock as number,
          reservedStock: 0,
        };
        return { id: 'inventory-1' };
      },
    },
    inventoryBatch: {
      create: async () => ({ id: 'batch-1' }),
      updateMany: async () => ({ count: 1 }),
    },
    inventoryTransaction: {
      create: async ({ data }: { data: Record<string, unknown> }) => {
        transactions.push(data);
        return data;
      },
    },
  } as unknown as Prisma.TransactionClient;

  return {
    tx,
    transactions,
    get currentInventory() {
      return inventory;
    },
    get inventoryCreate() {
      return inventoryCreate;
    },
  };
}

async function run(): Promise<void> {
  const service = new InventoryService({} as never);

  const existing = createTransaction({ totalStock: 10, reservedStock: 2 });
  await service.setStock(existing.tx, 'product-1', 15, 'admin:user-1', 'Counted');
  assert.equal(existing.transactions.length, 1);
  assert.equal(existing.transactions[0].quantity, 5);
  assert.equal(existing.transactions[0].balanceAfter, 13);

  const reserved = createTransaction({ totalStock: 10, reservedStock: 4 });
  await assert.rejects(
    service.setStock(reserved.tx, 'product-1', 3, 'admin:user-1', 'Counted'),
    InventoryAdjustmentError,
  );
  assert.equal(reserved.transactions.length, 0);

  const missing = createTransaction(null);
  await service.setStock(missing.tx, 'product-2', 7, 'admin:user-2', 'Opening stock');
  assert.deepEqual(missing.inventoryCreate, { productId: 'product-2', totalStock: 7 });
  assert.equal(missing.transactions[0].quantity, 7);
  assert.equal(missing.transactions[0].balanceAfter, 7);

  const restocked = createTransaction({ totalStock: 10, reservedStock: 2 });
  await service.restock(
    restocked.tx,
    [{ productId: 'product-1', quantity: 5 }],
    'admin:user-1',
    'Delivery received',
    'user-1',
  );
  assert.deepEqual(restocked.currentInventory, {
    totalStock: 15,
    reservedStock: 2,
  });
  assert.equal(restocked.transactions[0].type, 'RESTOCKED');
  assert.deepEqual(restocked.transactions[0].performedBy, {
    connect: { id: 'user-1' },
  });
  assert.equal(restocked.transactions[0].quantity, 5);
  assert.equal(restocked.transactions[0].balanceAfter, 13);

  const overLimit = createTransaction({
    totalStock: 2147483645,
    reservedStock: 0,
  });
  await assert.rejects(
    service.restock(
      overLimit.tx,
      [{ productId: 'product-1', quantity: 3 }],
      'admin:user-1',
      'Over limit',
    ),
    InventoryAdjustmentError,
  );

  const firstRestock = createTransaction(null);
  await service.restock(
    firstRestock.tx,
    [{ productId: 'product-2', quantity: 6 }],
    'admin:user-2',
    'First delivery',
    'user-2',
  );
  assert.deepEqual(firstRestock.inventoryCreate, {
    productId: 'product-2',
    totalStock: 6,
  });
  assert.equal(firstRestock.transactions[0].type, 'RESTOCKED');
  assert.deepEqual(firstRestock.transactions[0].performedBy, {
    connect: { id: 'user-2' },
  });
  assert.equal(firstRestock.transactions[0].balanceAfter, 6);

  await assert.rejects(
    service.restock(
      restocked.tx,
      [{ productId: 'product-1', quantity: 0 }],
      'admin:user-1',
      'Invalid',
    ),
    InventoryAdjustmentError,
  );

  await assert.rejects(
    service.setStock(missing.tx, 'product-2', -1, 'admin:user-2', 'Invalid'),
    InventoryAdjustmentError,
  );

  console.log('Admin inventory adjustment tests passed.');
}

void run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
