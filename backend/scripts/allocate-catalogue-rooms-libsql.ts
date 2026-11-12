import fs from 'node:fs';
import path from 'node:path';
import { createClient } from '@libsql/client';
import 'dotenv/config';

type ReportRow = {
  action: string;
  kind: 'retail' | 'wholesale';
  matchId?: string;
  source: {
    row: number;
    name: string;
    packaging?: string;
    stock: number | null;
    unlimited?: boolean;
    location?: string | null;
  };
};

const root = path.resolve(process.cwd(), '..');
const previewPath = path.join(root, 'tmp', 'final-inventory-upsert', 'preview.json');
const reportPath = path.join(root, 'Faststore-Room-Allocation-Report.csv');
const missingPath = path.join(root, 'Faststore-Missing-Room-Locations.csv');

const url = process.env.TURSO_DATABASE_URL;
const authToken = process.env.TURSO_AUTH_TOKEN;
if (!url || !authToken) throw new Error('TURSO_DATABASE_URL and TURSO_AUTH_TOKEN are required');

const db = createClient({ url: url.startsWith('libsql://') ? url : `libsql://${url}`, authToken });
const preview = JSON.parse(fs.readFileSync(previewPath, 'utf8')) as { report: ReportRow[] };

const csv = (value: unknown) => {
  const text = String(value ?? '');
  return /[",\n]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
};
const normalize = (value: string) => value.toLowerCase().replace(/[^a-z0-9]+/g, '');

async function main() {

const roomsResult = await db.execute('SELECT "id", "number" FROM "InventoryRoom" WHERE "active" = 1');
const roomByNumber = new Map<string, string>();
for (const row of roomsResult.rows) roomByNumber.set(String(row.number), String(row.id));

const productsResult = await db.execute('SELECT "id", "sku", "name" FROM "Product"');
const productsBySku = new Map<string, string>();
const productsByName = new Map<string, string[]>();
for (const row of productsResult.rows) {
  const id = String(row.id);
  if (row.sku) productsBySku.set(String(row.sku), id);
  const key = normalize(String(row.name));
  const ids = productsByName.get(key) ?? [];
  ids.push(id);
  productsByName.set(key, ids);
}

const wholesaleResult = await db.execute('SELECT "id", "sku", "name" FROM "WholesaleItem"');
const wholesaleBySku = new Map<string, string>();
const wholesaleByName = new Map<string, string[]>();
for (const row of wholesaleResult.rows) {
  const id = String(row.id);
  if (row.sku) wholesaleBySku.set(String(row.sku), id);
  const key = normalize(String(row.name));
  const ids = wholesaleByName.get(key) ?? [];
  ids.push(id);
  wholesaleByName.set(key, ids);
}

const allocationStatements: Array<{ sql: string; args: (string | number)[] }> = [];
const allocationRows: string[] = [['Excel row', 'Product', 'Product ID', 'Room', 'Quantity assigned', 'Stock mode', 'Status'].map(csv).join(',')];
const missingRows: string[] = [['Excel row', 'Product', 'Location from Excel', 'Reason'].map(csv).join(',')];
let mapped = 0;
let missing = 0;
let unresolved = 0;

for (let index = 0; index < preview.report.length; index += 1) {
  const row = preview.report[index];
  const source = row.source;
  const location = String(source.location ?? '').trim();
  const roomId = roomByNumber.get(location);
  const stock = source.unlimited || source.stock == null ? 333 : Math.max(0, Math.trunc(Number(source.stock)));
  const deterministicSku = `FINAL-INV-${index + 1}`;
  const displayName = `${source.name}${source.packaging ? ` - ${source.packaging}` : ''}`;
  const nameKey = normalize(displayName);
  const byKey = row.kind === 'wholesale' ? wholesaleBySku : productsBySku;
  const byName = row.kind === 'wholesale' ? wholesaleByName : productsByName;
  const id = row.matchId ?? byKey.get(deterministicSku) ?? (byName.get(nameKey)?.length === 1 ? byName.get(nameKey)![0] : undefined);

  if (!id) {
    unresolved += 1;
    missing += 1;
    missingRows.push([source.row, displayName, location, 'Product could not be matched safely'].map(csv).join(','));
    continue;
  }
  if (!roomId) {
    missing += 1;
    missingRows.push([source.row, displayName, location, location ? 'Room is not present or inactive' : 'Location is blank'].map(csv).join(','));
    allocationRows.push([source.row, displayName, id, '', '', source.unlimited ? 'manual 333 (unlimited source)' : 'source stock', 'Missing room - unchanged'].map(csv).join(','));
    continue;
  }

  const productKey = row.kind === 'wholesale' ? `wholesale-${id}` : id;
  allocationStatements.push({ sql: 'DELETE FROM "InventoryRoomStock" WHERE "productId" = ?', args: [productKey] });
  allocationStatements.push({ sql: 'INSERT OR REPLACE INTO "InventoryRoomStock" ("roomId", "productId", "quantity") VALUES (?, ?, ?)', args: [roomId, productKey, stock] });
  allocationRows.push([source.row, displayName, id, location, stock, source.unlimited ? 'manual 333 (unlimited source)' : 'source stock', 'Allocated'].map(csv).join(','));
  mapped += 1;
}

for (let start = 0; start < allocationStatements.length; start += 40) {
  await db.batch(allocationStatements.slice(start, start + 40), 'write');
}

fs.writeFileSync(reportPath, `${allocationRows.join('\n')}\n`, 'utf8');
const missingOutput = missingRows.length === 1
  ? [...missingRows, ['-', '-', '-', 'No missing or unmatched locations'].map(csv).join(',')]
  : missingRows;
fs.writeFileSync(missingPath, `${missingOutput.join('\n')}\n`, 'utf8');

const verify = await db.execute('SELECT "roomId", COUNT(*) AS "items", SUM("quantity") AS "quantity" FROM "InventoryRoomStock" GROUP BY "roomId" ORDER BY "roomId"');
console.log(JSON.stringify({ rows: preview.report.length, mapped, missing, unresolved, rooms: Object.fromEntries(verify.rows.map((r) => [String(r.roomId), { items: Number(r.items), quantity: Number(r.quantity) }])) }, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
