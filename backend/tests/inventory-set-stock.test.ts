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
