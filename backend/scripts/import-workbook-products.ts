import 'dotenv/config';
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { resolve } from 'node:path';
import { Prisma } from '@prisma/client';
import { createTursoPrismaClient } from '../src/turso-prisma.js';
import { InventoryService } from '../src/services/inventory.js';
import { allocateOpeningRoomStock } from '../src/services/room-inventory.js';
import { normalizeProductImage } from '../src/services/product-image.js';
import { prismaBytes } from '../src/services/prisma-bytes.js';
import { validateProductUnit } from '../src/services/product-validation.js';

const directory = resolve('../tmp/inventory-import');
const source = readFileSync(resolve(directory, 'source.json'), 'utf8').replace(/^\uFEFF/, '');
const sheets = JSON.parse(source) as Array<{ rows: Array<{ row: number; cells: Record<string, string> }> }>;
const before = JSON.parse(readFileSync(resolve(directory, 'catalogue-before.json'), 'utf8'));
const workbookHash = createHash('sha256').update(readFileSync('D:/Downloads/store_inventory_all_product_image_search_links.xlsx')).digest('hex');
const aliases: Record<number, string> = {
  1: 'HUNK', 2: 'Hajmola Anardana - 1 Box', 3: 'Hajmola Regular',
  4: 'Center Fruit', 5: 'Choco Kids', 6: 'Rock n Roll', 7: 'Sumo lacto',
  8: 'Mero lacto', 9: 'Eclairs', 10: 'Exo Soap', 11: 'Imli bomb',
};
const definitions: Record<number, { name: string; category: string; slug: string; file: string; mime: string; page: string; image: string }> = {
  15: { name: 'Choco Kiddo - Packet', category: 'Chocolate', slug: 'chocolate', file: 'choco-kiddo.jpg', mime: 'image/jpeg',
    page: 'https://www.daraz.com.np/products/choco-kiddo-chocolatey-wafer-14-i113659858.html',
    image: 'https://img.drz.lazcdn.com/static/np/p/ab626b3b5fddb0aafbcff0cb2f00f37f.jpg_720x720q80.jpg' },
  30: { name: 'Black Stone agarbatti - Packet', category: 'Puja & Religious Items', slug: 'puja-religious-items', file: 'black-stone.webp', mime: 'image/webp',
    page: 'https://darshanincense.com/products.php?pid=157&pname=Black+Stone',
    image: 'https://darshanincense.com/admin/uploads/1787315752_Black%20stone.webp' },
};
const reasons: Record<number, string> = {
  12: 'Fun Centre BS does not identify a verified brand/product or matching image.',
  13: 'Fun Centre BS does not identify a verified brand/product or matching image.',
  16: 'Namkin is generic; brand, variety and matching packet are unidentified.',
  19: 'Tradition does not identify a specific snack/brand variant.',
  20: 'Orange Creme lacks a biscuit brand and identifiable packaging.',
  21: 'The 1 kg variant/price entry is explicitly marked for verification; no replacement price was guessed.',
  22: 'Sagar Milk lacks a size/type; an existing 500 g milk powder cannot be assumed to match.',
  24: 'Eveready battery size, type and pack count are unspecified.',
  27: 'Ocean agarbatti brand/packaging cannot be uniquely matched to a downloadable product image.',
  28: 'Ocean agarbatti brand/packaging cannot be uniquely matched to a downloadable product image.',
  31: 'Aayo Ultra soap type/size and a matching product image could not be verified.',
  40: 'Tata 100 g tea variant (Premium/Agni/Gold/etc.) and bundle pack count are unspecified.',
};

const rows = sheets[0].rows.filter(r => r.row > 1 && r.cells[`A${r.row}`]).map(r => {
  const cell = (column: string) => r.cells[`${column}${r.row}`] ?? '';
  const number = Number(cell('A'));
  const existing = aliases[number] ? before.wholesale.find((p: { name: string }) => p.name === aliases[number]) : null;
  const definition = definitions[number];
  const missing: string[] = [];
  if (!cell('D') || Number(cell('D')) <= 0) missing.push('price');
  if (!cell('E')) missing.push('quantity');
  if (!cell('F')) missing.push('location');
  const menu = /^(Carton|Box|Bundle)$/i.test(cell('C')) ? 'Wholesale' : 'Products';
  return { number, excelRow: r.row, name: cell('B'), unit: cell('C'), price: cell('D'), quantity: cell('E'), room: cell('F'),
    suggestedMenu: menu, category: cell('I'), sourceNotes: cell('H'),
    status: existing ? 'already listed' : definition ? 'ready' : 'skipped',
    reason: existing ? 'Existing wholesale listing retained; current price, stock, image and room were not changed.' :
      missing.length ? `Missing ${missing.join(', ')}. ${reasons[number] ?? ''}`.trim() : reasons[number] ?? 'Product identity or packaging is not verified.',
    existingId: existing?.id ?? null,
    existingStock: existing?.stock ?? null,
  };
});

async function main() {
  const apply = process.argv.includes('--apply');
  const prisma = createTursoPrismaClient();
  const inventory = new InventoryService(prisma);
  const results: Array<Record<string, unknown>> = [];
  try {
    for (const row of rows.filter(r => r.status === 'ready')) {
      const definition = definitions[row.number];
      const room = await prisma.inventoryRoom.findFirst({ where: { number: row.room, active: true }, select: { id: true, name: true } });
      if (!room) throw new Error(`No active room ${row.room}; refusing to guess a location.`);
      const price = Number(row.price), quantity = Number(row.quantity);
      if (!Number.isInteger(quantity) || quantity <= 0 || !Number.isFinite(price) || price <= 0) throw new Error(`Invalid source data at no. ${row.number}`);
      const unitLabel = '1 pack';
      const unitError = validateProductUnit({ name: definition.name, categoryName: definition.category, unitLabel });
      if (unitError) throw new Error(unitError);
      const original = readFileSync(resolve(directory, definition.file));
      const normalized = await normalizeProductImage(original, definition.mime);
      const sku = `IMPORT-20261110-${row.number}-PACKET`;
      const slug = definition.name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
      const duplicate = await prisma.product.findFirst({ where: { OR: [{ sku }, { slug }, { name: definition.name }] }, select: { id: true, sku: true } });
      if (duplicate) { row.status = 'already imported'; results.push({ number: row.number, status: row.status, id: duplicate.id }); continue; }
      const duplicateWholesale = await prisma.wholesaleItem.findFirst({ where: { OR: [{ slug }, { name: definition.name }] }, select: { id: true } });
      if (duplicateWholesale) throw new Error(`No. ${row.number} is now in wholesale; inspect before creating a duplicate.`);
      if (!apply) { results.push({ number: row.number, status: 'validated', name: definition.name, price, quantity, room: row.room, imageBytes: original.length }); continue; }
      const created = await prisma.$transaction(async tx => {
        // Recheck the deterministic SKU in the same atomic write transaction.
        const prior = await tx.product.findUnique({ where: { sku }, select: { id: true } });
        if (prior) return prior;
        const category = await tx.category.upsert({ where: { slug: definition.slug },
          create: { name: definition.category, slug: definition.slug }, update: {} });
        const product = await tx.product.create({ data: {
          name: definition.name, sku, slug, barcode: null, categoryId: category.id,
          price: new Prisma.Decimal(row.price), unitLabel, isVendingDrink: false,
          description: `${row.name}. Sold per packet. Imported from inventory workbook, order ${row.number}.`,
          imageData: prismaBytes(original), imageMimeType: definition.mime,
          normalizedImageData: prismaBytes(normalized.data), normalizedMimeType: normalized.mimeType,
        }, select: { id: true } });
        await tx.product.update({ where: { id: product.id }, data: { imageUrl: `/api/v1/products/${product.id}/image` } });
        await inventory.setStock(tx, product.id, quantity, `workbook:${workbookHash.slice(0, 16)}:${row.number}`, `Opening stock from workbook order ${row.number}; ${quantity} packets; source workbook SHA256 ${workbookHash}.`);
        await allocateOpeningRoomStock(tx, product.id, quantity, [{ roomId: room.id, quantity }]);
        return product;
      }, { timeout: 30000 });
      row.status = 'added'; row.reason = 'Created with the spreadsheet price and packet quantity, matching downloaded image and full room allocation.';
      results.push({ number: row.number, status: 'added', id: created.id, sku, price, quantity, room: row.room,
        imageSource: definition.page, downloadedImage: definition.image, imageSha256: createHash('sha256').update(original).digest('hex') });
      console.log(JSON.stringify(results.at(-1)));
    }
    mkdirSync(directory, { recursive: true });
    writeFileSync(resolve(directory, apply ? 'import-results.json' : 'import-preview.json'), JSON.stringify({ workbookHash, applied: apply, capturedAt: new Date().toISOString(), rows, results }, null, 2));
    console.log(JSON.stringify({ applied: apply, counts: rows.reduce((counts, row) => ({ ...counts, [row.status]: (counts[row.status] ?? 0) + 1 }), {} as Record<string, number>), results }));
  } finally { await prisma.$disconnect(); }
}
void main().catch(error => { console.error(error.message); process.exitCode = 1; });
