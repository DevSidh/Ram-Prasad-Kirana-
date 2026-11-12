import 'dotenv/config';
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync } from 'node:fs';
import { createTursoPrismaClient } from '../src/turso-prisma.js';

async function main() {
  const before = JSON.parse(readFileSync('../tmp/inventory-import/catalogue-before.json', 'utf8'));
  const results = JSON.parse(readFileSync('../tmp/inventory-import/import-results.json', 'utf8'));
  const prisma = createTursoPrismaClient();
  try {
    const products = await prisma.product.findMany({ select: { id: true, name: true, sku: true, price: true, unitLabel: true, categoryId: true, isVendingDrink: true, imageUrl: true, inventory: { select: { totalStock: true, reservedStock: true } } } });
    const wholesale = await prisma.wholesaleItem.findMany({ select: { id: true, name: true, sku: true, price: true, stock: true, unitLabel: true, categoryId: true, imageUrl: true } });
    const comparable = (value: unknown) => JSON.stringify(value);
    for (const old of before.products) assert.equal(comparable(products.find(p => p.id === old.id)), comparable(old), `Existing product changed: ${old.sku}`);
    for (const old of before.wholesale) assert.equal(comparable(wholesale.find(p => p.id === old.id)), comparable(old), `Existing wholesale changed: ${old.sku}`);
    const verified = [];
    for (const item of results.results) {
      const p = await prisma.product.findUniqueOrThrow({ where: { sku: item.sku }, include: { category: true, inventory: true } });
      assert.equal(Number(p.price), item.price);
      assert.equal(p.inventory?.totalStock, item.quantity);
      assert.equal(p.unitLabel, '1 pack');
      assert((p.imageData?.byteLength ?? 0) > 0);
      assert((p.normalizedImageData?.byteLength ?? 0) > 0);
      const rooms = await prisma.inventoryRoomStock.findMany({ where: { productId: p.id }, include: { room: true } });
      assert.equal(rooms.length, 1);
      assert.equal(rooms[0].room.number, item.room);
      assert.equal(rooms[0].quantity, item.quantity);
      assert.equal(await prisma.product.count({ where: { sku: item.sku } }), 1);
      verified.push({ number: item.number, id: p.id, name: p.name, price: Number(p.price), quantity: p.inventory?.totalStock,
        unit: p.unitLabel, category: p.category.name, room: rooms[0].room.number, roomName: rooms[0].room.name,
        originalImageBytes: p.imageData?.byteLength, normalizedImageBytes: p.normalizedImageData?.byteLength });
    }
    const summary = { verifiedAt: new Date().toISOString(), existingProductsUnchanged: before.products.length, existingWholesaleUnchanged: before.wholesale.length, verified };
    writeFileSync('../tmp/inventory-import/verification.json', JSON.stringify(summary, null, 2));
    console.log(JSON.stringify(summary));
  } finally { await prisma.$disconnect(); }
}
void main().catch(error => { console.error(error.message); process.exitCode = 1; });
