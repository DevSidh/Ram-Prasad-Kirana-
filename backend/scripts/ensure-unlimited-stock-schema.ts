/**
 * Applies the additive Turso/libSQL columns used to represent unlimited stock.
 * It is intentionally idempotent and never changes an existing stock value.
 */
import 'dotenv/config';
import { createTursoPrismaClient } from '../src/turso-prisma.js';

async function ensureColumn(
  prisma: ReturnType<typeof createTursoPrismaClient>,
  table: 'Inventory' | 'WholesaleItem',
): Promise<void> {
  const columns = await prisma.$queryRawUnsafe<Array<{ name: string }>>(
    `PRAGMA table_info(\"${table}\")`,
  );
  if (columns.some((column) => column.name === 'isUnlimited')) return;
  await prisma.$executeRawUnsafe(
    `ALTER TABLE \"${table}\" ADD COLUMN \"isUnlimited\" INTEGER NOT NULL DEFAULT 0`,
  );
}

async function main(): Promise<void> {
  const prisma = createTursoPrismaClient();
  try {
    await ensureColumn(prisma, 'Inventory');
    await ensureColumn(prisma, 'WholesaleItem');
    console.log('Unlimited-stock columns are ready.');
  } finally {
    await prisma.$disconnect();
  }
}

void main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
