import { z } from 'zod';
import type { PrismaClient } from '@prisma/client';

export const clearOrderItemsInput = z.object({
  confirmation: z.literal('CONFIRM DELETE'),
}).strict();

export async function clearAllOrderItemDetails(
  prisma: Pick<PrismaClient, 'orderItem'>,
  confirmation: string,
): Promise<number> {
  const parsed = clearOrderItemsInput.safeParse({ confirmation });
  if (!parsed.success) {
    throw new Error('Type CONFIRM DELETE to remove order item details.');
  }

  const result = await prisma.orderItem.deleteMany();
  return result.count;
}
