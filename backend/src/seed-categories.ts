import dotenv from 'dotenv';
import { PrismaClient } from '@prisma/client';

dotenv.config();

const defaultCategories = [
  ['Dal & Pulses', 'dal-pulses'],
  ['Cooking Oil', 'cooking-oil'],
  ['Spices & Masala', 'spices-masala'],
  ['Salt & Sugar', 'salt-sugar'],
  ['Flour & Baking', 'flour-baking'],
  ['Noodles & Pasta', 'noodles-pasta'],
  ['Biscuits', 'biscuits'],
  ['Snacks & Chips', 'snacks-chips'],
  ['Chocolates & Candy', 'chocolates-candy'],
  ['Tea & Coffee', 'tea-coffee'],
  ['Soft Drinks', 'soft-drinks'],
  ['Juice & Energy Drinks', 'juice-energy-drinks'],
  ['Sauces & Pickles', 'sauces-pickles'],
  ['Jam & Spreads', 'jam-spreads'],
  ['Personal Care', 'personal-care'],
  ['Oral Care', 'oral-care'],
  ['Hair Care', 'hair-care'],
  ['Bath & Body', 'bath-body'],
  ['Cleaning Products', 'cleaning-products'],
  ['Laundry Products', 'laundry-products'],
  ['Kitchen Essentials', 'kitchen-essentials'],
  ['Stationery', 'stationery'],
  ['Copies & Notebooks', 'copies-notebooks'],
  ['Baby Care', 'baby-care'],
  ['Household Items', 'household-items'],
  ['Other General Store Items', 'other-general-store-items'],
] as const;

const prisma = new PrismaClient();

async function seedCategories(): Promise<void> {
  await prisma.$transaction(
    defaultCategories.map(([name, slug], sortOrder) =>
      prisma.category.upsert({
        where: { slug },
        create: { name, slug, sortOrder },
        update: {},
      }),
    ),
  );
  console.log(`Ensured ${defaultCategories.length} general-store categories exist.`);
}

seedCategories()
  .catch((error: unknown) => {
    console.error('Unable to create the starter categories:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
