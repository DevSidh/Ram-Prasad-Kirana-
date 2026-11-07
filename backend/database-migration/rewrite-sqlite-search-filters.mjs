import { readdir, readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../src/', import.meta.url));
let changed = 0;

async function visit(directory) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) await visit(path);
    else if (entry.isFile() && path.endsWith('.ts')) {
      const source = await readFile(path, 'utf8');
      // SQLite LIKE is case-insensitive for FastStore's ASCII identifiers.
      // Prisma's PostgreSQL-only `mode` property must not be sent to SQLite.
      const next = source
        .replace(/,\s*mode:\s*'insensitive'(?:\s+as\s+const)?/g, '')
        .replace(/,\s*mode:\s*"insensitive"(?:\s+as\s+const)?/g, '');
      if (next !== source) {
        await writeFile(path, next, 'utf8');
        changed += 1;
      }
    }
  }
}

await visit(root);
console.log(JSON.stringify({ sqliteSearchFilesUpdated: changed }));
