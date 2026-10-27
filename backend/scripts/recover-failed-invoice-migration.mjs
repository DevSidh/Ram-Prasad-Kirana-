import { PrismaClient } from '@prisma/client';
import { spawnSync } from 'node:child_process';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const migrationName = '20261117000000_invoices_offline_streak';
const prisma = new PrismaClient();

try {
  const failed = await prisma.$queryRaw`
    SELECT "migration_name"
    FROM "_prisma_migrations"
    WHERE "migration_name" = ${migrationName}
      AND "finished_at" IS NULL
      AND "rolled_back_at" IS NULL
    LIMIT 1
  `;

  if (failed.length === 0) {
    console.log(`No failed ${migrationName} migration needs recovery.`);
  } else {
    const columns = await prisma.$queryRaw`
      SELECT table_name, column_name
      FROM information_schema.columns
      WHERE table_schema = current_schema()
        AND ((table_name = 'Order' AND column_name = 'invoiceNumber')
          OR (table_name = 'PosSale' AND column_name = 'invoiceNumber')
          OR (table_name = 'PosOfflineStreakPurchase'
            AND column_name IN ('id', 'invoiceNumber', 'userId', 'purchaseDate', 'createdAt')))
    `;
    const existingColumns = new Set(
      columns.map((column) => `${column.table_name}.${column.column_name}`),
    );
    const requiredColumns = [
      'Order.invoiceNumber',
      'PosSale.invoiceNumber',
      'PosOfflineStreakPurchase.id',
      'PosOfflineStreakPurchase.invoiceNumber',
      'PosOfflineStreakPurchase.userId',
      'PosOfflineStreakPurchase.purchaseDate',
      'PosOfflineStreakPurchase.createdAt',
    ];

    const tables = await prisma.$queryRaw`
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = current_schema()
        AND table_name IN ('InvoiceSequence', 'PosOfflineStreakPurchase')
    `;
    const existingTables = new Set(tables.map((table) => table.table_name));

    if (
      requiredColumns.some((column) => !existingColumns.has(column)) ||
      !existingTables.has('InvoiceSequence') ||
      !existingTables.has('PosOfflineStreakPurchase')
    ) {
      throw new Error(
        `Refusing to automatically recover ${migrationName}: the database does not have the expected partial-migration schema. Reconcile it manually before deploying.`,
      );
    }

    const backendDir = resolve(dirname(fileURLToPath(import.meta.url)), '..');
    const prismaCli = resolve(backendDir, 'node_modules/prisma/build/index.js');

    await prisma.$executeRaw`ALTER TABLE "PosOfflineStreakPurchase" SET (schema_locked = false)`;
    try {
      await prisma.$executeRaw`CREATE UNIQUE INDEX IF NOT EXISTS "PosOfflineStreakPurchase_invoiceNumber_key" ON "PosOfflineStreakPurchase"("invoiceNumber")`;
      await prisma.$executeRaw`CREATE INDEX IF NOT EXISTS "PosOfflineStreakPurchase_userId_purchaseDate_idx" ON "PosOfflineStreakPurchase"("userId", "purchaseDate")`;
    } finally {
      await prisma.$executeRaw`ALTER TABLE "PosOfflineStreakPurchase" SET (schema_locked = true)`;
    }

    const result = spawnSync(
      process.execPath,
      [prismaCli, 'migrate', 'resolve', '--applied', migrationName],
      { cwd: backendDir, stdio: 'inherit' },
    );

    if (result.error) throw result.error;
    if (result.status !== 0) {
      throw new Error(`Prisma migrate resolve exited with status ${result.status}.`);
    }
  }
} finally {
  await prisma.$disconnect();
}
