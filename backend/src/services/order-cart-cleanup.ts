import type { Prisma } from '@prisma/client';

type SubmittedCartItem = {
  productId: string;
  quantity: number;
  isWholesale: boolean;
};

export function orderCartCleanupWhere(
  cartId: string,
  items: readonly SubmittedCartItem[],
): Prisma.CartItemWhereInput {
  return {
    cartId,
    OR: items.map(({ productId, quantity, isWholesale }) => ({
      productId,
      quantity,
      isWholesale,
    })),
  };
}
