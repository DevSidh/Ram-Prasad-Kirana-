/** Corrects the known Fevi Kwik adhesive category without touching stock or prices. */
import 'dotenv/config';
import { randomUUID } from 'node:crypto';
import { createTursoPrismaClient } from '../src/turso-prisma.js';

const apply = process.argv.includes('--apply');
const db = createTursoPrismaClient();

async function main() {
  const matches = await db.product.findMany({
    select: { id: true, name: true, category: { select: { name: true } } },
  });
  const feviKwik = matches.filter((item) => /\bfevi\s*(?:kwik|quik)\b/i.test(item.name));
  if (!apply) {
    console.log(JSON.stringify({ apply: false, matches: feviKwik }));
    return;
  }
  const glue = await db.category.upsert({
    where: { slug: 'glue' },
    update: { name: 'Glue' },
    create: { id: randomUUID(), name: 'Glue', slug: 'glue' },
    select: { id: true, name: true },
  });
  const updated = await db.product.updateMany({
    where: { id: { in: feviKwik.map((item) => item.id) } },
    data: { categoryId: glue.id },
  });
  console.log(JSON.stringify({ apply: true, category: glue.name, updated: updated.count }));
}

main().finally(() => db.$disconnect());
