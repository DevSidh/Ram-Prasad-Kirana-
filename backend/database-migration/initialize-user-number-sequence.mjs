import dotenv from 'dotenv';
import { PrismaLibSQL } from '@prisma/adapter-libsql';
import { PrismaClient } from '@prisma/client';
dotenv.config({ path: new URL('../.env', import.meta.url) });
const prisma = new PrismaClient({ adapter: new PrismaLibSQL({ url: process.env.TURSO_DATABASE_URL, authToken: process.env.TURSO_AUTH_TOKEN }) });
try {
  await prisma.$executeRawUnsafe('CREATE TABLE IF NOT EXISTS "UserNumberSequence" ("singleton" INTEGER PRIMARY KEY CHECK ("singleton" = 1), "nextValue" INTEGER NOT NULL CHECK ("nextValue" > 0))');
  await prisma.$executeRawUnsafe('INSERT OR IGNORE INTO "UserNumberSequence" ("singleton", "nextValue") SELECT 1, COALESCE(MAX("userNumber"), 0) + 1 FROM "User"');
  const rows = await prisma.$queryRawUnsafe('SELECT "nextValue" FROM "UserNumberSequence" WHERE "singleton" = 1');
  console.log(JSON.stringify({ userNumberSequence: 'initialized', rows: rows.length }));
} finally { await prisma.$disconnect(); }
