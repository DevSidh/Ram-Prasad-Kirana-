import { z } from 'zod';

export const orderInput = z.object({
  items: z.array(z.object({
    productId: z.string().trim().min(1),
    quantity: z.number().int().min(1).max(100),
  }).strict()).min(1).max(50),
  addressId: z.string().trim().min(1),
  paymentMethod: z.enum(['COD'], {
    errorMap: () => ({
      message: 'Online payment is not available yet. Choose Cash on Delivery.',
    }),
  }),
  tip: z.number().finite().min(0).max(10000).default(0),
  idempotencyKey: z.string().trim().min(8).max(100).optional(),
}).strict();
