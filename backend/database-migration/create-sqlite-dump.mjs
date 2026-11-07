import { createWriteStream } from 'node:fs';
import { once } from 'node:events';
import dotenv from 'dotenv';
import { connectTurso } from './connection.mjs';

dotenv.config({ path: new URL('../.env', import.meta.url) });

const source = process.argv.find((argument) => argument.startsWith('--source='))?.slice(9);
const output = process.argv.find((argument) => argument.startsWith('--output='))?.slice(9);
if (!source || !output) {
  throw new Error('Usage: node create-sqlite-dump.mjs --source=file:<staging.db> --output=<private dump.sql>');
}
if (!source.startsWith('file:')) {
  throw new Error('Only a verified local staging database may be dumped.');
}

function quoteIdentifier(identifier) {
  return `"${String(identifier).replaceAll('"', '""')}"`;
}

function sqlValue(value) {
  if (value === null) return 'NULL';
  if (typeof value === 'bigint') return value.toString();
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) throw new Error('A non-finite numeric value cannot be dumped.');
    return String(value);
  }
  if (value instanceof Uint8Array || value instanceof ArrayBuffer) {
    return `X'${Buffer.from(value).toString('hex')}'`;
  }
  return `'${String(value).replaceAll("'", "''")}'`;
}

const client = connectTurso({ TURSO_DATABASE_URL: source }, { local: true });
const writer = createWriteStream(output, { encoding: 'utf8', flags: 'wx' });
let tableCount = 0;
let rowCount = 0;

async function write(text) {
  if (!writer.write(text)) await once(writer, 'drain');
}

try {
  const objects = await client.execute(`
    SELECT type, name, tbl_name, sql
    FROM sqlite_master
    WHERE name NOT LIKE 'sqlite_%' AND sql IS NOT NULL
    ORDER BY CASE type WHEN 'table' THEN 0 WHEN 'view' THEN 1 WHEN 'index' THEN 2 WHEN 'trigger' THEN 3 ELSE 4 END, name
  `);
  const tables = objects.rows.filter((object) => object.type === 'table');

  await write('PRAGMA foreign_keys=OFF;\nBEGIN TRANSACTION;\n');
  for (const object of tables) await write(`${object.sql};\n`);

  for (const table of tables) {
    const rows = await client.execute(`SELECT * FROM ${quoteIdentifier(table.name)}`);
    tableCount += 1;
    for (const row of rows.rows) {
      const values = Object.values(row).map(sqlValue).join(',');
      await write(`INSERT INTO ${quoteIdentifier(table.name)} VALUES(${values});\n`);
      rowCount += 1;
    }
  }

  for (const object of objects.rows.filter((object) => object.type !== 'table')) {
    await write(`${object.sql};\n`);
  }
  await write('COMMIT;\nPRAGMA foreign_keys=ON;\n');
  writer.end();
  await once(writer, 'finish');
  console.log(JSON.stringify({ dump: 'created', tables: tableCount, rows: rowCount, targetChanged: false }));
} catch (error) {
  writer.destroy();
  throw error;
} finally {
  client.close();
}
