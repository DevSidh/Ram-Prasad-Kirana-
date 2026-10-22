import { Router, type RequestHandler } from 'express';
import type { PrismaClient } from '@prisma/client';
import { z } from 'zod';

const reviewInput = z.object({
  rating: z.number().int().min(1).max(5),
});

export function createReviewRouter(
  prisma: PrismaClient,
  authenticateToken: RequestHandler,
) {
  const router = Router();
  router.use(authenticateToken);

  router.post('/products/:id', async (req, res) => {
    const userId = res.locals.authenticatedUserId;
    const parsed = reviewInput.safeParse(req.body);
    if (typeof userId !== 'string') {
      return res.status(401).json({ error: 'Authentication is required.' });
    }
    if (!parsed.success) {
      return res.status(400).json({ error: 'Choose a rating from 1 to 5.' });
    }

    try {
      const summary = await prisma.$transaction(async (transaction) => {
        const product = await transaction.product.findFirst({
          where: {
            id: req.params.id,
            isActive: true,
            category: { isActive: true },
          },
          select: { id: true },
        });
        if (!product) return null;

        await transaction.review.upsert({
          where: {
            productId_userId: { productId: product.id, userId },
          },
          create: {
            productId: product.id,
            userId,
            rating: parsed.data.rating,
          },
          update: { rating: parsed.data.rating },
        });

        const aggregate = await transaction.review.aggregate({
          where: { productId: product.id },
          _avg: { rating: true },
          _count: { _all: true },
        });
        const rating = Number(aggregate._avg.rating ?? 0);
        const reviewCount = aggregate._count._all;
        await transaction.product.update({
          where: { id: product.id },
          data: { rating, reviewCount },
        });
        return { rating, reviewCount };
      });

      if (!summary) return res.status(404).json({ error: 'Product not found.' });
      return res.json({ data: summary });
    } catch (error) {
      console.error('Product rating submission failed:', error);
      return res.status(500).json({ error: 'Unable to save this rating.' });
    }
  });

  router.post('/wholesale/:id', async (req, res) => {
    const userId = res.locals.authenticatedUserId;
    const parsed = reviewInput.safeParse(req.body);
    if (typeof userId !== 'string') {
      return res.status(401).json({ error: 'Authentication is required.' });
    }
    if (!parsed.success) {
      return res.status(400).json({ error: 'Choose a rating from 1 to 5.' });
    }

    try {
      const summary = await prisma.$transaction(async (transaction) => {
        const item = await transaction.wholesaleItem.findFirst({
          where: {
            id: req.params.id,
            isActive: true,
            category: { isActive: true },
          },
          select: { id: true },
        });
        if (!item) return null;

        await transaction.review.upsert({
          where: {
            wholesaleItemId_userId: {
              wholesaleItemId: item.id,
              userId,
            },
          },
          create: {
            wholesaleItemId: item.id,
            userId,
            rating: parsed.data.rating,
          },
          update: { rating: parsed.data.rating },
        });

        const aggregate = await transaction.review.aggregate({
          where: { wholesaleItemId: item.id },
          _avg: { rating: true },
          _count: { _all: true },
        });
        const rating = Number(aggregate._avg.rating ?? 0);
        const reviewCount = aggregate._count._all;
        await transaction.wholesaleItem.update({
          where: { id: item.id },
          data: { rating, reviewCount },
        });
        return { rating, reviewCount };
      });

      if (!summary) {
        return res.status(404).json({ error: 'Wholesale product not found.' });
      }
      return res.json({ data: summary });
    } catch (error) {
      console.error('Wholesale product rating submission failed:', error);
      return res.status(500).json({ error: 'Unable to save this rating.' });
    }
  });

  return router;
}
