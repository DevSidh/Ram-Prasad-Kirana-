import { Router, type RequestHandler, type Response } from 'express';
import { Prisma, type PrismaClient } from '@prisma/client';
import { randomBytes, randomUUID } from 'node:crypto';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { getImageMimeType, receiveSingleImage } from '../services/image-upload.js';
import {
  calculateRoadDeliveryQuote,
  DEFAULT_DELIVERY_FEE,
  DeliveryPricingError,
} from '../services/delivery-pricing.js';
import {
  CUSTOMER_CATALOG_PRODUCT_FILTER,
  isExcludedCustomerCategory,
} from '../services/customer-catalog.js';
import { isPushConfigured } from '../services/push-notifications.js';
import { identityAlreadyInUse, normalizePhone } from '../services/user-identity.js';
import { formatUserDisplayId } from '../services/user-display-id.js';
import {
  getBuyingStreakSnapshot,
} from '../services/buying-streak.js';
import { isWeightUnitLabel } from '../services/product-validation.js';

const addressFields = {
  title: z.string().trim().min(1).max(40),
  fullName: z.string().trim().min(1).max(120),
  phone: z.string().trim().min(7).max(30),
  province: z.string().trim().min(1).max(100),
  city: z.string().trim().min(1).max(100),
  street: z.string().trim().min(1).max(240),
  landmark: z.string().trim().max(240).nullable().optional(),
  instructions: z.string().trim().max(500).nullable().optional(),
  isDefault: z.boolean().optional(),
  latitude: z.number().finite().min(-90).max(90).nullable().optional(),
  longitude: z.number().finite().min(-180).max(180).nullable().optional(),
};
const createAddressInput = z.object(addressFields).strict();
const updateAddressInput = z.object(addressFields).partial().strict()
  .refine((value) => Object.keys(value).length > 0);
const updateProfileInput = z.object({
  fullName: z.string().trim().min(1).max(120),
  phone: z.string().trim().min(7).max(30).nullable()
    .transform((phone) => normalizePhone(phone))
    .refine((phone) => phone === null || (phone.length >= 7 && phone.length <= 30)),
}).strict();
const deleteAccountInput = z.object({
  password: z.string().min(1).max(256),
}).strict();
const deviceTokenInput = z.object({
  token: z.string().trim().min(20).max(4096),
  platform: z.enum(['android', 'ios', 'web']),
}).strict();
const customerLocationInput = z.object({
  latitude: z.number().finite().min(-90).max(90),
  longitude: z.number().finite().min(-180).max(180),
}).strict();
const cartInput = z.object({
  items: z.array(z.object({
    productId: z.string().trim().min(1).max(100),
    quantity: z.number().int().min(1).max(100),
    weightGrams: z.number().int().min(1).max(100000).optional(),
    isWholesale: z.boolean().default(false),
  }).strict()).max(100),
}).strict().refine(
  ({ items }) =>
    new Set(items.map((item) => `${item.productId}:${item.isWholesale}`)).size ===
    items.length,
  'Cart items must not contain duplicates.',
);
const wishlistInput = z.object({
  productIds: z.array(z.string().trim().min(1).max(100)).max(200),
}).strict().refine(
  ({ productIds }) => new Set(productIds).size === productIds.length,
  'Saved products must not contain duplicates.',
);
class CartItemRejectedError extends Error {}
type CartResponseItem = {
  product: Record<string, unknown>;
  quantity: number;
  weightGrams?: number;
  isWholesale: boolean;
};

function authenticatedUserId(res: Response): string | null {
  const id = res.locals.authenticatedUserId;
  return typeof id === 'string' ? id : null;
}

function addressResponse(address: {
  id: string;
  label: string | null;
  fullName: string;
  phone: string;
  province: string | null;
  city: string;
  addressLine1: string;
  addressLine2: string | null;
  instructions: string | null;
  isDefault: boolean;
  latitude: number | null;
  longitude: number | null;
}) {
  return {
    id: address.id,
    title: address.label ?? 'Home',
    fullName: address.fullName,
    phone: address.phone,
    province: address.province ?? '',
    city: address.city,
    street: address.addressLine1,
    landmark: address.addressLine2,
    instructions: address.instructions,
    isDefault: address.isDefault,
    latitude: address.latitude,
    longitude: address.longitude,
  };
}

function addressData(input: Partial<z.infer<typeof createAddressInput>>) {
  return {
    ...(input.title !== undefined ? { label: input.title } : {}),
    ...(input.fullName !== undefined ? { fullName: input.fullName } : {}),
    ...(input.phone !== undefined ? { phone: input.phone } : {}),
    ...(input.province !== undefined ? { province: input.province } : {}),
    ...(input.city !== undefined ? { city: input.city } : {}),
    ...(input.street !== undefined ? { addressLine1: input.street } : {}),
    ...(input.landmark !== undefined ? { addressLine2: input.landmark } : {}),
    ...(input.instructions !== undefined ? { instructions: input.instructions } : {}),
    ...(input.isDefault !== undefined ? { isDefault: input.isDefault } : {}),
    ...(input.latitude !== undefined ? { latitude: input.latitude } : {}),
    ...(input.longitude !== undefined ? { longitude: input.longitude } : {}),
  };
}

export function createAccountRouter(
  prisma: PrismaClient,
  authenticateToken: RequestHandler,
): Router {
  const router = Router();
  router.use(authenticateToken);

  router.get('/profile', async (_req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    try {
      const user = await prisma.user.findFirst({
        where: { id: userId, isActive: true },
        select: {
          id: true,
          userNumber: true,
          name: true,
          email: true,
          phone: true,
          role: true,
          avatarUrl: true,
        },
      });
      if (!user) return res.status(404).json({ error: 'Account not found.' });
      return res.json({
        data: {
          id: user.id,
          profileId: formatUserDisplayId(user.userNumber),
          fullName: user.name,
          email: user.email,
          phone: user.phone,
          role: user.role,
          avatarUrl: user.avatarUrl,
        },
      });
    } catch (error) {
      console.error('Profile load failed:', error);
      return res.status(500).json({ error: 'Unable to load your profile.' });
    }
  });

  router.get('/buying-streak', async (_req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    try {
      const snapshot = await getBuyingStreakSnapshot(prisma, userId);
      return res.json(snapshot);
    } catch (error) {
      console.error('Buying streak load failed:', error);
      return res.status(500).json({ error: 'Unable to load your buying streak.' });
    }
  });

  router.post('/buying-streak/rewards/:day/claim', async (req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    const day = Number(req.params.day);
    if (!Number.isSafeInteger(day) || day < 1 || day > 365) {
      return res.status(400).json({ error: 'Choose a valid streak reward.' });
    }
    try {
      const result = await prisma.$transaction(async (tx) => {
        const reward = await tx.buyingStreakRewardProgress.findUnique({
          where: { userId_day: { userId, day } },
          include: {
            couponTemplate: true,
            coupon: { select: { code: true } },
          },
        });
        if (!reward) return { kind: 'locked' as const };
        if (reward.claimedAt) return { kind: 'claimed' as const };
        const template = reward.couponTemplate;
        if (!template || !template.isActive || template.isDeleted ||
            template.assignedUserId !== null ||
            (template.expiresAt !== null &&
                template.expiresAt.getTime() <= Date.now())) {
          return { kind: 'coupon-unavailable' as const };
        }
        const claimedAt = new Date();
        const updated = await tx.buyingStreakRewardProgress.updateMany({
          where: { userId, day, claimedAt: null },
          data: { claimedAt },
        });
        if (updated.count !== 1) {
          throw new Error('STREAK_REWARD_ALREADY_CLAIMED');
        }
        const couponCode =
          `STREAK-${randomUUID().replaceAll('-', '').slice(0, 12).toUpperCase()}`;
        const coupon = await tx.coupon.create({
          data: {
            code: couponCode,
            productId: template.productId,
            assignedUserId: userId,
            discountType: template.discountType,
            discountPercent: template.discountPercent,
            discountAmount: template.discountAmount,
            minOrderAmount: template.minOrderAmount,
            maxDiscount: template.maxDiscount,
            usageLimit: 1,
            perUserLimit: 1,
            expiresAt: template.expiresAt,
          },
          select: { id: true, code: true },
        });
        await tx.buyingStreakRewardProgress.update({
          where: { userId_day: { userId, day } },
          data: { couponId: coupon.id },
        });
        return {
          kind: 'claimed-now' as const,
          day: reward.day,
          title: reward.title,
          description: reward.description,
          claimedAt,
          couponCode: coupon.code,
        };
      });
      if (result.kind === 'locked') {
        return res.status(409).json({
          error: 'Complete this buying streak milestone before claiming its reward.',
        });
      }
      if (result.kind === 'claimed') {
        return res.status(409).json({ error: 'This streak reward was already claimed.' });
      }
      if (result.kind === 'coupon-unavailable') {
        return res.status(409).json({
          error: 'This coupon gift is no longer available. Contact the store.',
        });
      }
      return res.json({
        reward: {
          day: result.day,
          title: result.title,
          description: result.description,
          claimedAt: result.claimedAt.toISOString(),
          couponCode: result.couponCode,
        },
      });
    } catch (error) {
      if (error instanceof Error &&
          error.message === 'STREAK_REWARD_ALREADY_CLAIMED') {
        return res.status(409).json({ error: 'This streak reward was already claimed.' });
      }
      console.error('Buying streak reward claim failed:', error);
      return res.status(500).json({ error: 'Unable to claim this streak reward.' });
    }
  });

  const getUsedCoupons: RequestHandler = async (_req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    try {
      const orders = await prisma.order.findMany({
        where: {
          userId,
          status: { not: 'CANCELLED' },
          couponCode: { not: null },
        },
        select: { couponCode: true },
        distinct: ['couponCode'],
      });
      return res.json({
        usedCouponCodes: orders
          .map((order) => order.couponCode?.trim().toUpperCase())
          .filter((code): code is string => Boolean(code)),
      });
    } catch (error) {
      console.error('Used customer coupons lookup failed:', error);
      return res.status(500).json({ error: 'Unable to load your used coupons.' });
    }
  };
  router.get('/coupons/used', getUsedCoupons);
  router.get('/coupon/used', getUsedCoupons);

  router.get('/coupons/available', async (_req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    try {
      const notifications = await prisma.notification.findMany({
        where: { userId, type: 'PROMOTIONAL' },
        orderBy: { createdAt: 'desc' },
        take: 500,
        select: { metadata: true },
      });
      const notifiedCodes = new Set<string>();
      for (const notification of notifications) {
        const metadata = notification.metadata;
        if (
          typeof metadata === 'object' &&
          metadata !== null &&
          !Array.isArray(metadata) &&
          'couponCode' in metadata &&
          typeof metadata.couponCode === 'string'
        ) {
          notifiedCodes.add(metadata.couponCode.trim().toUpperCase());
        }
      }

      const codes = [...notifiedCodes];
      const [coupons, usageCounts] = await Promise.all([
        prisma.coupon.findMany({
          where: {
            isActive: true,
            isDeleted: false,
            AND: [
              {
                OR: [
                  {
                    isAnnounced: true,
                    productId: null,
                    assignedUserId: null,
                  },
                  { code: { in: codes } },
                ],
              },
              {
                OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
              },
            ],
          },
          select: {
            code: true,
            assignedUserId: true,
            usageLimit: true,
            perUserLimit: true,
            usedCount: true,
          },
        }),
        codes.length === 0
          ? Promise.resolve([])
          : prisma.order.groupBy({
            by: ['couponCode'],
            where: {
              userId,
              status: { not: 'CANCELLED' },
              couponCode: { in: codes },
            },
            _count: { couponCode: true },
          }),
      ]);
      const userUsage = new Map(
        usageCounts.map((row) => [
          row.couponCode?.toUpperCase() ?? '',
          row._count.couponCode,
        ]),
      );
      const availableCouponCodes = coupons
        .filter((coupon) => {
          if (
            coupon.assignedUserId !== null &&
            coupon.assignedUserId !== userId
          ) return false;
          if (
            coupon.usageLimit !== null &&
            coupon.usedCount >= coupon.usageLimit
          ) return false;
          const customerUses = userUsage.get(coupon.code.toUpperCase()) ?? 0;
          return coupon.perUserLimit === null ||
            customerUses < coupon.perUserLimit;
        })
        .map((coupon) => coupon.code.toUpperCase());
      return res.json({ availableCouponCodes });
    } catch (error) {
      console.error('Available customer coupons lookup failed:', error);
      return res.status(500).json({ error: 'Unable to load your available coupons.' });
    }
  });

  router.get('/notifications', async (_req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    try {
      const [notifications, unreadCount] = await Promise.all([
        prisma.notification.findMany({
          where: { userId },
          orderBy: { createdAt: 'desc' },
          take: 100,
        }),
        prisma.notification.count({ where: { userId, isRead: false } }),
      ]);
      return res.json({
        data: notifications,
        unreadCount,
        pushAvailable: isPushConfigured(),
      });
    } catch (error) {
      console.error('Notification list failed:', error);
      return res.status(500).json({ error: 'Unable to load your notifications.' });
    }
  });

  router.patch('/notifications/read-all', async (_req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    try {
      await prisma.notification.updateMany({
        where: { userId, isRead: false },
        data: { isRead: true },
      });
      return res.sendStatus(204);
    } catch (error) {
      console.error('Notification read-all update failed:', error);
      return res.status(500).json({ error: 'Unable to mark your notifications as read.' });
    }
  });

  router.patch('/notifications/:id/read', async (req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    try {
      const updated = await prisma.notification.updateMany({
        where: { id: req.params.id, userId },
        data: { isRead: true },
      });
      if (updated.count !== 1) {
        return res.status(404).json({ error: 'Notification not found.' });
      }
      return res.sendStatus(204);
    } catch (error) {
      console.error('Notification read update failed:', error);
      return res.status(500).json({ error: 'Unable to update this notification.' });
    }
  });

  router.delete('/notifications', async (_req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    try {
      await prisma.notification.deleteMany({ where: { userId } });
      return res.sendStatus(204);
    } catch (error) {
      console.error('Notification clear-all failed:', error);
      return res.status(500).json({ error: 'Unable to delete your notifications.' });
    }
  });

  router.delete('/notifications/:id', async (req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    try {
      const deleted = await prisma.notification.deleteMany({
        where: { id: req.params.id, userId },
      });
      if (deleted.count !== 1) {
        return res.status(404).json({ error: 'Notification not found.' });
      }
      return res.sendStatus(204);
    } catch (error) {
      console.error('Notification deletion failed:', error);
      return res.status(500).json({ error: 'Unable to delete this notification.' });
    }
  });

  router.post('/notifications/device-token', async (req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    const parsed = deviceTokenInput.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'A valid push token and platform are required.' });
    }
    try {
      await prisma.deviceToken.upsert({
        where: { token: parsed.data.token },
        create: {
          userId,
          token: parsed.data.token,
          platform: parsed.data.platform,
        },
        update: { userId, platform: parsed.data.platform },
      });
      return res.status(200).json({ pushAvailable: isPushConfigured() });
    } catch (error) {
      console.error('Push token registration failed:', error);
      return res.status(500).json({ error: 'Unable to enable push notifications.' });
    }
  });

  router.delete('/notifications/device-token/:token', async (req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    try {
      await prisma.deviceToken.deleteMany({
        where: { userId, token: req.params.token },
      });
      return res.sendStatus(204);
    } catch (error) {
      console.error('Push token removal failed:', error);
      return res.status(500).json({ error: 'Unable to disable push notifications.' });
    }
  });

  router.get('/cart', async (_req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    try {
      const cart = await prisma.cart.findUnique({
        where: { userId },
        include: {
          items: {
            include: {
              product: {
                include: {
                  category: { select: { name: true, slug: true, isActive: true } },
                  inventory: { select: { totalStock: true, reservedStock: true } },
                },
              },
              wholesaleItem: {
                include: {
                  category: {
                    select: { name: true, slug: true, isActive: true },
                  },
                },
              },
            },
          },
        },
      });

      const items = (cart?.items ?? []).flatMap<CartResponseItem>((item) => {
        if (item.isWholesale) {
          const wholesaleItem = item.wholesaleItem;
          if (!wholesaleItem || !wholesaleItem.isActive ||
              !wholesaleItem.category.isActive) return [];
          return [{
            product: {
              id: wholesaleItem.id,
              sku: wholesaleItem.sku,
              name: wholesaleItem.name,
              categoryId: wholesaleItem.categoryId,
              categoryName: wholesaleItem.category.name,
              categorySlug: wholesaleItem.category.slug,
              brand: wholesaleItem.brand,
              price: Number(wholesaleItem.price),
              originalPrice: null,
              discountPercent: 0,
              unitLabel: wholesaleItem.unitLabel,
              stock: wholesaleItem.stock,
              rating: 0,
              reviewCount: 0,
              isOrganic: false,
              isFeatured: false,
              isBestSeller: false,
              isWholesale: true,
              wholesalePrice: Number(wholesaleItem.price),
              wholesaleMinimumQuantity: wholesaleItem.minimumQuantity,
              description: wholesaleItem.description ?? '',
              origin: wholesaleItem.origin,
              imageUrl: wholesaleItem.imageMimeType && wholesaleItem.imageUrl
                ? `${wholesaleItem.imageUrl}?v=${wholesaleItem.updatedAt.getTime()}`
                : wholesaleItem.imageUrl ?? '',
            },
            quantity: item.quantity,
            isWholesale: true,
          }];
        }
        const product = item.product;
        if (!product || !product.isActive ||
            !product.category.isActive ||
            isExcludedCustomerCategory(product.category.name, product.category.slug)) {
          return [];
        }
        const price = Number(product.price);
        const originalPrice = product.originalPrice === null
          ? null
          : Number(product.originalPrice);
        const stock = Math.max(
          0,
          (product.inventory?.totalStock ?? 0) -
            (product.inventory?.reservedStock ?? 0),
        );
        const isWeightProduct = isWeightUnitLabel(product.unitLabel);
        return [{
          product: {
            id: product.id,
            sku: product.sku,
            name: product.name,
            categoryId: product.categoryId,
            categoryName: product.category.name,
            categorySlug: product.category.slug,
            brand: product.brand,
            price,
            originalPrice,
            discountPercent: originalPrice !== null && originalPrice > price
              ? Math.round(((originalPrice - price) / originalPrice) * 100)
              : 0,
            unitLabel: product.unitLabel,
            stock: isWeightProduct ? Math.floor(stock / 1000) : stock,
            ...(isWeightProduct ? { weightStockKg: stock / 1000 } : {}),
            rating: Number(product.rating),
            reviewCount: product.reviewCount,
            isOrganic: product.isOrganic,
            isFeatured: product.isFeatured,
            isBestSeller: product.isBestSeller,
            isWholesale: false,
            wholesalePrice: null,
            wholesaleMinimumQuantity: 1,
            description: product.description ?? '',
            origin: product.origin,
            imageUrl: product.imageMimeType && product.imageUrl
              ? `${product.imageUrl}?v=${product.updatedAt.getTime()}`
              : product.imageUrl ?? '',
            imageUrls: Array.isArray(product.imageUrls)
              ? product.imageUrls.filter((url): url is string => typeof url === 'string')
              : [],
          },
          quantity: item.quantity,
          ...(item.weightGrams == null ? {} : { weightGrams: item.weightGrams }),
          isWholesale: false,
        }];
      });
      return res.json({ items });
    } catch (error) {
      console.error('Account cart load failed:', error);
      return res.status(500).json({ error: 'Unable to load your saved basket.' });
    }
  });

  router.put('/orders/:id/live-location', async (req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    const parsed = customerLocationInput.safeParse(req.body);
    if (!parsed.success || !req.params.id || req.params.id.length > 100) {
      return res.status(400).json({ error: 'Send a valid delivery location.' });
    }
    try {
      const updated = await prisma.delivery.updateMany({
        where: {
          orderId: req.params.id,
          status: 'OUT_FOR_DELIVERY',
          order: {
            is: {
              userId,
              status: 'OUT_FOR_DELIVERY',
            },
          },
        },
        data: {
          customerLatitude: parsed.data.latitude,
          customerLongitude: parsed.data.longitude,
          customerLocationUpdatedAt: new Date(),
        },
      });
      if (updated.count !== 1) {
        return res.status(409).json({
          error: 'Location sharing is available only during an active delivery.',
        });
      }
      return res.sendStatus(204);
    } catch (error) {
      console.error('Customer live location update failed:', error);
      return res.status(500).json({ error: 'Unable to share your delivery location.' });
    }
  });

  router.put('/cart', async (req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    const parsed = cartInput.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Check the products and quantities in your basket.' });
    }
    try {
      const [products, wholesaleItems] = await Promise.all([
        prisma.product.findMany({
        where: {
          id: {
            in: parsed.data.items
              .filter((item) => !item.isWholesale)
              .map((item) => item.productId),
          },
          ...CUSTOMER_CATALOG_PRODUCT_FILTER,
          isWholesale: false,
        },
        select: {
          id: true,
          price: true,
          unitLabel: true,
          inventory: { select: { totalStock: true, reservedStock: true } },
        },
        }),
        prisma.wholesaleItem.findMany({
          where: {
            id: {
              in: parsed.data.items
                .filter((item) => item.isWholesale)
                .map((item) => item.productId),
            },
            isActive: true,
            category: { isActive: true },
          },
          select: { id: true, price: true, stock: true, minimumQuantity: true },
        }),
      ]);
      const productsById = new Map(products.map((product) => [product.id, product]));
      const wholesaleItemsById = new Map(
        wholesaleItems.map((item) => [item.id, item]),
      );
      const itemData = parsed.data.items.map((item) => {
        if (item.isWholesale) {
          const wholesaleItem = wholesaleItemsById.get(item.productId);
          if (!wholesaleItem ||
              item.quantity < wholesaleItem.minimumQuantity ||
              item.quantity > wholesaleItem.stock) {
            throw new CartItemRejectedError(
              'A wholesale item is unavailable or no longer meets its minimum quantity.',
            );
          }
          return {
            productId: null,
            wholesaleItemId: wholesaleItem.id,
            quantity: item.quantity,
            unitPrice: wholesaleItem.price,
            isWholesale: true,
          };
        }
        const product = productsById.get(item.productId);
        if (!product) {
          throw new CartItemRejectedError(
            'One or more products in the basket are no longer available.',
          );
        }
        const weightMatch = /^\s*\d+(?:\.\d+)?\s*(?:kg|g)\s*$/i
          .test(product.unitLabel);
        if (weightMatch !== (item.weightGrams != null)) {
          throw new CartItemRejectedError(
            weightMatch
              ? 'Choose a weight for this product before saving your basket.'
              : 'Weight can only be set for products sold by weight.',
          );
        }
        if (weightMatch && item.weightGrams! >
            Math.max(0, (product.inventory?.totalStock ?? 0) -
              (product.inventory?.reservedStock ?? 0))) {
          throw new CartItemRejectedError(
            'The requested weight exceeds available stock.',
          );
        }
        return {
          productId: product.id,
          wholesaleItemId: null,
          quantity: item.quantity,
          weightGrams: item.weightGrams ?? null,
          unitPrice: product.price,
          isWholesale: false,
        };
      });
      await prisma.$transaction(async (transaction) => {
        const cart = await transaction.cart.upsert({
          where: { userId },
          create: { userId },
          update: {},
          select: { id: true },
        });
        await transaction.cartItem.deleteMany({ where: { cartId: cart.id } });
        if (itemData.length > 0) {
          await transaction.cartItem.createMany({
            data: itemData.map((item) => ({ ...item, cartId: cart.id })),
          });
        }
      });
      return res.sendStatus(204);
    } catch (error) {
      if (error instanceof CartItemRejectedError) {
        return res.status(409).json({ error: error.message });
      }
      console.error('Account cart save failed:', error);
      return res.status(500).json({ error: 'Unable to save your basket.' });
    }
  });

  router.get('/wishlist', async (_req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    try {
      const wishlist = await prisma.wishlist.findUnique({
        where: { userId },
        include: {
          items: {
            where: {
              product: { is: CUSTOMER_CATALOG_PRODUCT_FILTER },
            },
            select: { productId: true },
          },
        },
      });
      return res.json({
        productIds: wishlist?.items.map((item) => item.productId) ?? [],
      });
    } catch (error) {
      console.error('Account wishlist load failed:', error);
      return res.status(500).json({ error: 'Unable to load your saved items.' });
    }
  });

  router.put('/wishlist', async (req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    const parsed = wishlistInput.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Check the products in your saved items.' });
    }
    try {
      const products = await prisma.product.findMany({
        where: {
          id: { in: parsed.data.productIds },
          ...CUSTOMER_CATALOG_PRODUCT_FILTER,
        },
        select: { id: true },
      });
      if (products.length !== parsed.data.productIds.length) {
        return res.status(409).json({
          error: 'One or more saved products are no longer available.',
        });
      }
      await prisma.$transaction(async (transaction) => {
        const wishlist = await transaction.wishlist.upsert({
          where: { userId },
          create: { userId },
          update: {},
          select: { id: true },
        });
        await transaction.wishlistItem.deleteMany({
          where: { wishlistId: wishlist.id },
        });
        if (parsed.data.productIds.length > 0) {
          await transaction.wishlistItem.createMany({
            data: parsed.data.productIds.map((productId) => ({
              wishlistId: wishlist.id,
              productId,
            })),
          });
        }
      });
      return res.sendStatus(204);
    } catch (error) {
      console.error('Account wishlist save failed:', error);
      return res.status(500).json({ error: 'Unable to save your saved items.' });
    }
  });

  router.post('/delivery-quote', async (req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    const parsed = z.object({
      addressId: z.string().trim().min(1).max(100),
    }).strict().safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Choose a valid delivery address.' });
    }
    try {
      const address = await prisma.address.findFirst({
        where: { id: parsed.data.addressId, userId },
        select: { id: true },
      });
      if (!address) {
        return res.status(404).json({ error: 'Delivery address not found.' });
      }
      return res.json({ deliveryFee: DEFAULT_DELIVERY_FEE });
    } catch (error) {
      if (error instanceof DeliveryPricingError) {
        return res.status(error.statusCode).json({ error: error.message });
      }
      console.error('Delivery quote failed:', error);
      return res.status(500).json({ error: 'Unable to calculate the delivery fee.' });
    }
  });

  router.get('/orders/:id/delivery-route', async (req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    if (!req.params.id || req.params.id.length > 100) {
      return res.status(400).json({ error: 'A valid order is required.' });
    }

    try {
      const order = await prisma.order.findFirst({
        where: { id: req.params.id, userId },
        select: {
          address: {
            select: { latitude: true, longitude: true },
          },
          delivery: {
            select: {
              status: true,
              latitude: true,
              longitude: true,
              locationUpdatedAt: true,
            },
          },
        },
      });
      if (!order) return res.status(404).json({ error: 'Order not found.' });
      const riderLocationIsFresh =
        order.delivery?.status === 'OUT_FOR_DELIVERY' &&
        order.delivery.latitude !== null &&
        order.delivery.longitude !== null &&
        order.delivery.locationUpdatedAt !== null &&
        Date.now() - order.delivery.locationUpdatedAt.getTime() <= 120_000;
      const origin = riderLocationIsFresh
        ? {
          latitude: order.delivery!.latitude!,
          longitude: order.delivery!.longitude!,
        }
        : undefined;
      const route = await calculateRoadDeliveryQuote(
        order.address?.latitude ?? null,
        order.address?.longitude ?? null,
        { includePolyline: true, origin },
      );
      if (!route.encodedPolyline) {
        throw new DeliveryPricingError(
          'The road-distance service did not return a route line.',
          502,
        );
      }
      return res.json({
        encodedPolyline: route.encodedPolyline,
        origin: riderLocationIsFresh ? 'rider' : 'store',
      });
    } catch (error) {
      if (error instanceof DeliveryPricingError) {
        return res.status(error.statusCode).json({ error: error.message });
      }
      console.error('Order route load failed:', error);
      return res.status(500).json({ error: 'Unable to load the delivery route.' });
    }
  });

  router.patch('/profile', async (req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    const parsed = updateProfileInput.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Enter a valid name and phone number.' });
    }
    try {
      const currentUser = await prisma.user.findUnique({
        where: { id: userId },
        select: { id: true, phone: true },
      });
      if (!currentUser) return res.status(404).json({ error: 'Account not found.' });
      if (parsed.data.phone !== currentUser.phone) {
        return res.status(503).json({
          error: 'Phone number changes are unavailable until SMS verification is configured.',
        });
      }
      if (await identityAlreadyInUse(prisma, {
        phone: parsed.data.phone,
        excludeUserId: userId,
      })) {
        return res.status(409).json({ error: 'That phone number is already in use.' });
      }
      const user = await prisma.user.update({
        where: { id: userId },
        data: parsed.data,
        select: {
          id: true,
          userNumber: true,
          name: true,
          email: true,
          phone: true,
          role: true,
          avatarUrl: true,
        },
      });
      return res.json({
        data: {
          id: user.id,
          profileId: formatUserDisplayId(user.userNumber),
          fullName: user.name,
          email: user.email,
          phone: user.phone,
          role: user.role,
          avatarUrl: user.avatarUrl,
        },
      });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError &&
          error.code === 'P2002') {
        return res.status(409).json({ error: 'That phone number is already in use.' });
      }
      console.error('Profile update failed:', error);
      return res.status(500).json({ error: 'Unable to update your profile.' });
    }
  });

  router.post('/delete-account', async (req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) {
      return res.status(401).json({ error: 'Authentication is required.' });
    }
    const parsed = deleteAccountInput.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: 'Enter your password to delete your account.' });
    }

    try {
      const currentUser = await prisma.user.findUnique({
        where: { id: userId },
        select: {
          id: true,
          email: true,
          passwordHash: true,
          role: true,
          isActive: true,
        },
      });
      if (!currentUser || !currentUser.isActive) {
        return res.status(401).json({ error: 'Your account is no longer available.' });
      }
      if (currentUser.role !== 'CUSTOMER') {
        return res.status(403).json({ error: 'Only customer accounts can be deleted here.' });
      }
      if (!(await bcrypt.compare(parsed.data.password, currentUser.passwordHash))) {
        return res.status(401).json({ error: 'The password is incorrect.' });
      }

      const anonymizedEmail = `deleted-${randomUUID()}@accounts.invalid`;
      const replacementPasswordHash = await bcrypt.hash(
        randomBytes(32).toString('hex'),
        12,
      );
      const result = await prisma.$transaction(async (transaction) => {
        const deactivated = await transaction.user.updateMany({
          where: { id: userId, isActive: true, role: 'CUSTOMER' },
          data: {
            isActive: false,
            tokenVersion: { increment: 1 },
            name: 'Deleted customer',
            email: anonymizedEmail,
            phone: null,
            avatarUrl: null,
            avatarData: null,
            avatarMimeType: null,
            passwordHash: replacementPasswordHash,
          },
        });
        if (deactivated.count !== 1) return 'unavailable' as const;

        const activeOrderCount = await transaction.order.count({
          where: {
            userId,
            status: { notIn: ['DELIVERED', 'CANCELLED'] },
          },
        });
        if (activeOrderCount > 0) {
          throw new Error('ACCOUNT_HAS_ACTIVE_ORDERS');
        }

        await transaction.order.updateMany({
          where: { userId },
          data: {
            addressId: null,
            shippingName: 'Deleted customer',
            shippingPhone: 'Removed',
            shippingAddress: 'Removed on account deletion',
            shippingCity: 'Removed',
            shippingDistrict: null,
            shippingProvince: null,
            shippingPostalCode: null,
            notes: null,
          },
        });
        await transaction.payment.updateMany({
          where: { order: { userId } },
          data: {
            transactionId: null,
            gatewayResponse: Prisma.DbNull,
            errorMessage: null,
          },
        });
        await transaction.passwordResetOtp.deleteMany({
          where: { email: currentUser.email },
        });
        await transaction.address.deleteMany({ where: { userId } });
        await transaction.cart.deleteMany({ where: { userId } });
        await transaction.wishlist.deleteMany({ where: { userId } });
        await transaction.review.deleteMany({ where: { userId } });
        await transaction.notification.deleteMany({ where: { userId } });
        await transaction.deviceToken.deleteMany({ where: { userId } });
        return 'deleted' as const;
      });

      if (result === 'unavailable') {
        return res.status(401).json({ error: 'Your account is no longer available.' });
      }
      return res.status(200).json({
        message: 'Your account was deleted and historical orders were anonymized.',
      });
    } catch (error) {
      if (error instanceof Error && error.message === 'ACCOUNT_HAS_ACTIVE_ORDERS') {
        return res.status(409).json({
          error: 'Complete or cancel your active orders before deleting your account.',
        });
      }
      console.error('Account deletion failed:', error);
      return res.status(500).json({ error: 'Unable to delete your account.' });
    }
  });

  router.get('/profile/avatar/:userId', async (req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    if (req.params.userId !== userId) {
      return res.status(403).json({ error: 'You cannot view this profile photo.' });
    }

    try {
      const user = await prisma.user.findUnique({
        where: { id: userId },
        select: { avatarData: true, avatarMimeType: true },
      });
      if (!user?.avatarData || !user.avatarMimeType) {
        return res.status(404).json({ error: 'Profile photo not found.' });
      }
      res.setHeader('Content-Type', user.avatarMimeType);
      res.setHeader('Cache-Control', 'private, max-age=86400');
      return res.send(Buffer.from(user.avatarData));
    } catch (error) {
      console.error('Profile image retrieval failed:', error);
      return res.status(500).json({ error: 'Unable to load your profile photo.' });
    }
  });

  router.post('/profile/avatar', receiveSingleImage, async (req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    if (!req.file) return res.status(400).json({ error: 'Choose an image to upload.' });

    try {
      const avatarMimeType = getImageMimeType(req.file.buffer);
      if (!avatarMimeType) {
        return res.status(400).json({ error: 'Use a valid JPEG, PNG, or WebP image.' });
      }
      const avatarUrl =
        `/account/profile/avatar/${userId}?v=${Date.now()}`;
      const user = await prisma.user.update({
        where: { id: userId },
        data: {
          avatarUrl,
          avatarData: req.file.buffer,
          avatarMimeType,
        },
        select: {
          id: true,
          name: true,
          email: true,
          phone: true,
          role: true,
          avatarUrl: true,
        },
      });
      return res.json({
        data: {
          id: user.id,
          fullName: user.name,
          email: user.email,
          phone: user.phone,
          role: user.role,
          avatarUrl: user.avatarUrl,
        },
      });
    } catch (error) {
      console.error('Profile image upload failed:', error);
      return res.status(500).json({ error: 'Unable to update your profile photo.' });
    }
  });

  router.get('/addresses', async (_req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    try {
      const addresses = await prisma.address.findMany({
        where: { userId },
        orderBy: [{ isDefault: 'desc' }, { createdAt: 'asc' }],
      });
      return res.json({ data: addresses.map(addressResponse) });
    } catch (error) {
      console.error('Address list failed:', error);
      return res.status(500).json({ error: 'Unable to load delivery addresses.' });
    }
  });

  router.post('/addresses', async (req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    const parsed = createAddressInput.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: 'Check the delivery address details.' });

    try {
      const created = await prisma.$transaction(async (transaction) => {
        const count = await transaction.address.count({ where: { userId } });
        const shouldDefault = parsed.data.isDefault === true || count === 0;
        if (shouldDefault) await transaction.address.updateMany({ where: { userId }, data: { isDefault: false } });
        return transaction.address.create({
          data: {
            label: parsed.data.title,
            fullName: parsed.data.fullName,
            phone: parsed.data.phone,
            province: parsed.data.province,
            city: parsed.data.city,
            addressLine1: parsed.data.street,
            addressLine2: parsed.data.landmark ?? null,
            instructions: parsed.data.instructions ?? null,
            latitude: parsed.data.latitude ?? null,
            longitude: parsed.data.longitude ?? null,
            userId,
            isDefault: shouldDefault,
          },
        });
      });
      return res.status(201).json({ data: addressResponse(created) });
    } catch (error) {
      console.error('Address creation failed:', error);
      return res.status(500).json({ error: 'Unable to save this delivery address.' });
    }
  });

  router.patch('/addresses/:id', async (req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    const parsed = updateAddressInput.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: 'Check the delivery address details.' });

    try {
      const updated = await prisma.$transaction(async (transaction) => {
        const existing = await transaction.address.findFirst({
          where: { id: req.params.id, userId },
        });
        if (!existing) return null;
        if (parsed.data.isDefault === true) {
          await transaction.address.updateMany({ where: { userId }, data: { isDefault: false } });
        }
        const result = await transaction.address.updateMany({
          where: { id: existing.id, userId },
          data: addressData(parsed.data),
        });
        if (result.count !== 1) return null;
        return transaction.address.findUnique({ where: { id: existing.id } });
      });
      if (!updated) return res.status(404).json({ error: 'Delivery address not found.' });
      return res.json({ data: addressResponse(updated) });
    } catch (error) {
      console.error('Address update failed:', error);
      return res.status(500).json({ error: 'Unable to update this delivery address.' });
    }
  });

  router.delete('/addresses/:id', async (req, res) => {
    const userId = authenticatedUserId(res);
    if (!userId) return res.status(401).json({ error: 'Authentication is required.' });
    try {
      const wasDefault = await prisma.$transaction(async (transaction) => {
        const existing = await transaction.address.findFirst({
          where: { id: req.params.id, userId },
        });
        if (!existing) return null;
        const deleted = await transaction.address.deleteMany({
          where: { id: existing.id, userId },
        });
        if (deleted.count !== 1) return null;
        if (existing.isDefault) {
          const nextDefault = await transaction.address.findFirst({
            where: { userId },
            orderBy: { createdAt: 'asc' },
          });
          if (nextDefault) {
            await transaction.address.update({
              where: { id: nextDefault.id },
              data: { isDefault: true },
            });
          }
        }
        return true;
      });
      if (wasDefault === null) return res.status(404).json({ error: 'Delivery address not found.' });
      return res.sendStatus(204);
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError) {
        console.error('Address deletion failed:', error);
        return res.status(500).json({ error: 'Unable to remove this delivery address.' });
      }
      console.error('Address deletion failed:', error);
      return res.status(500).json({ error: 'Unable to remove this delivery address.' });
    }
  });

  return router;
}
