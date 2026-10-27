import { PrismaClient } from '@prisma/client';
import { spawnSync } from 'node:child_process';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const migrationName = '20261118000000_barcode_scanner_sessions';
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
      SELECT column_name
      FROM information_schema.columns
      WHERE table_schema = current_schema()
        AND table_name = 'BarcodeScannerSession'
        AND column_name IN ('code', 'ownerId', 'barcode', 'expiresAt', 'connectedAt', 'createdAt')
    `;
    const existingColumns = new Set(columns.map((column) => column.column_name));
    const requiredColumns = [
      'code',
      'ownerId',
      'barcode',
      'expiresAt',
      'connectedAt',
      'createdAt',
    ];

    if (requiredColumns.some((column) => !existingColumns.has(column))) {
      throw new Error(
        `Refusing to automatically recover ${migrationName}: BarcodeScannerSession does not have the expected partially applied schema. Reconcile it manually before deploying.`,
      );
    }

    const backendDir = resolve(dirname(fileURLToPath(import.meta.url)), '..');
    const prismaCli = resolve(backendDir, 'node_modules/prisma/build/index.js');

    await prisma.$executeRaw`ALTER TABLE "BarcodeScannerSession" SET (schema_locked = false)`;
    try {
      await prisma.$executeRaw`CREATE INDEX IF NOT EXISTS "BarcodeScannerSession_expiresAt_idx" ON "BarcodeScannerSession"("expiresAt")`;
      await prisma.$executeRaw`CREATE INDEX IF NOT EXISTS "BarcodeScannerSession_ownerId_expiresAt_idx" ON "BarcodeScannerSession"("ownerId", "expiresAt")`;
    } finally {
      await prisma.$executeRaw`ALTER TABLE "BarcodeScannerSession" SET (schema_locked = true)`;
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
