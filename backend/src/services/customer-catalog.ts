import type { Prisma } from '@prisma/client';

const excludedCategoryTerms = ['rice', 'vegetable', 'dairy'];

const excludedCategoryFilter = {
  OR: excludedCategoryTerms.flatMap((term) => [
    { name: { contains: term, mode: 'insensitive' } },
    { slug: { contains: term, mode: 'insensitive' } },
  ]),
} satisfies Prisma.CategoryWhereInput;

export const CUSTOMER_CATALOG_CATEGORY_FILTER = {
  isActive: true,
  NOT: excludedCategoryFilter,
} satisfies Prisma.CategoryWhereInput;

export const CUSTOMER_CATALOG_PRODUCT_FILTER = {
  isActive: true,
  category: CUSTOMER_CATALOG_CATEGORY_FILTER,
} satisfies Prisma.ProductWhereInput;

export function isExcludedCustomerCategory(name: string, slug: string): boolean {
  const category = `${name} ${slug}`.toLowerCase();
  return excludedCategoryTerms.some((term) => category.includes(term));
}
