import { z } from 'zod';

export const orderInput = z.object({
  items: z.array(z.object({
    productId: z.string().trim().min(1),
    quantity: z.number().int().min(1).max(100),
    isWholesale: z.boolean().default(false),
  }).strict()).min(1).max(50),
  addressId: z.string().trim().min(1),
  paymentMethod: z.enum(['COD'], {
    errorMap: () => ({
      message: 'Online payment is not available yet. Choose Cash on Delivery.',
    }),
  }),
  scheduledDeliveryAt: z.string().datetime().nullable().optional(),
  tip: z.number().finite().min(0).max(10000).default(0),
  couponCode: z.string().trim().min(1).max(40).transform((code) => code.toUpperCase()).optional(),
  idempotencyKey: z.string().trim().min(8).max(100).optional(),
}).strict().refine(
  ({ items }) =>
    new Set(items.map((item) => `${item.productId}:${item.isWholesale}`)).size ===
    items.length,
  'Order items must not contain duplicates.',
);
