import { PrismaClient } from '@prisma/client';
import { spawnSync } from 'node:child_process';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const migrationName = '20261027000000_pos_sale_vat';
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
    const vatColumns = await prisma.$queryRaw`
      SELECT column_name
      FROM information_schema.columns
      WHERE table_schema = current_schema()
        AND table_name = 'PosSale'
        AND column_name IN ('vatRate', 'vatAmount')
    `;

    if (vatColumns.length > 0) {
      throw new Error(
        `Refusing to automatically resolve ${migrationName}: PosSale has partial VAT columns (${vatColumns.map((column) => column.column_name).join(', ')}). Reconcile the schema manually before deploying.`,
      );
    }

    const backendDir = resolve(dirname(fileURLToPath(import.meta.url)), '..');
    const prismaCli = resolve(backendDir, 'node_modules/prisma/build/index.js');
    const result = spawnSync(
      process.execPath,
      [prismaCli, 'migrate', 'resolve', '--rolled-back', migrationName],
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
