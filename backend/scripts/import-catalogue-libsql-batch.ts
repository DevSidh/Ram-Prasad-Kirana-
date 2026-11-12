import 'dotenv/config';
import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { createClient, type InStatement } from '@libsql/client';

type Preview = {
  report: Array<{ action: string; kind: string; matchId?: string; source: { row: number; name: string; brand: string; category: string; price: number | null; stock: number | null; unlimited: boolean; location: string; packaging: string; unit: string }; newPrice?: number | null; newStock?: number | null; setUnlimited?: boolean; setStock?: boolean }>;
};

const previewPath = '../tmp/final-inventory-upsert/preview.json';
const preview = JSON.parse(readFileSync(previewPath, 'utf8')) as Preview;
const db = createClient({ url: process.env.TURSO_DATABASE_URL!, authToken: process.env.TURSO_AUTH_TOKEN! });
const now = new Date().toISOString();
const validRooms = new Set(['1', '2', '5', '6', '7']);
const slugify = (value: string) => value.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 90);
const id = () => `cl${randomUUID().replaceAll('-', '').slice(0, 24)}`;

async function main() {
  const categories = new Map<string, string>();
  for (const row of preview.report.filter((item) => item.action === 'insert' || item.action === 'update')) {
    const category = row.source.category || 'Other General';
    if (categories.has(category)) continue;
    const found = await db.execute({ sql: 'SELECT "id" FROM "Category" WHERE "name" = ? LIMIT 1', args: [category] });
    const categoryId = found.rows[0]?.id?.toString() ?? id();
    categories.set(category, categoryId);
    if (!found.rows.length) await db.execute({ sql: 'INSERT INTO "Category" ("id","name","slug","isActive","sortOrder","createdAt","updatedAt") VALUES (?,?,?,?,?,?,?)', args: [categoryId, category, `${slugify(category)}-${categoryId.slice(-6)}`, 1, 0, now, now] });
  }
  let applied = 0;
  const rows = preview.report.filter((item) => item.action === 'insert' || item.action === 'update');
  for (let offset = 0; offset < rows.length; offset += 10) {
    const statements: InStatement[] = [];
    for (const row of rows.slice(offset, offset + 10)) {
      const source = row.source;
      const categoryId = categories.get(source.category || 'Other General')!;
      const price = row.newPrice ?? source.price ?? 100;
      const stock = row.newStock ?? source.stock ?? 0;
      const unlimited = Boolean(row.setUnlimited || source.unlimited);
      const unit = `1 ${source.unit || source.packaging || 'piece'}`;
      if (row.action === 'insert') {
        const productId = id();
        const sku = `FINAL-INV-${preview.report.indexOf(row) + 1}`;
        statements.push({ sql: 'INSERT OR IGNORE INTO "Product" ("id","sku","name","slug","categoryId","brand","price","unitLabel","isVendingDrink","isActive","description","createdAt","updatedAt") VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)', args: [productId, sku, `${source.name} - ${source.packaging}`.trim(), `${slugify(source.name)}-${productId.slice(-6)}`, categoryId, source.brand || null, price, unit, row.kind === 'drinks' ? 1 : 0, 1, 'Imported from product catalogue workbook.', now, now] });
        statements.push({ sql: 'INSERT OR IGNORE INTO "Inventory" ("id","productId","totalStock","reservedStock","isUnlimited","version","createdAt","updatedAt") VALUES (?,?,?,?,?,?,?,?)', args: [id(), productId, unlimited ? 0 : stock, 0, unlimited ? 1 : 0, 0, now, now] });
        if (!unlimited && stock > 0 && validRooms.has(source.location)) statements.push({ sql: 'INSERT OR REPLACE INTO "InventoryRoomStock" ("roomId","productId","quantity") SELECT "id",?,?,? FROM "InventoryRoom" WHERE "number"=?', args: [source.location, productId, stock, source.location] });
      } else if (row.matchId) {
        statements.push({ sql: 'UPDATE "Product" SET "name"=?,"brand"=COALESCE(?,"brand"),"categoryId"=?,"price"=?,"unitLabel"=?,"updatedAt"=? WHERE "id"=?', args: [`${source.name} - ${source.packaging}`.trim(), source.brand || null, categoryId, price, unit, now, row.matchId] });
        if (row.setStock) statements.push({ sql: 'UPDATE "Inventory" SET "totalStock"=?,"isUnlimited"=?,"updatedAt"=? WHERE "productId"=?', args: [unlimited ? 0 : stock, unlimited ? 1 : 0, now, row.matchId] });
      }
    }
    await db.batch(statements, 'write');
    applied += rows.slice(offset, offset + 10).length;
    console.log(JSON.stringify({ applied, total: rows.length }));
  }
  const counts = await db.batch([
    { sql: 'SELECT COUNT(*) AS count FROM "Product"', args: [] },
    { sql: 'SELECT COUNT(*) AS count FROM "WholesaleItem"', args: [] },
  ], 'read');
  console.log(JSON.stringify({ applied, products: counts[0].rows[0]?.count, wholesale: counts[1].rows[0]?.count }));
  db.close();
}
void main().catch((error) => { console.error(error); process.exitCode = 1; });
