import 'dotenv/config';
import { writeFileSync } from 'node:fs';
import { createTursoPrismaClient } from '../src/turso-prisma.js';

async function main() {
  const prisma = createTursoPrismaClient();
  try {
    const snapshot = {
      capturedAt: new Date().toISOString(),
      categories: await prisma.category.findMany({ select: { id: true, name: true, slug: true, isActive: true, sortOrder: true } }),
      products: await prisma.product.findMany({ select: {
        id: true, name: true, sku: true, barcode: true, brand: true, price: true, originalPrice: true,
        unitLabel: true, categoryId: true, isVendingDrink: true, isWholesale: true, wholesalePrice: true,
        wholesaleMinimumQuantity: true, imageUrl: true, isActive: true, isFeatured: true, lowStockThreshold: true,
        inventory: { select: { totalStock: true, reservedStock: true, isUnlimited: true } },
      } }),
      wholesale: await prisma.wholesaleItem.findMany({ select: {
        id: true, name: true, sku: true, brand: true, price: true, stock: true, isUnlimited: true,
        minimumQuantity: true, unitLabel: true, categoryId: true, imageUrl: true, isActive: true,
      } }),
      rooms: await prisma.inventoryRoom.findMany({ select: { id: true, number: true, name: true, active: true } }),
      roomStock: await prisma.inventoryRoomStock.findMany({ select: { productId: true, roomId: true, quantity: true } }),
    };
    const output = process.argv[2] ?? '../tmp/inventory-import/catalogue-before.json';
    writeFileSync(output, JSON.stringify(snapshot, (_key, value) => typeof value === 'bigint' ? value.toString() : value, 2));
    console.log(JSON.stringify({ output, products: snapshot.products.length, wholesale: snapshot.wholesale.length, categories: snapshot.categories.length, rooms: snapshot.rooms }));
  } finally { await prisma.$disconnect(); }
}
void main().catch(error => { console.error(error.message); process.exitCode = 1; });
