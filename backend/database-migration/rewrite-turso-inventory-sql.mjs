import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

for (const source of ['../src/services/inventory.ts', '../src/services/room-inventory.ts']) {
  const path = fileURLToPath(new URL(source, import.meta.url));
  const current = await readFile(path, 'utf8');
  const next = current
    // Turso has a single writer. The surrounding Prisma transaction provides
    // the write boundary; SQLite/libSQL does not implement SELECT FOR UPDATE.
    .replace(/\s+FOR UPDATE/g, '')
    // Portable SQLite/libSQL equivalents for the Cockroach functions used by
    // inventory mutations.
    .replaceAll('NOW()', 'CURRENT_TIMESTAMP')
    .replaceAll('GREATEST(', 'MAX(');
  await writeFile(path, next, 'utf8');
}
console.log(JSON.stringify({ inventorySql: 'rewritten-for-turso' }));
