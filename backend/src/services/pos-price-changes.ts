import { Prisma } from '@prisma/client';
import { z } from 'zod';

const money = z.number().finite().min(0).max(999999999)
  .refine(v => Math.abs(v * 100 - Math.round(v * 100)) < .0001, 'Use at most two decimal places.');
export const priceChangesInput = z.array(z.object({
  productId: z.string().min(1).max(100), expectedPrice: money, price: money,
}).strict()).min(1).max(100).refine(changes => new Set(changes.map(c => c.productId)).size === changes.length);

export async function applyPosPriceChanges(tx: Prisma.TransactionClient, requestId: string,
  cashierId: string, changes: z.infer<typeof priceChangesInput>) {
  const existing = await tx.posCataloguePriceChange.findUnique({where: {requestId}});
  if (existing) {
    if (existing.cashierId !== cashierId || JSON.stringify(existing.changes) !== JSON.stringify(changes)) {
      throw new Error('POS_QUOTE_CHANGED');
    }
    return;
  }
  for (const change of changes) {
    const wholesale = change.productId.startsWith('wholesale-');
    const id = wholesale ? change.productId.slice('wholesale-'.length) : change.productId;
    const updated = wholesale
      ? await tx.wholesaleItem.updateMany({where: {id, price: change.expectedPrice}, data: {price: change.price}})
      : await tx.product.updateMany({where: {id, price: change.expectedPrice}, data: {price: change.price}});
    if (updated.count !== 1) throw new Error('POS_QUOTE_CHANGED');
  }
  await tx.posCataloguePriceChange.create({data: {requestId, cashierId, changes}});
}
