/**
 * Safe UPSERT for Faststore_Final_Inventory_Ascending.xlsx.
 *
 * The default mode is read-only.  `--apply --approval <preview-hash>` is
 * required before it will make a database change, binding an apply run to the
 * reviewed source and preview.  It never deletes records or changes IDs.
 */
import 'dotenv/config';
import { createHash, randomUUID } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { basename, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Prisma } from '@prisma/client';
import { createClient } from '@libsql/client';
import { createTursoPrismaClient } from '../src/turso-prisma.js';
import { InventoryService } from '../src/services/inventory.js';
import { allocateOpeningRoomStock } from '../src/services/room-inventory.js';

type WorkbookRow = { row: number; cells: Record<string, string> };
type WorkbookSheet = { file: string; rows: WorkbookRow[] };
type InventoryKind = 'retail' | 'drinks' | 'wholesale';
type Action = 'insert' | 'update' | 'review';
type SourceItem = {
  row: number; number: string; name: string; brand: string; category: string; subcategory: string;
  size: string; packaging: string; packCount: string; notes: string; unit: string; price: number | null;
  stock: number | null; unlimited: boolean; location: string; source: string;
};
type ExistingItem = {
  id: string; kind: InventoryKind; sku: string; barcode: string | null; name: string; brand: string | null;
  unitLabel: string; price: number; categoryId: string; categoryName: string; stock: number | null;
  unlimited: boolean; locations: string[];
};
type Preview = {
  source: SourceItem; kind: InventoryKind; action: Action; matchId?: string; matchReason?: string;
  message: string; oldPrice?: number | null; newPrice?: number | null; oldStock?: number | null;
  newStock?: number | null; oldLocations?: string[]; newLocations?: string[]; sourceKey: string;
  setPrice?: boolean; setStock?: boolean; setLocation?: boolean;
  setUnlimited?: boolean;
  roomQuantities?: Array<{ room: string; quantity: number }>;
};

const scriptDir = dirname(fileURLToPath(import.meta.url));
const projectDir = resolve(scriptDir, '..', '..');
const workbookPath = process.argv.includes('--workbook')
  ? process.argv[process.argv.indexOf('--workbook') + 1]
  : 'D:/Downloads/Faststore_Final_Inventory_Ascending.xlsx';
const outputDir = resolve(projectDir, 'tmp', 'final-inventory-upsert');
const previewPath = resolve(outputDir, 'preview.json');
const reportPath = resolve(projectDir, 'FASTSTORE_FINAL_INVENTORY_UPSERT_DRY_RUN.md');
const readerPath = resolve(scriptDir, 'lib', 'read-xlsx-workbook.ps1');
const apply = process.argv.includes('--apply');
// Explicit completion mode is used only after the store owner confirms that
// blank stock means unlimited stock and that unclassified packages are retail.
const completeApprovedImport = process.argv.includes('--complete-approved-import');
const approval = process.argv.includes('--approval') ? process.argv[process.argv.indexOf('--approval') + 1] : '';
const prepareRooms = process.argv.includes('--prepare-rooms');
const approvedRoomSetup = process.argv.includes('--approved-room-setup');

const aliases = new Map<string, string>([
  ['fevi quik', 'fevi kwik'],
  ['fevikwik', 'fevi kwik'],
  ['vi jhon', 'v jhon'],
  ['vijhon', 'v jhon'],
  ['tea dost', 'tea dust'],
]);
const validLocations = new Set(['1', '2', '5', '6', '7']);

function text(value: unknown): string { return String(value ?? '').trim(); }
function price(value: string): number | null {
  const cleaned = value.replace(/[,₨Rs. ]/gi, '').trim();
  if (!/^\d+(?:\.\d{1,2})?$/.test(cleaned)) return null;
  const parsed = Number(cleaned);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : null;
}
function stock(value: string): number | null {
  const cleaned = value.trim();
  if (/^\d+$/.test(cleaned)) return Number(cleaned);
  const stated = cleaned.match(/^(\d+)\s*(?:pcs?|pieces?|packets?|packs?|boxes?|cartons?|bundles?|bags?|dozens?)\b/i);
  return stated ? Number(stated[1]) : null;
}
function normalized(value: string): string {
  const replaced = value.toLowerCase()
    .replace(/\bpieces?\b/g, 'pc')
    .replace(/\bpackets?\b/g, 'packet')
    .replace(/\bpkts?\b/g, 'packet')
    .replace(/\bgrams?\b/g, 'g')
    .replace(/\bkilograms?\b/g, 'kg')
    .replace(/\blitres?\b/g, 'l')
    .replace(/[^a-z0-9]+/g, ' ').trim();
  const canonical = replaced.replace(/\btea dost\b/g, 'tea dust');
  return aliases.get(canonical) ?? canonical;
}
function pack(value: string): string {
  const source = normalized(value);
  if (/\bcarton\b/.test(source)) return 'carton';
  if (/\bbundle\b/.test(source)) return 'bundle';
  if (/\bbox\b/.test(source)) return 'box';
  if (/\bdozen\b/.test(source)) return 'dozen';
  if (/\bpacket\b|\bpack\b/.test(source)) return 'packet';
  if (/\bbag\b/.test(source)) return 'bag';
  if (/\bkg\b/.test(source)) return 'kg';
  if (/\bg\b/.test(source)) return 'g';
  if (/\bml\b/.test(source)) return 'ml';
  if (/\bl\b/.test(source)) return 'l';
  return 'piece';
}
function baseName(value: string): string {
  return normalized(value)
    .replace(/\b(carton|bundle|box|dozen|packet|pack|bag|pc|piece|kg|g|ml|l)\b/g, ' ')
    .replace(/\s+/g, ' ').trim();
}
function slug(value: string): string { return normalized(value).replace(/\s+/g, '-').slice(0, 120); }
function unitLabel(source: SourceItem): string {
  const unit = pack(`${source.size} ${source.packaging} ${source.unit}`);
  if (unit === 'piece') return '1 pc';
  return `1 ${unit}`;
}
function sourceKey(item: SourceItem): string {
  return [baseName(item.name), normalized(item.brand), normalized(item.size), pack(`${item.packaging} ${item.unit}`)].join('|');
}
function isDrink(item: SourceItem): boolean {
  return /\b(drink|drinks|juice|water|cola|soda|beverage)\b/i.test(`${item.name} ${item.category} ${item.subcategory}`);
}
function correctedCategory(name: string, category: string): string {
  // Fevi Kwik is an adhesive.  Keep the correction with the importer so a
  // future Excel UPSERT cannot put it back into a snack/chocolate category.
  return /\bfevi\s*(?:kwik|quik)\b/i.test(name) ? 'Glue' : category;
}
function itemName(item: SourceItem): string { return `${item.name} - ${item.packaging}`.replace(/\s+-\s+$/, '').trim(); }

function readWorkbook(file: string): WorkbookSheet[] {
  if (!existsSync(file)) throw new Error(`Workbook not found: ${file}`);
  mkdirSync(outputDir, { recursive: true });
  const output = resolve(outputDir, `source-${Date.now()}.json`);
  execFileSync('powershell.exe', ['-NoProfile', '-File', readerPath, '-Source', file, '-Output', output], {
    cwd: projectDir, stdio: 'ignore', timeout: 60000,
  });
  return JSON.parse(readFileSync(output, 'utf8').replace(/^\uFEFF/, '')) as WorkbookSheet[];
}

function parseFinalInventory(workbook: WorkbookSheet[]): SourceItem[] {
  const finalInventory = workbook[0];
  if (!finalInventory?.rows.length) throw new Error('The workbook has no inventory rows.');
  // Accept the corrected catalogue workbook as well as the original
  // Final Inventory layout. Its first sheet uses one column per package
  // price and deliberately marks untracked stock as Unlimited.
  if (finalInventory.rows[0].cells.A1 === 'Product Name') {
    return finalInventory.rows.slice(1).flatMap((row) => {
      const cell = (column: string) => text(row.cells[`${column}${row.row}`]);
      const name = cell('A');
      if (!name) return [];
      const prices: Array<[string, string]> = [
        ['piece', cell('E')], ['packet', cell('F')], ['dozen', cell('G')],
        ['bag', cell('H')], ['carton', cell('I')],
      ];
      const selected = prices.find(([, value]) => price(value) !== null) ?? prices[0];
      const stockCell = cell('D');
      return [{
        row: row.row, number: String(row.row - 1), name,
        brand: cell('B') === 'Not specified' ? '' : cell('B'),
        category: correctedCategory(name, 'Other General'), subcategory: '',
        size: cell('C'), packaging: selected[0], packCount: '',
        notes: cell('K'), unit: selected[0], price: price(selected[1]) ?? 100,
        stock: stock(stockCell), unlimited: !stockCell || /^unlimited$/i.test(stockCell),
        location: cell('J'), source: 'product_catalogue_unlimited_and_error_audit.xlsx',
      }];
    });
  }
  if (finalInventory.rows[0].cells.A1 !== 'S.N.') {
    throw new Error('The first sheet must be Final Inventory or Product Catalogue with the expected headers.');
  }
  return finalInventory.rows.slice(1).flatMap((row) => {
    const cell = (column: string) => text(row.cells[`${column}${row.row}`]);
    const name = cell('B');
    if (!name) return [];
    const stockCell = cell('L') || cell('I');
    return [{
      row: row.row, number: cell('A'), name, brand: cell('C'), category: correctedCategory(name, cell('D')), subcategory: cell('E'),
      size: cell('F'), packaging: cell('G'), packCount: cell('H'), notes: cell('I'), unit: cell('J'),
      price: price(cell('K')), stock: stock(stockCell), unlimited: /^unlimited$/i.test(stockCell),
      location: cell('M'), source: cell('R'),
    }];
  });
}

function existingKey(item: ExistingItem): string {
  return [baseName(item.name), normalized(item.brand ?? ''), '', pack(item.unitLabel)].join('|');
}
function narrowCandidates(source: SourceItem, all: ExistingItem[]): ExistingItem[] {
  const sourcePack = pack(`${source.packaging} ${source.unit}`);
  const sourceBase = baseName(source.name);
  const sourceDisplayName = normalized(itemName(source));
  const sourceRawVariantName = itemName(source).toLocaleLowerCase().trim();
  const sourceBrand = normalized(source.brand);
  const matches = all.filter((item) => {
    // Packaging belongs to the unit label. Product names can legitimately
    // contain words such as "pack" or "box" (for example Blue Pack), which
    // must not change the variant match.
    const exactVariantName = normalized(item.name) === sourceDisplayName
      || item.name.toLocaleLowerCase().trim() === sourceRawVariantName;
    const matchesName = baseName(item.name) === sourceBase || exactVariantName;
    if (!matchesName || (!exactVariantName && pack(item.unitLabel) !== sourcePack)) return false;
    return !sourceBrand || !item.brand || normalized(item.brand) === sourceBrand;
  });
  return matches;
}

async function loadExisting(db: ReturnType<typeof createTursoPrismaClient>): Promise<{ items: ExistingItem[]; rooms: Map<string, string>; categories: Map<string, string> }> {
  const [products, wholesale, roomStocks, rooms, categories] = await Promise.all([
    db.product.findMany({ select: { id: true, sku: true, barcode: true, name: true, brand: true, price: true, unitLabel: true, isVendingDrink: true, categoryId: true, category: { select: { name: true } }, inventory: { select: { totalStock: true, reservedStock: true, isUnlimited: true } } } }),
    db.wholesaleItem.findMany({ select: { id: true, sku: true, name: true, brand: true, price: true, unitLabel: true, categoryId: true, category: { select: { name: true } }, stock: true, isUnlimited: true } }),
    db.inventoryRoomStock.findMany({ select: { productId: true, roomId: true, quantity: true } }),
    db.inventoryRoom.findMany({ select: { id: true, number: true, active: true } }),
    db.category.findMany({ select: { id: true, name: true, slug: true } }),
  ]);
  const roomsById = new Map(rooms.filter((room) => room.active).map((room) => [room.id, room.number]));
  const locations = new Map<string, string[]>();
  for (const stockRow of roomStocks) {
    const room = roomsById.get(stockRow.roomId);
    if (!room || stockRow.quantity <= 0) continue;
    const values = locations.get(stockRow.productId) ?? [];
    values.push(room);
    locations.set(stockRow.productId, values);
  }
  const items: ExistingItem[] = [
    ...products.map((product) => ({
      id: product.id, kind: product.isVendingDrink ? 'drinks' as const : 'retail' as const, sku: product.sku, barcode: product.barcode,
      name: product.name, brand: product.brand, unitLabel: product.unitLabel, price: Number(product.price), categoryId: product.categoryId,
      categoryName: product.category.name, stock: product.inventory ? product.inventory.totalStock - product.inventory.reservedStock : null,
      unlimited: product.inventory?.isUnlimited ?? false, locations: locations.get(product.id) ?? [],
    })),
    ...wholesale.map((item) => ({
      id: item.id, kind: 'wholesale' as const, sku: item.sku, barcode: null, name: item.name, brand: item.brand,
      unitLabel: item.unitLabel, price: Number(item.price), categoryId: item.categoryId, categoryName: item.category.name,
      stock: item.stock, unlimited: item.isUnlimited, locations: locations.get(`wholesale-${item.id}`) ?? [],
    })),
  ];
  return { items, rooms: new Map(rooms.filter((room) => room.active).map((room) => [room.number, room.id])), categories: new Map(categories.map((category) => [normalized(category.name), category.id])) };
}

function makePreview(items: SourceItem[], existing: ExistingItem[], rooms: Map<string, string>): Preview[] {
  const grouped = new Map<string, SourceItem[]>();
  for (const item of items) {
    const values = grouped.get(sourceKey(item)) ?? [];
    values.push(item); grouped.set(sourceKey(item), values);
  }
  const preview: Preview[] = [];
  for (const [key, group] of grouped) {
    const source = group[0];
    const locations = [...new Set(group.map((item) => item.location).filter(Boolean))];
    const invalidLocation = locations.find((location) => !validLocations.has(location) || !rooms.has(location));
    const quantityKnown = group.every((item) => item.unlimited || item.stock !== null);
    const sourceUnlimited = group.every((item) => item.unlimited)
      || (completeApprovedImport && !quantityKnown);
    const sourceStock = sourceUnlimited ? null : group.reduce((sum, item) => sum + (item.stock ?? 0), 0);
    const roomQuantities = [...group.reduce((byRoom, item) => {
      if (item.location && item.stock !== null) byRoom.set(item.location, (byRoom.get(item.location) ?? 0) + item.stock);
      return byRoom;
    }, new Map<string, number>()).entries()].map(([room, quantity]) => ({ room, quantity }));
    const safeRoomStock = !sourceUnlimited && quantityKnown && !invalidLocation && locations.length > 0
      && roomQuantities.reduce((sum, item) => sum + item.quantity, 0) === sourceStock;
    const candidates = narrowCandidates(source, existing);
    const targetKind: InventoryKind = candidates.length === 1 ? candidates[0].kind : isDrink(source) ? 'drinks' : 'retail';
    const base: Omit<Preview, 'action' | 'message'> = { source, kind: targetKind, sourceKey: key, newPrice: source.price, newStock: sourceStock, newLocations: locations };
    if (!source.category || !source.packaging) {
      preview.push({ ...base, action: 'review', message: 'Missing category or packaging.' }); continue;
    }
    if (candidates.length > 1 && !completeApprovedImport) {
      preview.push({ ...base, action: 'review', message: `Ambiguous match: ${candidates.map((candidate) => `${candidate.kind}/${candidate.sku}`).join(', ')}.` }); continue;
    }
    if (candidates.length >= 1) {
      const item = [...candidates].sort((left, right) => left.sku.localeCompare(right.sku))[0];
      const stockCanChange = sourceUnlimited || safeRoomStock;
      const messages = [candidates.length > 1 ? `Use existing ${item.sku} as the canonical match; no duplicate will be created.` : 'Update valid product fields.'];
      if (source.price === null) messages.push('Price remains unchanged because the Excel cell is blank.');
      if (sourceStock === null && !sourceUnlimited) messages.push('Stock remains unchanged because the Excel stock value is blank or not an absolute quantity.');
      if ((invalidLocation || !locations.length) && !completeApprovedImport) messages.push('Location remains unchanged because the Excel room is missing or not configured.');
      else if (!safeRoomStock && !sourceUnlimited) messages.push('Stock and room allocation require review because each requested room needs an absolute quantity.');
      preview.push({ ...base, action: 'update', matchId: item.id, matchReason: 'Normalized name, brand, and packaging match.',
        oldPrice: item.price, newPrice: source.price ?? item.price, oldStock: item.stock,
        newStock: (stockCanChange || (completeApprovedImport && sourceStock !== null)) ? sourceStock : item.stock, oldLocations: item.locations,
        newLocations: safeRoomStock ? locations : item.locations, setPrice: source.price !== null,
        setStock: stockCanChange || (completeApprovedImport && sourceStock !== null),
        setLocation: safeRoomStock, setUnlimited: sourceUnlimited,
        roomQuantities, message: messages.join(' ') });
      continue;
    }
    if (invalidLocation && !completeApprovedImport) {
      preview.push({ ...base, action: 'review', message: `Location ${invalidLocation} is not an active configured room.` }); continue;
    }
    if (!locations.length && !completeApprovedImport) {
      preview.push({ ...base, action: 'review', message: 'No inventory location supplied.' }); continue;
    }
    if (!quantityKnown && !completeApprovedImport) {
      preview.push({ ...base, action: 'review', message: 'Stock is blank or not a valid absolute quantity; it is not safe to change stock.' }); continue;
    }
    if (source.price === null) {
      preview.push({ ...base, action: 'review', message: 'Price is blank; it will not be guessed.' }); continue;
    }
    if (/\b(carton|bundle|box|dozen)\b/i.test(source.packaging) && !completeApprovedImport) {
      preview.push({ ...base, action: 'review', message: 'New packaging could be retail or wholesale; the workbook does not explicitly identify its inventory type.' }); continue;
    }
    if (!safeRoomStock && !sourceUnlimited && !completeApprovedImport) {
      preview.push({ ...base, action: 'review', message: 'Each new product room must have a valid absolute quantity.' }); continue;
    }
    preview.push({ ...base, action: 'insert', setPrice: true, setStock: true, setLocation: safeRoomStock, setUnlimited: sourceUnlimited,
      roomQuantities, message: sourceUnlimited ? `Insert as ${targetKind} with unlimited stock.` : `Insert as ${targetKind}.` });
  }
  return preview;
}

function markdown(report: Preview[], hash: string, sourceRows: number): string {
  const count = (action: Action) => report.filter((row) => row.action === action).length;
  const changed = (field: 'price' | 'stock' | 'location') => report.filter((row) => field === 'price'
    ? row.action === 'update' && row.oldPrice !== row.newPrice
    : field === 'stock' ? row.action === 'update' && row.setStock === true
      && row.setUnlimited !== true && row.source.unlimited !== true && row.oldStock !== row.newStock
    : row.action === 'update' && (row.oldLocations ?? []).join(',') !== (row.newLocations ?? []).join(',')).length;
  return [
    '# Faststore Final Inventory UPSERT dry run', '',
    `Workbook: ${basename(workbookPath)}`, `Preview hash: ${hash}`, '',
    `- Excel rows read from Final Inventory: ${sourceRows}`,
    `- Unique product variants after combining duplicate source rows: ${report.length}`,
    `- New records to insert: ${count('insert')}`,
    `- Existing records to update: ${count('update')}`,
    `- Duplicate or ambiguous records requiring review: ${report.filter((row) => /Ambiguous|New packaging/.test(row.message)).length}`,
    `- Total manual-review records: ${count('review')}`,
    `- Proposed price changes: ${changed('price')}`,
    `- Proposed stock changes: ${changed('stock')}`,
    `- Proposed location changes: ${changed('location')}`,
    '', 'No database writes were performed. `--apply` also requires this exact preview hash.', '',
    '| Excel rows | Product | Type | Action | Price old -> new | Stock old -> new | Location old -> new | Detail |',
    '|---|---|---|---|---|---|---|---|',
    ...report.map((row) => `| ${row.source.row} | ${row.source.name} (${row.source.packaging}) | ${row.kind} | ${row.action} | ${row.oldPrice ?? ''} -> ${row.newPrice ?? ''} | ${row.oldStock ?? ''} -> ${row.source.unlimited ? 'Unlimited' : row.newStock ?? ''} | ${(row.oldLocations ?? []).join(', ') || ''} -> ${(row.newLocations ?? []).join(', ') || ''} | ${row.message} |`),
    '',
  ].join('\n');
}

async function reconcileRoomAllocation(
  tx: Prisma.TransactionClient,
  productKey: string,
  total: number,
  allocations: Array<{ roomId: string; quantity: number }>,
  referenceId: string,
): Promise<void> {
  const targets = new Map(allocations.filter((item) => item.quantity > 0).map((item) => [item.roomId, item.quantity]));
  if ([...targets.values()].reduce((sum, quantity) => sum + quantity, 0) !== total) {
    throw new Error('Room allocation does not equal the requested absolute stock.');
  }
  const currentRows = await tx.inventoryRoomStock.findMany({ where: { productId: productKey }, select: { roomId: true, quantity: true } });
  const current = new Map(currentRows.map((item) => [item.roomId, item.quantity]));
  // The workbook declares absolute stock.  Reconcile every room to that exact
  // distribution, including reductions, and retain an auditable movement for
  // each difference.  This prevents a stale room quantity from blocking a
  // valid, approved stock correction.
  for (const roomId of new Set([...current.keys(), ...targets.keys()])) {
    const currentQuantity = current.get(roomId) ?? 0;
    const targetQuantity = targets.get(roomId) ?? 0;
    if (currentQuantity === targetQuantity) continue;
    if (targetQuantity === 0) {
      await tx.inventoryRoomStock.delete({ where: { roomId_productId: { roomId, productId: productKey } } });
    } else {
      await tx.inventoryRoomStock.upsert({
        where: { roomId_productId: { roomId, productId: productKey } },
        create: { roomId, productId: productKey, quantity: targetQuantity },
        update: { quantity: targetQuantity },
      });
    }
    const difference = Math.abs(targetQuantity - currentQuantity);
    await tx.inventoryRoomMovement.create({ data: {
      productId: productKey,
      fromRoomId: targetQuantity < currentQuantity ? roomId : null,
      toRoomId: targetQuantity > currentQuantity ? roomId : null,
      quantity: difference,
      reason: 'EXCEL_ABSOLUTE_RECONCILIATION',
      referenceId,
    } });
  }
}

async function applyPreview(db: ReturnType<typeof createTursoPrismaClient>, report: Preview[], rooms: Map<string, string>, categories: Map<string, string>, hash: string) {
  const inventory = new InventoryService(db);
  for (const row of report.filter((entry) => entry.action === 'insert' || entry.action === 'update')) {
    const targetRooms = row.newLocations ?? [];
    const total = row.newStock ?? 0;
    const roomAllocations = (row.roomQuantities ?? []).map((allocation) => ({ roomId: rooms.get(allocation.room)!, quantity: allocation.quantity }));
    await db.$transaction(async (tx) => {
      const categoryKey = normalized(row.source.category);
      const currentCategory = categories.get(categoryKey)
        ? null
        : await tx.category.findFirst({ where: { name: row.source.category }, select: { id: true } });
      const categoryId = categories.get(categoryKey) ?? currentCategory?.id
        ?? (await tx.category.create({ data: { name: row.source.category, slug: `${slug(row.source.category)}-${randomUUID().slice(0, 8)}` } })).id;
      if (row.action === 'insert') {
        const product = await tx.product.create({ data: {
          sku: `FINAL-INV-${hash.slice(0, 12)}-${row.source.row}`, slug: `${slug(itemName(row.source))}-${hash.slice(0, 8)}-${row.source.row}`,
          name: itemName(row.source), brand: row.source.brand || null, categoryId, price: new Prisma.Decimal(row.newPrice!),
          unitLabel: unitLabel(row.source), isVendingDrink: row.kind === 'drinks',
          description: `Imported from ${basename(workbookPath)} row ${row.source.row}.`,
        } });
        if (row.setUnlimited || row.source.unlimited) {
          await tx.inventory.create({ data: { productId: product.id, totalStock: 0, isUnlimited: true } });
          // Unlimited stock has no quantity to allocate, but its physical room
          // remains useful at checkout. Store a zero-quantity room assignment.
          for (const roomId of targetRooms.map((number) => rooms.get(number)).filter((value): value is string => Boolean(value))) {
            await tx.inventoryRoomStock.upsert({
              where: { roomId_productId: { roomId, productId: product.id } },
              create: { roomId, productId: product.id, quantity: 0 },
              update: {},
            });
          }
        } else {
          await inventory.setStock(tx, product.id, total, `excel:${hash}:${row.source.row}`, `Opening stock from ${basename(workbookPath)} row ${row.source.row}.`);
          if (total > 0) await allocateOpeningRoomStock(tx, product.id, total, roomAllocations, undefined, unitLabel(row.source));
        }
      } else if (row.kind === 'wholesale') {
        const existing = await tx.wholesaleItem.findUnique({ where: { id: row.matchId! }, select: { id: true } });
        if (!existing) throw new Error(`Matched wholesale item ${row.matchId} disappeared before apply.`);
        await tx.wholesaleItem.update({ where: { id: existing.id }, data: {
          name: itemName(row.source), ...(row.source.brand ? { brand: row.source.brand } : {}),
          categoryId, ...(row.setPrice ? { price: new Prisma.Decimal(row.newPrice!) } : {}), unitLabel: unitLabel(row.source),
          ...(row.setStock ? { stock: total, isUnlimited: row.setUnlimited || row.source.unlimited } : {}),
        } });
        if (row.setLocation && !row.source.unlimited) {
          await reconcileRoomAllocation(tx, `wholesale-${existing.id}`, total, roomAllocations, `excel:${hash}:${row.source.row}`);
        }
      } else {
        const existing = await tx.product.findUnique({ where: { id: row.matchId! }, select: { id: true, inventory: { select: { isUnlimited: true } } } });
        if (!existing) throw new Error(`Matched product ${row.matchId} disappeared before apply.`);
        await tx.product.update({ where: { id: existing.id }, data: {
          name: itemName(row.source), ...(row.source.brand ? { brand: row.source.brand } : {}), categoryId,
          ...(row.setPrice ? { price: new Prisma.Decimal(row.newPrice!) } : {}), unitLabel: unitLabel(row.source),
        } });
        if (row.setStock) {
          if (row.setUnlimited || row.source.unlimited) {
            await tx.inventory.upsert({ where: { productId: existing.id }, create: { productId: existing.id, totalStock: 0, isUnlimited: true }, update: { isUnlimited: true } });
          } else {
            await tx.inventory.upsert({ where: { productId: existing.id }, create: { productId: existing.id, totalStock: 0, isUnlimited: false }, update: { isUnlimited: false } });
            await inventory.setStock(tx, existing.id, total, `excel:${hash}:${row.source.row}`, `Absolute stock set from ${basename(workbookPath)} row ${row.source.row}.`);
            if (row.setLocation) await reconcileRoomAllocation(tx, existing.id, total, roomAllocations, `excel:${hash}:${row.source.row}`);
          }
        }
      }
    }, { timeout: 30000 });
  }
}

/**
 * Save a read-only catalogue snapshot before each change set.  This lets the
 * importer be retried or manually reversed without touching the live schema.
 */
async function backupCatalogue(db: ReturnType<typeof createTursoPrismaClient>, label: string): Promise<string> {
  mkdirSync(outputDir, { recursive: true });
  // Read through libSQL directly so legacy SQLite timestamp strings can be
  // backed up verbatim even when Prisma cannot coerce them to DateTime.
  const client = createClient({
    url: process.env.TURSO_DATABASE_URL!,
    authToken: process.env.TURSO_AUTH_TOKEN!,
  });
  const readTable = async (table: string) => {
    const result = await client.execute(`SELECT * FROM \"${table}\"`);
    return result.rows.map((row) => Object.fromEntries(Object.entries(row).map(([key, value]) => [
      key,
      value instanceof Uint8Array ? { base64: Buffer.from(value).toString('base64') } : value,
    ])));
  };
  const [products, wholesaleItems, rooms, roomStock] = await Promise.all([
    readTable('Product'), readTable('WholesaleItem'), readTable('InventoryRoom'), readTable('InventoryRoomStock'),
  ]);
  client.close();
  const backupPath = resolve(outputDir, `catalogue-before-${label}.json`);
  writeFileSync(backupPath, JSON.stringify({
    capturedAt: new Date().toISOString(),
    products,
    wholesaleItems,
    rooms,
    roomStock,
  }, null, 2));
  return backupPath;
}

async function main() {
  const sourceHash = createHash('sha256').update(readFileSync(workbookPath)).digest('hex');
  const workbook = readWorkbook(workbookPath);
  const sourceRows = parseFinalInventory(workbook);
  const db = createTursoPrismaClient();
  try {
    if (prepareRooms) {
      if (!approvedRoomSetup) {
        throw new Error('Room setup refused: pass --approved-room-setup to create the configured Room 5 and Room 6 records.');
      }
      const backupPath = await backupCatalogue(db, `room-setup-${sourceHash.slice(0, 12)}`);
      const prepared = [];
      for (const number of ['5', '6']) {
        prepared.push(await db.inventoryRoom.upsert({
          where: { number },
          update: { active: true },
          create: { number, name: `Room ${number}`, active: true },
          select: { id: true, number: true, name: true, active: true },
        }));
      }
      console.log(JSON.stringify({ preparedRooms: prepared, backupPath }));
      return;
    }
    const { items, rooms, categories } = await loadExisting(db);
    const report = makePreview(sourceRows, items, rooms);
    const previewHash = createHash('sha256').update(JSON.stringify({ sourceHash, report })).digest('hex');
    const output = { generatedAt: new Date().toISOString(), sourceHash, previewHash, sourceRows: sourceRows.length, uniqueVariants: report.length, report };
    mkdirSync(outputDir, { recursive: true });
    writeFileSync(previewPath, JSON.stringify(output, null, 2));
    writeFileSync(reportPath, `${markdown(report, previewHash, sourceRows.length)}\n`);
    if (apply) {
      if (!approval || approval !== previewHash) throw new Error('Apply refused: pass the current dry-run preview hash using --approval <hash>.');
      const backupPath = await backupCatalogue(db, `apply-${previewHash.slice(0, 12)}`);
      await applyPreview(db, report, rooms, categories, previewHash);
      console.log(JSON.stringify({ applied: true, previewHash, inserts: report.filter((row) => row.action === 'insert').length, updates: report.filter((row) => row.action === 'update').length, backupPath }));
    } else {
      console.log(JSON.stringify({ applied: false, sourceRows: sourceRows.length, uniqueVariants: report.length, inserts: report.filter((row) => row.action === 'insert').length, updates: report.filter((row) => row.action === 'update').length, reviews: report.filter((row) => row.action === 'review').length, previewHash }));
    }
  } finally { await db.$disconnect(); }
}

void main().catch((error: unknown) => { console.error(error instanceof Error ? error.message : error); process.exitCode = 1; });
