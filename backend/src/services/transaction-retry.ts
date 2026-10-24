import { Prisma, type PrismaClient } from '@prisma/client';

const MAX_ATTEMPTS = 3;
const TRANSACTION_OPTIONS = {
  maxWait: 10_000,
  timeout: 15_000,
} as const;

function isRetryableTransactionError(error: unknown): boolean {
  if (!(error instanceof Prisma.PrismaClientKnownRequestError)) return false;
  if (error.code === 'P2034') return true;
  return error.code === 'P2028' &&
    /transaction not found|old closed transaction/i.test(error.message);
}

export async function runTransactionWithRetry<T>(
  prisma: Pick<PrismaClient, '$transaction'>,
  operation: (transaction: Prisma.TransactionClient) => Promise<T>,
  options: {
    maxWait: number;
    timeout: number;
    maxAttempts?: number;
  } = TRANSACTION_OPTIONS,
): Promise<T> {
  const { maxAttempts = MAX_ATTEMPTS, maxWait, timeout } = options;
  if (!Number.isInteger(maxAttempts) || maxAttempts < 1) {
    throw new RangeError('Transaction attempts must be a positive integer.');
  }
  for (let attempt = 1; ; attempt += 1) {
    try {
      return await prisma.$transaction(operation, { maxWait, timeout });
    } catch (error) {
      if (!isRetryableTransactionError(error) || attempt >= maxAttempts) {
        throw error;
      }
      await new Promise((resolve) => setTimeout(resolve, attempt * 50));
    }
  }
}
