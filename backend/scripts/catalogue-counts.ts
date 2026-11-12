import 'dotenv/config';
import { createTursoPrismaClient } from '../src/turso-prisma.js';
import { CUSTOMER_CATALOG_PRODUCT_FILTER } from '../src/services/customer-catalog.js';
async function main() {
const db = createTursoPrismaClient();
try {
  console.log(JSON.stringify({
    products: await db.product.count(),
    activeProducts: await db.product.count({where:{isActive:true}}),
    drinks: await db.product.count({where:{isActive:true,isVendingDrink:true}}),
    customerVisible: await db.product.count({where:CUSTOMER_CATALOG_PRODUCT_FILTER}),
    wholesale: await db.wholesaleItem.count(),
    activeWholesale: await db.wholesaleItem.count({where:{isActive:true}}),
  }));
} finally { await db.$disconnect(); }
}
main().catch(error => {console.error(error.message); process.exitCode = 1;});
