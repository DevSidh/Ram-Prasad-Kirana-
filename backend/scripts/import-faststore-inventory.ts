/**
 * Safe Faststore inventory importer.
 *
 * Default behaviour is read-only: it reads the Excel workbooks, compares them
 * with Turso, and writes a preview report. `--apply` is deliberately required
 * for database writes and only creates the exact preview entries. Existing
 * products, prices, stock and images are never overwritten by this script.
 */
import 'dotenv/config';
import { createHash, randomUUID } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { resolve, basename, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Prisma } from '@prisma/client';
import { createTursoPrismaClient } from '../src/turso-prisma.js';
import { InventoryService } from '../src/services/inventory.js';
import { allocateOpeningRoomStock } from '../src/services/room-inventory.js';

type Row = { row: number; cells: Record<string, string> };
type Sheet = { file: string; rows: Row[] };
type Workbook = Sheet[];
type Action = 'create-retail' | 'create-drink' | 'review' | 'existing';
type PreviewRow = {
  sheet: number; row: number; sourceNumber: string; name: string; category: string;
  packaging: string; price: number | null; quantity: number | null; isUnlimited: boolean; place: string;
  action: Action; reason: string; existingId?: string; sku: string;
};

const scriptDir = dirname(fileURLToPath(import.meta.url));
const projectDir = resolve(scriptDir, '..', '..');
const reportsDir = resolve(projectDir, 'tmp', 'inventory-import');
const reader = resolve(projectDir, 'tmp', 'inventory-import', 'read-source.ps1');
const previewPath = resolve(reportsDir, 'faststore-inventory-dry-run.json');
const reportPath = resolve(projectDir, 'FASTSTORE_INVENTORY_DRY_RUN.md');

function arg(name: string): string | undefined {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : undefined;
}
const apply = process.argv.includes('--apply');
const workbookPath = arg('--workbook') ?? 'D:/Downloads/faststore_inventory_names_categories_updated.xlsx';
const rulesPath = arg('--rules') ?? 'D:/Downloads/faststore_confirmed_rules.xlsx';
const normalized = (value: string) => value.toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
const slug = (value: string) => normalized(value).replace(/\s+/g, '-');
const canonicalName = (value: string) => normalized(value)
  .replace(/\b(?:box|packet|pack|bundle|carton|dozen|pieces?|pcs?)$/i, '').trim();
const packKind = (value: string) => {
  const item = value.toLowerCase();
  if (/carton/.test(item)) return 'carton';
  if (/bundle/.test(item)) return 'bundle';
  if (/dozen/.test(item)) return 'dozen';
  if (/box/.test(item)) return 'box';
  if (/packet|pack/.test(item)) return 'packet';
  return 'piece';
};
const sourceHash = (...files: string[]) => createHash('sha256').update(files.map(file => readFileSync(file)).join('')).digest('hex');
const number = (value: string): number | null => /^\d+(?:\.\d+)?$/.test(value.trim()) ? Number(value) : null;
const quantity = (value: string): number | null => /^\d+$/.test(value.trim()) ? Number(value) : null;
const unit = (packaging: string) => {
  const item = packaging.toLowerCase();
  if (item.includes('bag')) return '1 bag';
  if (item.includes('kg')) return '1 kg';
  if (/\b\d+\s*g\b/.test(item)) return '1 g';
  if (item.includes('l')) return '1 L';
  if (item.includes('ml')) return '1 ml';
  if (item.includes('carton')) return '1 carton';
  if (item.includes('bundle')) return '1 bundle';
  if (item.includes('dozen')) return '1 dozen';
  if (item.includes('box')) return '1 box';
  if (item.includes('packet') || item.includes('pack')) return '1 packet';
  return '1 pc';
};
const drink = (name: string, category: string) => /\b(?:beverage|beverages|drink|drinks|juice|cola|soda|water)\b/i.test(`${name} ${category}`);
const restricted = (name: string, category: string) => /\brice\b|patanjali oil|\bamul\b|\bmdh\b|momo masala/i.test(`${name} ${category}`);
const defaultPrice = 100;

/** A note such as "13 bundles" is a usable opening count.  Conversion
 * notes ("100x12", "9 per bundle") describe a package, so its stock is
 * deliberately marked unlimited instead of inventing a count. */
function quantityFromNote(note: string, packaging: string): number | null {
  const match = note.trim().match(/^(\d+)\s+(?:cartons?|bundles?|dozens?|boxes?|bags?|packets?|packs?|pieces?|pcs?)\b/i);
  if (!match) return null;
  const expected = packKind(packaging);
  const stated = match[0].toLowerCase();
  if (expected === 'piece' || stated.includes(expected)) return Number(match[1]);
  return null;
}

function readWorkbook(file: string, label: string): Workbook {
  if (!existsSync(file)) throw new Error(`${label} workbook not found: ${file}`);
  if (!existsSync(reader)) throw new Error(`Excel reader is missing: ${reader}`);
  const output = `faststore-${label}-${Date.now()}.json`;
  execFileSync('powershell.exe', ['-NoProfile', '-File', reader, '-Source', file, '-OutputName', output], {
    cwd: projectDir, stdio: 'ignore', timeout: 60000,
  });
  return JSON.parse(readFileSync(resolve(reportsDir, output), 'utf8').replace(/^\uFEFF/, ''));
}

function values(row: Row) {
  const c = row.cells;
  return { sourceNumber: c[`A${row.row}`] ?? '', name: c[`B${row.row}`]?.trim() ?? '', category: c[`C${row.row}`]?.trim() ?? '',
    packaging: c[`D${row.row}`]?.trim() ?? '', price: number(c[`E${row.row}`] ?? ''), quantity: quantity(c[`F${row.row}`] ?? ''),
    quantityNote: c[`F${row.row}`]?.trim() ?? '', place: c[`G${row.row}`]?.trim() ?? '', notes: c[`J${row.row}`]?.trim() ?? '' };
}

async function retryTurso<T>(operation: () => Promise<T>, attempts = 8): Promise<T> {
  let lastError: unknown;
  for (let attempt = 1; attempt <= attempts; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error;
      const message = error instanceof Error ? error.message : String(error);
      if (attempt === attempts || !/fetch failed|timeout|connection|network|database is locked|sqlite_busy/i.test(message)) throw error;
      await new Promise<void>((resolve) => setTimeout(resolve, Math.min(5000, attempt * 1000)));
    }
  }
  throw lastError;
}

async function main() {
  if (apply && !process.argv.includes('--approved')) {
    throw new Error('Refusing database writes. Review the dry-run report, then use --apply --approved with the same workbooks.');
  }
  // The rules workbook is intentionally read: its restrictions are encoded in
  // the checks below, and its hash binds the preview to the apply action.
  const workbook = readWorkbook(workbookPath, 'inventory');
  const rules = readWorkbook(rulesPath, 'rules');
  if (rules.length < 2) throw new Error('The confirmed-rules workbook is incomplete.');
  const hash = sourceHash(workbookPath, rulesPath);
  const db = createTursoPrismaClient();
  try {
    const [products, wholesale, rooms] = await retryTurso(() => Promise.all([
      db.product.findMany({ select: { id: true, name: true, sku: true, barcode: true, slug: true, unitLabel: true, price: true, isVendingDrink: true } }),
      db.wholesaleItem.findMany({ select: { id: true, name: true, sku: true, slug: true, unitLabel: true, price: true } }),
      db.inventoryRoom.findMany({ where: { active: true }, select: { id: true, number: true } }),
    ]));
    const all = [...products.map(p => ({ ...p, type: 'retail' as const })), ...wholesale.map(p => ({ ...p, type: 'wholesale' as const }))];
    const preview: PreviewRow[] = [];
    for (const [sheetIndex, sheet] of workbook.entries()) {
      for (const source of sheet.rows.slice(1)) {
        const v = values(source);
        const sku = `FASTSTORE-XLSX-S${sheetIndex + 1}-R${source.row}`;
        const base = canonicalName(v.name);
        const sourcePack = packKind(v.packaging);
        const exact = all.find(item => item.sku === sku ||
          (canonicalName(item.name) === base &&
            packKind(`${item.name} ${item.unitLabel}`) === sourcePack &&
            (v.price == null || Number(item.price) === v.price)));
        let action: Action = 'review';
        let reason = '';
        if (!v.name || !v.category || !v.packaging) reason = 'Missing product name, category or packaging.';
        else if (restricted(v.name, v.category)) reason = 'Excluded by confirmed rules.';
        else if (exact) { action = 'existing'; reason = `Exact existing ${exact.type} item; no stock, price or image will be overwritten.`; }
        else if (!rooms.some(room => room.number === v.place)) reason = `Active inventory room ${v.place || '(blank)'} does not exist.`;
        else { action = drink(v.name, v.category) ? 'create-drink' : 'create-retail'; reason = v.price == null
          ? `New item using the approved default price of Rs. ${defaultPrice}.`
          : 'New item using its workbook price.'; }
        const resolvedQuantity = v.quantity ?? quantityFromNote(v.quantityNote, v.packaging);
        preview.push({ sheet: sheetIndex + 1, row: source.row, ...v,
          price: v.price ?? (action === 'existing' ? null : defaultPrice),
          quantity: resolvedQuantity,
          isUnlimited: action !== 'existing' && resolvedQuantity == null,
          action, reason, existingId: exact?.id, sku });
      }
    }
    const summary = {
      generatedAt: new Date().toISOString(), source: basename(workbookPath), rules: basename(rulesPath), sourceHash: hash,
      totalRows: preview.length, createRetail: preview.filter(row => row.action === 'create-retail').length,
      createDrinks: preview.filter(row => row.action === 'create-drink').length,
      existing: preview.filter(row => row.action === 'existing').length,
      manualReview: preview.filter(row => row.action === 'review').length,
      wholesale: 0, missingPrices: preview.filter(row => row.price == null).length,
      preview,
    };
    if (apply) {
      const old = JSON.parse(readFileSync(previewPath, 'utf8'));
      if (old.sourceHash !== hash) throw new Error('The Excel files changed after preview. Run dry-run again before applying.');
      const inventory = new InventoryService(db);
      for (const row of preview.filter(row => row.action === 'create-retail' || row.action === 'create-drink')) {
        const room = rooms.find(candidate => candidate.number === row.place)!;
        try {
          await retryTurso(() => db.$transaction(async tx => {
          const category = await tx.category.upsert({ where: { slug: slug(row.category) }, update: {}, create: { name: row.category, slug: slug(row.category) } });
          const created = await tx.product.create({ data: { sku: row.sku, slug: slug(`${row.name}-${row.packaging}-${row.sku}`), name: `${row.name} — ${row.packaging}`, categoryId: category.id,
            price: new Prisma.Decimal(row.price!), unitLabel: unit(row.packaging), isVendingDrink: row.action === 'create-drink',
            description: `Imported from ${basename(workbookPath)}, sheet ${row.sheet}, row ${row.row}. Packaging: ${row.packaging}.${row.quantityNote ? ` Source note: ${row.quantityNote}.` : ''}` } });
          if (row.isUnlimited) {
            const inventoryRow = await tx.inventory.create({ data: { productId: created.id, totalStock: 0, isUnlimited: true } });
            await tx.inventoryTransaction.create({ data: {
              inventoryId: inventoryRow.id, type: 'ADJUSTED', quantity: 0, balanceAfter: 0,
              referenceId: row.sku, notes: `Unlimited stock imported from ${basename(workbookPath)} sheet ${row.sheet} row ${row.row}`,
            } });
          } else {
            await inventory.setStock(tx, created.id, row.quantity!, row.sku, `Excel opening stock: ${basename(workbookPath)} sheet ${row.sheet} row ${row.row}`);
            await allocateOpeningRoomStock(tx, created.id, row.quantity!, [{ roomId: room.id, quantity: row.quantity! }], undefined, created.unitLabel);
          }
          }, { timeout: 30000 }));
        } catch (error) {
          const message = error instanceof Error ? error.message : String(error);
          throw new Error(`Import stopped at sheet ${row.sheet}, row ${row.row} (${row.name}, ${row.packaging}): ${message}`);
        }
      }
    }
    writeFileSync(previewPath, JSON.stringify(summary, null, 2));
    const lines = [
      '# Faststore inventory import dry run', '',
      `Source: ${basename(workbookPath)}`, `Rules: ${basename(rulesPath)}`, `Source hash: ${hash}`, '',
      `- Total rows processed: ${summary.totalRows}`,
      `- New retail products to insert: ${summary.createRetail}`,
      `- New drinks to insert: ${summary.createDrinks}`,
      `- Wholesale items to insert: ${summary.wholesale}`,
      `- Existing exact products: ${summary.existing}`,
      `- Rows requiring manual review: ${summary.manualReview}`,
      `- Rows with missing prices: ${summary.missingPrices}`,
      '', 'Blank or conversion-only stock is imported as Unlimited. Missing prices use the approved default of Rs. 100. Existing items are never overwritten.', '',
      '| Sheet | Row | Product | Packaging | Price | Stock | Room | Action | Reason |', '|---|---:|---|---|---:|---:|---|---|---|',
      ...preview.map(row => `| ${row.sheet} | ${row.row} | ${row.name} | ${row.packaging} | ${row.price ?? ''} | ${row.isUnlimited ? 'Unlimited' : row.quantity ?? row.quantityNote} | ${row.place} | ${row.action} | ${row.reason} |`),
    ];
    writeFileSync(reportPath, `${lines.join('\n')}\n`);
    console.log(JSON.stringify({ ...summary, preview: undefined }));
  } finally { await db.$disconnect(); }
}
void main().catch(error => { console.error(error.message); process.exitCode = 1; });
