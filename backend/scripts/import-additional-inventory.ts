/** Owner-requested additional workbook import. Dry run unless --apply. */
import 'dotenv/config';
import { randomUUID } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { Prisma } from '@prisma/client';
import { createTursoPrismaClient } from '../src/turso-prisma.js';
import { InventoryService } from '../src/services/inventory.js';
import { allocateOpeningRoomStock } from '../src/services/room-inventory.js';

const directory = '../tmp/inventory-import/';
const source = JSON.parse(readFileSync(directory + 'additional-source.json', 'utf8').replace(/^\uFEFF/, ''));
// Only rows with unambiguous identity, selling unit, price and opening quantity.
const confirmed = [
  { sheet: 1, room: '7', row: 4, name: 'Lotte Choco Pie - Box', sourceName: 'Lotte Choco Pie', category: 'Chocolate & Cakes', bulk: true, price: 300, stock: 7, quantity: '7', unit: '1 box' },
  { sheet: 1, room: '7', row: 5, name: 'Eclairs Pop - Packet', sourceName: 'Eclairs Pop', category: 'Chocolate', bulk: false, price: 300, stock: 2, quantity: '2', unit: '1 pack' },
  { sheet: 1, room: '7', row: 120, name: 'Soan Papdi - Box', sourceName: 'Soan Papdi Box', category: 'Sweets', bulk: true, price: 200, stock: 6, quantity: '6 noted', unit: '1 box' },
  { sheet: 2, room: '2', row: 2, name: 'Aaha Laundry Soap', sourceName: 'Aaha Soap', category: 'Laundry', bulk: false, price: 100, stock: 27, quantity: '27', unit: '1 pc' },
  { sheet: 2, room: '2', row: 5, name: 'Druk Laundry Soap', sourceName: 'Druk', category: 'Laundry', bulk: false, price: 100, stock: 8, quantity: '8', unit: '1 pc' },
  { sheet: 2, room: '2', row: 6, name: 'Dhoni Laundry Soap 200g', sourceName: 'Dhoni 200g', category: 'Laundry', bulk: false, price: 100, stock: 25, quantity: '25', unit: '1 pc' },
];
const slug = (s: string) => s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
async function main() {
  const db = createTursoPrismaClient();
  const inventory = new InventoryService(db);
  const apply = process.argv.includes('--apply');
  const results = [];
  try {
    for (const entry of confirmed) {
      const room = await db.inventoryRoom.findFirstOrThrow({ where: { number: entry.room, active: true } });
      const row = source[entry.sheet - 1].rows.find((r: {row: number}) => r.row === entry.row);
      const values = Object.values(row.cells);
      if (values[1] !== entry.sourceName || Number(values[4]) !== entry.price || values[5] !== entry.quantity || values[6] !== entry.room) {
        throw new Error(`Workbook row ${entry.row} differs from review; refusing import.`);
      }
      const sku = `ADDITIONAL-20261110-S${entry.sheet}-R${entry.row}`;
      const existing = await db.product.findFirst({ where: { OR: [{ sku }, { slug: slug(entry.name) }, { name: entry.name }] } });
      const wholesale = await db.wholesaleItem.findFirst({ where: { OR: [{ sku }, { slug: slug(entry.name) }, { name: entry.name }] } });
      if (existing || wholesale) {
        results.push({ ...entry, sku, status: 'existing-preserved', id: existing?.id ?? wholesale?.id });
        continue;
      }
      if (!apply) { results.push({ ...entry, sku, status: 'ready' }); continue; }
      const id = await db.$transaction(async tx => {
        const category = await tx.category.upsert({ where: { slug: slug(entry.category) }, update: {}, create: { name: entry.category, slug: slug(entry.category) } });
        const description = `Additional corrected workbook, sheet ${entry.sheet} row ${entry.row}; room ${entry.room}. Stock is in ${entry.unit}. Image pending verified match. ${entry.price === 100 ? 'Workbook placeholder price NPR 100.' : ''} ${entry.name === 'Aaha Laundry Soap' || entry.name === 'Druk Laundry Soap' ? 'Pack weight not supplied; do not infer a size.' : ''}`;
        if (entry.bulk) {
          const item = await tx.wholesaleItem.create({ data: { id: randomUUID(), sku, slug: slug(entry.name), name: entry.name, price: new Prisma.Decimal(entry.price), stock: entry.stock, unitLabel: entry.unit, categoryId: category.id, description, minimumQuantity: 1 } });
          await allocateOpeningRoomStock(tx, `wholesale-${item.id}`, entry.stock, [{ roomId: room.id, quantity: entry.stock }]);
          return item.id;
        }
        const item = await tx.product.create({ data: { sku, slug: slug(entry.name), name: entry.name, price: new Prisma.Decimal(entry.price), unitLabel: entry.unit, categoryId: category.id, description } });
        await inventory.setStock(tx, item.id, entry.stock, sku, description);
        await allocateOpeningRoomStock(tx, item.id, entry.stock, [{ roomId: room.id, quantity: entry.stock }]);
        return item.id;
      }, { timeout: 30000 });
      results.push({ ...entry, sku, id, status: 'added' });
      writeFileSync(directory + 'additional-progress.json', JSON.stringify(results, null, 2));
    }
    writeFileSync(directory + (apply ? 'additional-results.json' : 'additional-plan.json'), JSON.stringify(results, null, 2));
    console.log(JSON.stringify({ apply, results: results.map(r => ({ row: r.row, name: r.name, status: r.status })) }));
  } finally { await db.$disconnect(); }
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
