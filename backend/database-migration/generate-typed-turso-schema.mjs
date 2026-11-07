import { readFile, writeFile } from 'node:fs/promises';

const source = new URL('../prisma/schema.prisma', import.meta.url);
const target = new URL('../prisma/schema.turso-typed.prisma', import.meta.url);
let schema = await readFile(source, 'utf8');

schema = schema.replace('provider = "cockroachdb"', 'provider = "sqlite"');
schema = schema.replace('url      = env("DATABASE_URL")', 'url      = env("TURSO_SCHEMA_URL")');
// SQLite/libSQL has no Cockroach native type namespace. Prisma's portable
// scalar types preserve the application contract while the staging importer
// retains the original values as canonical text/integers.
schema = schema.replace(/\s+@db\.(?:Timestamptz\(\d+\)|Decimal(?:\(\d+,\s*\d+\))?)/g, '');
// SQLite has no database sequence. Runtime allocation is handled explicitly
// during the Turso write-path conversion.
schema = schema.replace(/\s+@default\(sequence\(\)\)/g, '');

await writeFile(target, schema, 'utf8');
console.log(JSON.stringify({ generated: 'schema.turso-typed.prisma', sourceChanged: false }));
