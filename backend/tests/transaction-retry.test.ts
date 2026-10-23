import assert from 'node:assert/strict';
import { Prisma, type PrismaClient } from '@prisma/client';
import { runTransactionWithRetry } from '../src/services/transaction-retry.js';

function transactionError(code: string): Prisma.PrismaClientKnownRequestError {
  return new Prisma.PrismaClientKnownRequestError(
    code === 'P2028'
      ? 'Transaction API error: Transaction not found; it refers to an old closed transaction.'
      : 'Transaction failed.',
    { code, clientVersion: 'test' },
  );
}

async function run(): Promise<void> {
  let attempts = 0;
  const prisma = {
    $transaction: async (
      operation: (transaction: Prisma.TransactionClient) => Promise<string>,
      options: { maxWait: number; timeout: number },
    ) => {
      assert.equal(options.maxWait, 10_000);
      assert.equal(options.timeout, 15_000);
      attempts += 1;
      if (attempts < 3) throw transactionError('P2034');
      return operation({} as Prisma.TransactionClient);
    },
  } as unknown as Pick<PrismaClient, '$transaction'>;

  assert.equal(
    await runTransactionWithRetry(prisma, async () => 'saved'),
    'saved',
  );
  assert.equal(attempts, 3);

  let closedTransactionAttempts = 0;
  const closedTransactionPrisma = {
    $transaction: async (
      operation: (transaction: Prisma.TransactionClient) => Promise<string>,
    ) => {
      closedTransactionAttempts += 1;
      if (closedTransactionAttempts === 1) {
        throw transactionError('P2028');
      }
      return operation({} as Prisma.TransactionClient);
    },
  } as unknown as Pick<PrismaClient, '$transaction'>;
  assert.equal(
    await runTransactionWithRetry(
      closedTransactionPrisma,
      async () => 'saved',
    ),
    'saved',
  );
  assert.equal(closedTransactionAttempts, 2);

  let timedOutTransactionAttempts = 0;
  const timedOutPrisma = {
    $transaction: async () => {
      timedOutTransactionAttempts += 1;
      throw new Prisma.PrismaClientKnownRequestError(
        'Transaction API error: Transaction already closed: timeout.',
        { code: 'P2028', clientVersion: 'test' },
      );
    },
  } as unknown as Pick<PrismaClient, '$transaction'>;
  await assert.rejects(
    runTransactionWithRetry(timedOutPrisma, async () => 'unreachable'),
    (error: unknown) =>
      error instanceof Prisma.PrismaClientKnownRequestError &&
      error.code === 'P2028',
  );
  assert.equal(timedOutTransactionAttempts, 1);

  let exhaustedAttempts = 0;
  const exhaustedPrisma = {
    $transaction: async () => {
      exhaustedAttempts += 1;
      throw transactionError('P2034');
    },
  } as unknown as Pick<PrismaClient, '$transaction'>;
  await assert.rejects(
    runTransactionWithRetry(exhaustedPrisma, async () => 'unreachable'),
    (error: unknown) =>
      error instanceof Prisma.PrismaClientKnownRequestError &&
      error.code === 'P2034',
  );
  assert.equal(exhaustedAttempts, 3);

  let nonRetryableAttempts = 0;
  const nonRetryableError = new Error('Validation failure');
  const nonRetryablePrisma = {
    $transaction: async () => {
      nonRetryableAttempts += 1;
      throw nonRetryableError;
    },
  } as unknown as Pick<PrismaClient, '$transaction'>;
  await assert.rejects(
    runTransactionWithRetry(nonRetryablePrisma, async () => 'unreachable'),
    nonRetryableError,
  );
  assert.equal(nonRetryableAttempts, 1);

  console.log('Admin transaction retry tests passed.');
}

void run().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
