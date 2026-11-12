/** Reviewed inventory import. Dry-run by default; never resets existing stock. */
import 'dotenv/config';
import { randomUUID } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { Prisma } from '@prisma/client';
import { createTursoPrismaClient } from '../src/turso-prisma.js';
import { InventoryService } from '../src/services/inventory.js';
import { allocateOpeningRoomStock } from '../src/services/room-inventory.js';

const dir = '../tmp/inventory-import/';
const review = JSON.parse(readFileSync(dir + 'rechecked-review.json', 'utf8'));
type Entry = { number: number; name: string; category: string; menu: 'Products' | 'Wholesale'; price: number; stock: number; unit: string; room: string; note?: string };
const entries: Entry[] = [];
const add = (number: number, name: string, category: string, menu: Entry['menu'], price: number, stock: number, unit: string, note?: string) =>
  entries.push({ number, name, category, menu, price, stock, unit, room: number === 59 ? '7' : number <= 20 ? '2' : '1', note });
add(20, 'Orange Creme biscuit - Bundle', 'Biscuits', 'Wholesale', 600, 4, '1 bundle');
add(21, 'Horlicks - 15 sachet packet', 'Health Drinks & Nutrition', 'Products', 125, 34, '1 pack', '15 sachets per packet; 34 packets total. Sale unit is one packet.');
add(23, 'Bidi - Bundle', 'Tobacco', 'Wholesale', 100, 57, '1 bundle');
add(24, 'Eveready AA batteries - Packet', 'Batteries', 'Products', 250, 5, '1 pack', 'AA size; price and stock are per packet, not individual battery.');
add(25, 'Ajanta assorted colours - Box', 'Colour', 'Wholesale', 100, 48, '1 box', 'Assorted colours; not mehndi. Original source quantity 48 dib (boxes).');
add(26, 'Dalchini whole masala', 'Masalas', 'Products', 100, 25000, '1 kg', '25 kg stored as 25000 grams.');
add(31, 'Aayo Ultra soap', 'Soap', 'Products', 55, 22, '1 pc');
add(40, 'Tata tea leaves 100g - Bundle', 'Tea & Coffee', 'Wholesale', 800, 84, '1 bundle', 'Packets per bundle not supplied; no retail counterpart generated.');
add(41, 'Nycil', 'Personal Care', 'Products', 100, 42, '1 pc');
add(42, 'Zareen Mehndi - Box', 'Mehndi', 'Wholesale', 100, 17, '1 box');
add(43, 'Neha Mehndi - Box', 'Mehndi', 'Wholesale', 100, 25, '1 box');
add(44, 'Gits Gulab Jamun', 'Food Mixes', 'Products', 100, 29, '1 pack');
add(45, 'Coffee Chocolate - Box', 'Chocolate', 'Wholesale', 100, 40, '1 box', 'Image intentionally blank at owner request.');
add(46, 'Makhan - Bag', 'Groceries', 'Wholesale', 100, 4, '1 bag', '4 bags (bora); weight unspecified. Do not infer kilograms.');
add(47, 'Ice Puff - Packet', 'Snacks & Namkeen', 'Products', 100, 12, '1 pack');
add(50, 'Gugal agarbatti - Packet', 'Dhoop', 'Products', 100, 60, '1 pack');
add(51, 'Small Kapoor - Packet', 'Puja & Religious Items', 'Products', 100, 324, '1 pack', '12 boxes of 27 packets = 324 packets total. Box sale pending shared-stock support.');
add(52, 'Brahma agarbatti - Packet', 'Dhoop', 'Products', 100, 360, '1 pack', '12 bundles of 30 packets = 360 packets. Owner-authorized placeholder price; do not infer NPR 10 from the old source name.');
add(53, 'Navaratan Oil - 24 sachet packet', 'Personal Care', 'Products', 100, 50, '1 pack', '24 sachets per packet; 50 packets = 1200 sachets, not additional stock.');
add(54, 'Madhu Sopari', 'Supari', 'Products', 100, 100000, '1 kg', '100 kg stored as 100000 grams; price per kg.');
add(55, 'Chura - Packet', 'Groceries', 'Products', 100, 33, '1 pack');
add(56, 'Madhu gutka', 'Tobacco', 'Products', 100, 50, '1 pc');
add(57, 'Choco Choco chocolate - Box', 'Chocolate', 'Wholesale', 100, 6, '1 box');
add(58, 'Bhai Tika Chandan colour - Packet', 'Puja & Religious Items', 'Products', 100, 14, '1 pack');
add(59, 'Mini Shikhar - Packet', 'Tobacco', 'Products', 100, 8, '1 pack');
add(60, 'Pandit Ji Dhoop - Packet', 'Dhoop', 'Products', 100, 2, '1 pack');

// These decisions are persisted even when shared-stock schema approval is pending.
const linked = [
  { numbers: [14, 15], name: 'Choco Kiddo', units: 24, totalPackets: 168, cartonPrice: 100, packetPrice: 70,
    unresolved: 'Owner corrected existing 7 packet stock to 7 cartons of 24 packets. Apply once through an audited adjustment when linking.' },
  { numbers: [16, 17], name: 'Namkin biscuit', units: 12, totalPackets: 36, cartonPrice: 600, packetPrice: 100 },
  { numbers: [27, 28], name: 'Ocean Dhoop', units: 4, totalPackets: 24, bundlePrice: 600, packetPrice: 80 },
  { numbers: [32, 33], name: 'Captain cigarettes', units: 10, totalPackets: 660, bundlePrice: 100, packetPrice: 100,
    unresolved: 'Owner also said No.33 is 1 packet. Confirm whether that is the sale unit or one additional loose packet (661 total).' },
  { numbers: [34, 35], name: 'Mayalu', units: 20, totalPackets: 100, bundlePrice: 1700, packetPrice: 85 },
  { numbers: [36, 37], name: 'Surya', units: 10, totalPackets: 350, bundlePrice: 100, packetPrice: 100 },
  { numbers: [38, 39], name: 'Shikhar Ice', units: 10, totalPackets: 640, bundlePrice: 100, packetPrice: 100,
    unresolved: 'Proposed spreadsheet conversion; owner has not yet confirmed this row. Do not apply.' },
  { numbers: [48], name: 'Garam masala', units: 8, totalPackets: 80, bundlePrice: 100, packetPrice: 100,
    unresolved: 'Smaller unit is a box, not a packet; retain that distinction.' },
  { numbers: [49], name: 'Dettol', units: 4, totalPackets: 404, bundlePrice: 100, packetPrice: 100,
    unresolved: 'Soap versus liquid and size still unspecified.' },
  { numbers: [12, 13], name: 'Fun Center biscuit', units: 6, totalPackets: 24, cartonPrice: 600, packetPrice: 100 },
  { numbers: [18, 19], name: 'Tradition biscuit', units: 8, totalPackets: 24, cartonPrice: 100, packetPrice: 50 },
  { numbers: [61, 62], name: 'Vi-John Blades', units: 5, totalPackets: 61, bundlePrice: 100, packetPrice: 230,
    unresolved: 'No.61 says one bundle remains; No.62 says 61 packets. Confirm whether 61 includes the 5 packets in that bundle.' },
  { numbers: [63], name: 'Dabur Glucose', units: 24, totalPackets: 24, packetPrice: 220,
    unresolved: 'Carton selling price not provided; do not derive a wholesale price automatically.' },
];
const deferred = [22]; // Milk powder confirmed, but pack weight is still unspecified.
const slugify = (value: string) => value.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

async function main() {
  const apply = process.argv.includes('--apply');
  const prisma = createTursoPrismaClient();
  const inventory = new InventoryService(prisma);
  const results: Array<Record<string, unknown>> = [];
  try {
    const rooms = await prisma.inventoryRoom.findMany({ where: { active: true } });
    for (const entry of entries) {
      const room = rooms.find(r => r.number === entry.room);
      if (!room) throw new Error(`Active room ${entry.room} missing.`);
      const sku = `IMPORT-20261110-${entry.number}-${entry.menu === 'Wholesale' ? 'BULK' : 'PACKET'}`;
      const slug = slugify(entry.name);
      const existing = await prisma.product.findFirst({ where: { OR: [{ sku }, { slug }, { name: entry.name }] } });
      const bulk = await prisma.wholesaleItem.findFirst({ where: { OR: [{ sku }, { slug }, { name: entry.name }] } });
      if (existing || bulk) {
        results.push({ number: entry.number, status: 'existing-preserved', id: existing?.id ?? bulk?.id }); continue;
      }
      if (!apply) { results.push({ ...entry, status: 'ready' }); continue; }
      const id = await prisma.$transaction(async tx => {
        // Stable SKU makes reruns safe, and duplicate names never overwrite live stock.
        const category = await tx.category.upsert({ where: { slug: slugify(entry.category) },
          update: {}, create: { name: entry.category, slug: slugify(entry.category) } });
        const description = `Owner-confirmed workbook no. ${entry.number}. ${entry.note ?? ''} ${entry.price === 100 ? 'NPR 100 is an owner-authorized editable placeholder price.' : ''}`.trim();
        if (entry.menu === 'Wholesale') {
          const item = await tx.wholesaleItem.create({ data: { id: randomUUID(), sku, slug, name: entry.name,
            categoryId: category.id, price: new Prisma.Decimal(entry.price), stock: entry.stock,
            unitLabel: entry.unit, minimumQuantity: 1, description } });
          await allocateOpeningRoomStock(tx, `wholesale-${item.id}`, entry.stock, [{ roomId: room.id, quantity: entry.stock }]);
          return item.id;
        }
        const product = await tx.product.create({ data: { sku, slug, name: entry.name, categoryId: category.id,
          price: new Prisma.Decimal(entry.price), unitLabel: entry.unit, description } });
        await inventory.setStock(tx, product.id, entry.stock, `confirmed-import:${entry.number}`, description);
        await allocateOpeningRoomStock(tx, product.id, entry.stock, [{ roomId: room.id, quantity: entry.stock }]);
        return product.id;
      }, { timeout: 30000 });
      results.push({ number: entry.number, status: 'added', id, ...entry });
      writeFileSync(dir + 'confirmed-progress.json', JSON.stringify({ results, linked, deferred }, null, 2));
      console.log(JSON.stringify({ number: entry.number, status: 'added', id }));
    }
    // Relocate existing spreadsheet entries, preserving aggregate and reserved stock.
    for (const number of [...Array.from({ length: 11 }, (_, i) => i + 1), 15, 30]) {
      const row = review.rows.find((r: { number: number }) => r.number === number);
      const item = number <= 11 ? await prisma.wholesaleItem.findUnique({ where: { id: row.existingId } }) :
        await prisma.product.findUnique({ where: { sku: `IMPORT-20261110-${number}-PACKET` }, include: { inventory: true } });
      if (!item) throw new Error(`Existing no. ${number} missing; refusing location guess.`);
      const productId = number <= 11 ? `wholesale-${item.id}` : item.id;
      const target = rooms.find(r => r.number === (number <= 20 ? '2' : '1'))!;
      if (apply) await prisma.$transaction(async tx => {
        const total = number <= 11 ? (await tx.wholesaleItem.findUniqueOrThrow({ where: { id: item.id } })).stock :
          (await tx.inventory.findUniqueOrThrow({ where: { productId: item.id } })).totalStock;
        const stocks = await tx.inventoryRoomStock.findMany({ where: { productId } });
        const assigned = stocks.reduce((sum, s) => sum + s.quantity, 0);
        if (assigned > total) throw new Error(`No.${number}: room stock exceeds aggregate; manual review needed.`);
        for (const stock of stocks.filter(s => s.roomId !== target.id && s.quantity > 0)) {
          await tx.inventoryRoomStock.update({ where: { roomId_productId: { roomId: stock.roomId, productId } }, data: { quantity: 0 } });
          await tx.inventoryRoomMovement.create({ data: { productId, fromRoomId: stock.roomId, toRoomId: target.id,
            quantity: stock.quantity, reason: 'TRANSFER', referenceId: `confirmed-room:${number}` } });
        }
        if (total > assigned) await tx.inventoryRoomMovement.create({ data: { productId, toRoomId: target.id,
          quantity: total - assigned, reason: 'TRANSFER', referenceId: `confirmed-room:${number}` } });
        await tx.inventoryRoomStock.upsert({ where: { roomId_productId: { roomId: target.id, productId } },
          update: { quantity: total }, create: { roomId: target.id, productId, quantity: total } });
        if (number === 30) {
          const category = await tx.category.upsert({ where: { slug: 'dhoop' }, update: {}, create: { name: 'Dhoop', slug: 'dhoop' } });
          await tx.product.update({ where: { id: item.id }, data: { categoryId: category.id } });
        }
      }, { timeout: 30000 });
      results.push({ number, status: apply ? 'room-confirmed' : 'room-planned', room: target.number, id: item.id });
    }
    writeFileSync(dir + (apply ? 'confirmed-results.json' : 'confirmed-plan.json'), JSON.stringify({ applied: apply,
      at: new Date().toISOString(), results, linkedPending: linked, deferred,
      captainConfirmedQuantity: 66, note: 'Pending pairs are not imported as independent stock. Missing identities/pack conversions/quantities remain deferred.' }, null, 2));
    console.log(JSON.stringify({ applied: apply, newItems: results.filter(r => r.status === 'added').length,
      ready: results.filter(r => r.status === 'ready').length, pendingLinkedGroups: linked.length, deferred }));
  } finally { await prisma.$disconnect(); }
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
