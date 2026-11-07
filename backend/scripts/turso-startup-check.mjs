import 'dotenv/config';
import { PrismaLibSQL } from '@prisma/adapter-libsql';
import { PrismaClient } from '@prisma/client';

const url = process.env.TURSO_DATABASE_URL?.trim();
const authToken = process.env.TURSO_AUTH_TOKEN?.trim();
if (!url?.startsWith('libsql://') || !authToken) {
  throw new Error('Turso is not configured. Set TURSO_DATABASE_URL and TURSO_AUTH_TOKEN in the deployment environment.');
}

const prisma = new PrismaClient({ adapter: new PrismaLibSQL({ url, authToken }) });
try {
  const tables = await prisma.$queryRawUnsafe("SELECT COUNT(*) AS count FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'");
  if (Number(tables[0]?.count ?? 0) < 55) throw new Error('The configured Turso database does not contain the FastStore application schema.');
  await prisma.$executeRawUnsafe('CREATE TABLE IF NOT EXISTS "UserNumberSequence" ("singleton" INTEGER PRIMARY KEY CHECK ("singleton" = 1), "nextValue" INTEGER NOT NULL CHECK ("nextValue" > 0))');
  await prisma.$executeRawUnsafe('INSERT OR IGNORE INTO "UserNumberSequence" ("singleton", "nextValue") SELECT 1, COALESCE(MAX("userNumber"), 0) + 1 FROM "User"');
  console.log(JSON.stringify({ database: 'turso-ready', applicationTables: Number(tables[0].count) }));
} finally {
  await prisma.$disconnect();
}
