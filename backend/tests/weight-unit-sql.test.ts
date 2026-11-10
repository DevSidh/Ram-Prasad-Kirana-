import assert from 'node:assert/strict';
import { createClient } from '@libsql/client';
import { Prisma } from '@prisma/client';
import { weightUnitSql } from '../src/services/weight-unit-sql.js';
import { isWeightUnitLabel } from '../src/services/product-validation.js';

async function main(): Promise<void> {
const db = createClient({ url: 'file::memory:' });
try {
  await db.execute('CREATE TABLE Product (unitLabel TEXT NOT NULL)');
  for (const label of ['1 kg', '500 g', '0.5KG', '  1\tkg\n', 'pcs', 'pack', 'kg', '1..2kg', '1.kg', '.5kg', '1 2 kg', '2 k g', '-1kg', '0g']) {
    await db.execute('DELETE FROM Product');
    await db.execute({ sql: 'INSERT INTO Product VALUES (?)', args: [label] });
    const query = Prisma.sql`SELECT CASE WHEN ${weightUnitSql()} THEN 1 ELSE 0 END AS matches FROM Product p`;
    const result = await db.execute({ sql: query.sql, args: query.values as string[] });
    assert.equal(Number(result.rows[0].matches), isWeightUnitLabel(label) ? 1 : 0, label);
  }
  const search = await db.execute({
    sql: "SELECT INSTR(LOWER(COALESCE(?, '') || ' ' || COALESCE(?, '')), ?) AS position",
    args: [null, 'LOT-1', 'lot-1'],
  });
  assert(Number(search.rows[0].position) > 0);
  console.log('Actual libSQL engine: weight units match application rules; nullable expiry search works.');
} finally {
  db.close();
}
}
void main().catch((error) => { console.error(error); process.exitCode = 1; });
