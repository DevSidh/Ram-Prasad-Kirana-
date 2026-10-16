import assert from 'node:assert/strict';
import type { PrismaClient } from '@prisma/client';
import {
  clearAllOrderItemDetails,
  clearOrderItemsInput,
} from '../src/services/order-maintenance.js';

async function run(): Promise<void> {
  assert.equal(
    clearOrderItemsInput.safeParse({ confirmation: 'CONFIRM DELETE' }).success,
    true,
  );
  assert.equal(
    clearOrderItemsInput.safeParse({ confirmation: 'confirm delete' }).success,
    false,
  );
  assert.equal(
    clearOrderItemsInput.safeParse({
      confirmation: 'CONFIRM DELETE',
      scope: 'all',
    }).success,
    false,
  );

  let deleteCalls = 0;
  const prisma = {
    orderItem: {
      deleteMany: async () => {
        deleteCalls += 1;
        return { count: 7 };
      },
    },
  } as unknown as Pick<PrismaClient, 'orderItem'>;

  await assert.rejects(
    clearAllOrderItemDetails(prisma, 'DELETE'),
    /Type CONFIRM DELETE/,
  );
  assert.equal(deleteCalls, 0);
  assert.equal(await clearAllOrderItemDetails(prisma, 'CONFIRM DELETE'), 7);
  assert.equal(deleteCalls, 1);
  console.log('Order item detail cleanup confirmation tests passed.');
}

void run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
