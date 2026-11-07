import { Prisma } from '@prisma/client';

type SqlClient = {
  $executeRaw: (query: Prisma.Sql) => Promise<unknown>;
  $queryRaw: <T>(query: Prisma.Sql) => Promise<T>;
};

export async function initializeUserNumberSequence(client: SqlClient): Promise<void> {
  await client.$executeRaw(Prisma.sql`
    CREATE TABLE IF NOT EXISTS "UserNumberSequence" (
      "singleton" INTEGER PRIMARY KEY CHECK ("singleton" = 1),
      "nextValue" INTEGER NOT NULL CHECK ("nextValue" > 0)
    )
  `);
  await client.$executeRaw(Prisma.sql`
    INSERT OR IGNORE INTO "UserNumberSequence" ("singleton", "nextValue")
    SELECT 1, COALESCE(MAX("userNumber"), 0) + 1 FROM "User"
  `);
}

export async function allocateUserNumber(client: SqlClient): Promise<bigint> {
  const rows = await client.$queryRaw<Array<{ userNumber: bigint }>>(Prisma.sql`
    UPDATE "UserNumberSequence"
    SET "nextValue" = "nextValue" + 1
    WHERE "singleton" = 1
    RETURNING "nextValue" - 1 AS "userNumber"
  `);
  if (rows.length !== 1 || rows[0].userNumber < 1n) throw new Error('Unable to allocate a user number.');
  return rows[0].userNumber;
}
