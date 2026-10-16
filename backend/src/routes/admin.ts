import { Router, type Request, type RequestHandler, type Response } from 'express';
import { Prisma, type PrismaClient } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { sendAdminError } from '../middleware/auth.js';
import { InventoryAdjustmentError, InventoryService } from '../services/inventory.js';
import {
  getImageMimeType,
  receiveSingleImage,
} from '../services/image-upload.js';
import {
  validateProductSalePrice,
  validateProductUnit,
} from '../services/product-validation.js';
import { sendPushToUser } from '../services/push-notifications.js';
import { identityAlreadyInUse, normalizeEmail, normalizePhone } from '../services/user-identity.js';
import {
  DEFAULT_WEEKLY_HOURS,
  getStoreAvailability,
  storeHoursSchema,
} from '../services/store-hours.js';
import {
  clearAllOrderItemDetails,
  clearOrderItemsInput,
} from '../services/order-maintenance.js';

const categoryInput = z.object({
  name: z.string().trim().min(1).max(120).optional(),
  slug: z.string().trim().min(1).max(140)
    .regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/, 'Slug must be lowercase words separated by hyphens')
    .optional(),
  description: z.string().trim().max(2000).nullable().optional(),
  imageUrl: z.string().trim().max(2048).nullable().optional(),
  isActive: z.boolean().optional(),
}).strict();
const createCategoryInput = z.object({
  name: z.string().trim().min(1).max(120),
  slug: z.string().trim().min(1).max(140)
    .regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/, 'Slug must be lowercase words separated by hyphens'),
  description: z.string().trim().max(2000).nullable().optional(),
  imageUrl: z.string().trim().max(2048).nullable().optional(),
}).strict();

const productFields = {
  sku: z.string().trim().min(1).max(80),
  name: z.string().trim().min(1).max(160),
  slug: z.string().trim().min(1).max(180)
    .regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/, 'Slug must be lowercase words separated by hyphens'),
  categoryId: z.string().trim().min(1).max(100),
  brand: z.string().trim().max(120).nullable(),
  price: z.number().finite().nonnegative(),
  originalPrice: z.number().finite().nonnegative().nullable(),
  lowStockThreshold: z.number().int().min(1).max(100000),
  rating: z.number().finite().min(0).max(5),
  reviewCount: z.number().int().nonnegative(),
  description: z.string().trim().max(5000).nullable(),
  origin: z.string().trim().max(200).nullable(),
  imageUrl: z.string().trim().max(2048).nullable(),
  unitLabel: z.string().trim().min(1).max(40),
  isOrganic: z.boolean(),
  isFeatured: z.boolean(),
  isBestSeller: z.boolean(),
  isVendingDrink: z.boolean(),
  isActive: z.boolean(),
  stock: z.number().int().nonnegative(),
};

const createProductInput = z.object({
  ...productFields,
}).partial().extend({
  sku: productFields.sku,
  name: productFields.name,
  slug: productFields.slug,
  categoryId: productFields.categoryId,
  price: productFields.price,
}).strict();

const updateProductInput = z.object({
  sku: productFields.sku.optional(),
  name: productFields.name.optional(),
  slug: productFields.slug.optional(),
  categoryId: productFields.categoryId.optional(),
  brand: productFields.brand.optional(),
  price: productFields.price.optional(),
  originalPrice: productFields.originalPrice.optional(),
  lowStockThreshold: productFields.lowStockThreshold.optional(),
  rating: productFields.rating.optional(),
  reviewCount: productFields.reviewCount.optional(),
  description: productFields.description.optional(),
  origin: productFields.origin.optional(),
  imageUrl: productFields.imageUrl.optional(),
  unitLabel: productFields.unitLabel.optional(),
  isOrganic: productFields.isOrganic.optional(),
  isFeatured: productFields.isFeatured.optional(),
  isBestSeller: productFields.isBestSeller.optional(),
  isVendingDrink: productFields.isVendingDrink.optional(),
  isActive: productFields.isActive.optional(),
  stock: productFields.stock.optional(),
}).strict().refine((value) => Object.keys(value).length > 0, 'At least one field is required');

export const productsQuery = z.object({
  search: z.string().trim().max(200).optional(),
  category: z.string().trim().min(1).max(140).optional(),
  categoryId: z.string().trim().min(1).max(100).optional(),
  availability: z.enum(['available', 'unavailable', 'in_stock', 'out_of_stock']).optional(),
  stock: z.enum(['in_stock', 'out_of_stock', 'low_stock', 'restock']).optional(),
  wholesale: z.enum(['true', 'false'])
    .transform((value) => value === 'true')
    .optional(),
  vendingDrink: z.enum(['true', 'false'])
    .transform((value) => value === 'true')
    .optional(),
  sort: z.enum([
    'name_asc', 'name_desc', 'price_asc', 'price_desc', 'newest', 'oldest',
    'stock_asc', 'stock_desc',
  ]).default('newest'),
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(20),
});
const ordersQuery = z.object({
  search: z.string().trim().max(200).optional(),
  status: z.enum([
    'PLACED', 'CONFIRMED', 'PROCESSING', 'OUT_FOR_DELIVERY', 'DELIVERED', 'CANCELLED',
  ]).optional(),
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(20),
});
const customersQuery = z.object({
  search: z.string().trim().max(200).optional(),
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(20),
});
const deliveryPersonInput = z.object({
  name: z.string().trim().min(1).max(120),
  email: z.string().trim().email().max(254),
  phone: z.string().trim().min(7).max(30).optional()
    .transform((phone) => normalizePhone(phone))
    .refine((phone) => phone === undefined || (phone !== null && phone.length >= 7 && phone.length <= 30)),
  password: z.string().min(10).max(200),
}).strict();
const deliveryAssignmentInput = z.object({
  deliveryPersonId: z.string().trim().min(1).max(100),
}).strict();
const orderStatusInput = z.object({
  status: z.enum([
    'PLACED', 'CONFIRMED', 'PROCESSING', 'OUT_FOR_DELIVERY', 'DELIVERED', 'CANCELLED',
  ]),
  note: z.string().trim().max(1000).optional(),
}).strict();
const orderDeliveryTimeInput = z.object({
  scheduledDeliveryAt: z.string().datetime().nullable(),
}).strict();
const couponCreateInput = z.object({
  code: z.string().trim().toUpperCase().min(3).max(40)
    .regex(/^[A-Z0-9][A-Z0-9_-]*$/, 'Use letters, numbers, underscores, or hyphens.'),
  discountType: z.enum(['PERCENTAGE', 'FIXED']),
  discountPercent: z.number().finite().positive().max(100).nullable(),
  discountAmount: z.number().finite().positive().nullable(),
  minOrderAmount: z.number().finite().nonnegative(),
  maxDiscount: z.number().finite().positive().nullable(),
  usageLimit: z.number().int().positive().nullable(),
  expiresAt: z.string().datetime().nullable()
    .transform((value) => value === null ? null : new Date(value)),
}).strict().superRefine((coupon, context) => {
  if (coupon.discountType === 'PERCENTAGE') {
    if (coupon.discountPercent === null || coupon.discountAmount !== null) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['discountPercent'],
        message: 'Percentage coupons need a percentage discount only.',
      });
    }
  } else if (coupon.discountAmount === null || coupon.discountPercent !== null) {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['discountAmount'],
      message: 'Fixed coupons need a fixed amount discount only.',
    });
  }
  if (coupon.discountType === 'FIXED' && coupon.maxDiscount !== null) {
    context.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['maxDiscount'],
      message: 'A maximum discount cap is only used for percentage coupons.',
    });
  }
});
const couponActiveInput = z.object({ isActive: z.boolean() }).strict();
const wholesaleItemFields = {
  sku: z.string().trim().min(1).max(80),
  name: z.string().trim().min(1).max(160),
  slug: z.string().trim().min(1).max(180)
    .regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/, 'Slug must be lowercase words separated by hyphens'),
  categoryId: z.string().trim().min(1).max(100),
  brand: z.string().trim().max(120).nullable(),
  price: z.number().finite().positive(),
  stock: z.number().int().nonnegative().max(1000000),
  minimumQuantity: z.number().int().positive().max(100),
  description: z.string().trim().max(5000).nullable(),
  origin: z.string().trim().max(200).nullable(),
  imageUrl: z.string().trim().max(2048).nullable(),
  unitLabel: z.string().trim().min(1).max(40),
  isActive: z.boolean(),
};
const createWholesaleItemInput = z.object(wholesaleItemFields).partial().extend({
  sku: wholesaleItemFields.sku,
  name: wholesaleItemFields.name,
  slug: wholesaleItemFields.slug,
  categoryId: wholesaleItemFields.categoryId,
  price: wholesaleItemFields.price,
}).strict();
const updateWholesaleItemInput = z.object({
  sku: wholesaleItemFields.sku.optional(),
  name: wholesaleItemFields.name.optional(),
  slug: wholesaleItemFields.slug.optional(),
  categoryId: wholesaleItemFields.categoryId.optional(),
  brand: wholesaleItemFields.brand.optional(),
  price: wholesaleItemFields.price.optional(),
  stock: wholesaleItemFields.stock.optional(),
  minimumQuantity: wholesaleItemFields.minimumQuantity.optional(),
  description: wholesaleItemFields.description.optional(),
  origin: wholesaleItemFields.origin.optional(),
  imageUrl: wholesaleItemFields.imageUrl.optional(),
  unitLabel: wholesaleItemFields.unitLabel.optional(),
  isActive: wholesaleItemFields.isActive.optional(),
}).strict().refine((value) => Object.keys(value).length > 0, 'At least one field is required');
const wholesaleItemsQuery = z.object({
  search: z.string().trim().max(200).optional(),
  categoryId: z.string().trim().min(1).max(100).optional(),
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(20),
}).strict();
const wholesaleItemSelect = {
  id: true,
  sku: true,
  name: true,
  slug: true,
  categoryId: true,
  brand: true,
  price: true,
  stock: true,
  minimumQuantity: true,
  description: true,
  origin: true,
  imageUrl: true,
  imageMimeType: true,
  unitLabel: true,
  isActive: true,
  createdAt: true,
  updatedAt: true,
  category: { select: { id: true, name: true, slug: true } },
} satisfies Prisma.WholesaleItemSelect;

type WholesaleItemRecord = Prisma.WholesaleItemGetPayload<{
  select: typeof wholesaleItemSelect;
}>;

function wholesaleItemResponse(item: WholesaleItemRecord) {
  return {
    ...item,
    price: Number(item.price),
    imageUrl: item.imageMimeType && item.imageUrl
      ? `${item.imageUrl}?v=${item.updatedAt.getTime()}`
      : item.imageUrl,
  };
}

const restockInput = z.object({
  quantity: z.number().int().min(1).max(1000000),
  notes: z.string().trim().max(500).optional(),
}).strict();
const restockHistoryQuery = z.object({
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(25),
});
const recordIdInput = z.string().trim().min(1).max(100);
const productSelect = {
  id: true,
  sku: true,
  name: true,
  slug: true,
  categoryId: true,
  brand: true,
  price: true,
  originalPrice: true,
  isWholesale: true,
  wholesalePrice: true,
  wholesaleMinimumQuantity: true,
  lowStockThreshold: true,
  rating: true,
  reviewCount: true,
  description: true,
  origin: true,
  imageUrl: true,
  imageMimeType: true,
  unitLabel: true,
  isOrganic: true,
  isFeatured: true,
  isBestSeller: true,
  isVendingDrink: true,
  isActive: true,
  createdAt: true,
  updatedAt: true,
  category: { select: { id: true, name: true, slug: true } },
  inventory: { select: { totalStock: true, reservedStock: true } },
} satisfies Prisma.ProductSelect;
type AdminProduct = Prisma.ProductGetPayload<{ select: typeof productSelect }>;

function productResponse(product: AdminProduct) {
  const { inventory, imageMimeType, ...fields } = product;
  return {
    ...fields,
    imageUrl: imageMimeType && product.imageUrl
      ? `${product.imageUrl}?v=${product.updatedAt.getTime()}`
      : product.imageUrl,
    price: Number(product.price),
    originalPrice: product.originalPrice === null ? null : Number(product.originalPrice),
    wholesalePrice: product.wholesalePrice === null
      ? null
      : Number(product.wholesalePrice),
    rating: Number(product.rating),
    stock: Math.max(0, (inventory?.totalStock ?? 0) - (inventory?.reservedStock ?? 0)),
  };
}

function couponResponse(coupon: {
  id: string;
  code: string;
  discountType: 'PERCENTAGE' | 'FIXED';
  discountPercent: Prisma.Decimal | null;
  discountAmount: Prisma.Decimal | null;
  minOrderAmount: Prisma.Decimal;
  maxDiscount: Prisma.Decimal | null;
  usageLimit: number | null;
  usedCount: number;
  isActive: boolean;
  expiresAt: Date | null;
  createdAt: Date;
}) {
  return {
    ...coupon,
    discountPercent: coupon.discountPercent === null
      ? null
      : Number(coupon.discountPercent),
    discountAmount: coupon.discountAmount === null
      ? null
      : Number(coupon.discountAmount),
    minOrderAmount: Number(coupon.minOrderAmount),
    maxDiscount: coupon.maxDiscount === null
      ? null
      : Number(coupon.maxDiscount),
    expiresAt: coupon.expiresAt?.toISOString() ?? null,
    createdAt: coupon.createdAt.toISOString(),
  };
}

function invalidInput(res: Response, error: z.ZodError): void {
  res.status(400).json({
    error: 'Invalid request',
    details: error.issues.map(({ path, message }) => ({ field: path.join('.'), message })),
  });
}

function parseRecordId(value: string, res: Response): string | undefined {
  const parsed = recordIdInput.safeParse(value);
  if (!parsed.success) {
    invalidInput(res, parsed.error);
    return undefined;
  }
  return parsed.data;
}

function handleKnownError(error: unknown, res: Response): boolean {
  if (error instanceof Prisma.PrismaClientKnownRequestError) {
    if (error.code === 'P2002') {
      res.status(409).json({ error: 'A record with one of those unique values already exists' });
      return true;
    }
    if (error.code === 'P2003') {
      res.status(400).json({ error: 'The referenced category does not exist' });
      return true;
    }
    if (error.code === 'P2025') {
      res.status(404).json({ error: 'Record not found' });
      return true;
    }
  }
  return false;
}

async function availableProductIds(
  prisma: PrismaClient,
  stock: 'in_stock' | 'out_of_stock' | 'low_stock' | 'restock',
): Promise<string[]> {
  if (stock === 'in_stock') {
    const rows = await prisma.$queryRaw<Array<{ id: string }>>`
      SELECT p."id"
      FROM "Product" AS p
      INNER JOIN "Inventory" AS i ON i."productId" = p."id"
      WHERE i."totalStock" - i."reservedStock" > 0
    `;
    return rows.map(({ id }) => id);
  }
  if (stock === 'low_stock') {
    const rows = await prisma.$queryRaw<Array<{ id: string }>>`
      SELECT p."id"
      FROM "Product" AS p
      INNER JOIN "Inventory" AS i ON i."productId" = p."id"
      WHERE i."totalStock" - i."reservedStock" > 0
        AND i."totalStock" - i."reservedStock" <= p."lowStockThreshold"
    `;
    return rows.map(({ id }) => id);
  }
  if (stock === 'restock') {
    const rows = await prisma.$queryRaw<Array<{ id: string }>>`
      SELECT p."id"
      FROM "Product" AS p
      LEFT JOIN "Inventory" AS i ON i."productId" = p."id"
      WHERE p."isActive" = true
        AND COALESCE(i."totalStock", 0) - COALESCE(i."reservedStock", 0)
          <= p."lowStockThreshold"
    `;
    return rows.map(({ id }) => id);
  }
  const rows = await prisma.$queryRaw<Array<{ id: string }>>`
    SELECT p."id"
    FROM "Product" AS p
    LEFT JOIN "Inventory" AS i ON i."productId" = p."id"
    WHERE COALESCE(i."totalStock", 0) - COALESCE(i."reservedStock", 0) <= 0
  `;
  return rows.map(({ id }) => id);
}

function productRequestBody(req: Request): Record<string, unknown> | null {
  let body: unknown = req.body;
  if (req.file) {
    const encoded = (req.body as Record<string, unknown> | undefined)?.product;
    if (typeof encoded !== 'string') return null;
    try {
      body = JSON.parse(encoded);
    } catch {
      return null;
    }
  }
  return body !== null && typeof body === 'object' && !Array.isArray(body)
    ? body as Record<string, unknown>
    : null;
}

function wholesaleItemRequestBody(req: Request): Record<string, unknown> | null {
  let body: unknown = req.body;
  if (req.file) {
    const encoded = (req.body as Record<string, unknown> | undefined)?.wholesaleItem;
    if (typeof encoded !== 'string') return null;
    try {
      body = JSON.parse(encoded);
    } catch {
      return null;
    }
  }
  return body !== null && typeof body === 'object' && !Array.isArray(body)
    ? body as Record<string, unknown>
    : null;
}

export function createAdminRouter(
  prisma: PrismaClient,
  authenticateToken: RequestHandler,
  requireAdmin: RequestHandler,
): Router {
  const router = Router();
  const inventoryService = new InventoryService(prisma);
  router.use(authenticateToken, requireAdmin);

  router.get('/store-settings', async (_req, res) => {
    try {
      res.setHeader('Cache-Control', 'no-store');
      const settings = await prisma.storeSetting.findUnique({ where: { id: 'store' } });
      return res.json(getStoreAvailability(
        settings?.isOrderingEnabled ?? true,
        settings?.weeklyHours ?? DEFAULT_WEEKLY_HOURS,
      ));
    } catch (error) {
      console.error('Admin store settings lookup failed:', error);
      return res.status(500).json({ error: 'Unable to load store hours.' });
    }
  });

  router.put('/store-settings', async (req, res) => {
    const input = z.object({
      isOrderingEnabled: z.boolean(),
      weeklyHours: storeHoursSchema,
    }).strict().safeParse(req.body);
    if (!input.success) return invalidInput(res, input.error);

    try {
      const weeklyHours: Prisma.InputJsonArray = input.data.weeklyHours.map(
        ({ day, isOpen, openTime, closeTime }) => ({
          day,
          isOpen,
          openTime,
          closeTime,
        }),
      );
      const settings = await prisma.storeSetting.upsert({
        where: { id: 'store' },
        create: {
          id: 'store',
          isOrderingEnabled: input.data.isOrderingEnabled,
          weeklyHours,
        },
        update: {
          isOrderingEnabled: input.data.isOrderingEnabled,
          weeklyHours,
        },
      });
      return res.json(getStoreAvailability(
        settings.isOrderingEnabled,
        settings.weeklyHours,
      ));
    } catch (error) {
      console.error('Admin store settings update failed:', error);
      return res.status(500).json({ error: 'Unable to save store hours.' });
    }
  });

  router.post('/uploads/images', receiveSingleImage, async (req, res) => {
    if (!req.file) return res.status(400).json({ error: 'Choose an image to upload.' });
    try {
      const mimeType = getImageMimeType(req.file.buffer);
      if (!mimeType) {
        return res.status(400).json({ error: 'Use a valid JPEG, PNG, or WebP image.' });
      }
      const image = await prisma.storedImage.create({
        data: {
          imageData: req.file.buffer,
          mimeType,
        },
        select: { id: true },
      });
      return res.status(201).json({ url: `/api/v1/images/${image.id}` });
    } catch (error) {
      console.error('Admin image upload failed:', error);
      return res.status(500).json({ error: 'Unable to save this product image.' });
    }
  });

  router.get('/coupons', async (_req, res) => {
    try {
      const coupons = await prisma.coupon.findMany({
        orderBy: [{ createdAt: 'desc' }, { code: 'asc' }],
      });
      return res.json({ coupons: coupons.map(couponResponse) });
    } catch (error) {
      sendAdminError(error, res);
    }
  });

  router.post('/coupons', async (req, res) => {
    const parsed = couponCreateInput.safeParse(req.body);
    if (!parsed.success) return invalidInput(res, parsed.error);
    try {
      const coupon = await prisma.coupon.create({
        data: {
          ...parsed.data,
          code: parsed.data.code,
          isActive: true,
        },
      });
      return res.status(201).json({ coupon: couponResponse(coupon) });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError &&
          error.code === 'P2002') {
        return res.status(409).json({ error: 'A coupon with this code already exists.' });
      }
      sendAdminError(error, res);
    }
  });

  router.patch('/coupons/:id/active', async (req, res) => {
    const id = recordIdInput.safeParse(req.params.id);
    const input = couponActiveInput.safeParse(req.body);
    if (!id.success) return res.status(400).json({ error: 'Invalid coupon ID.' });
    if (!input.success) return invalidInput(res, input.error);
    try {
      const updated = await prisma.coupon.updateMany({
        where: { id: id.data },
        data: { isActive: input.data.isActive },
      });
      if (updated.count === 0) {
        return res.status(404).json({ error: 'Coupon not found.' });
      }
      const coupon = await prisma.coupon.findUnique({ where: { id: id.data } });
      if (!coupon) return res.status(404).json({ error: 'Coupon not found.' });
      return res.json({ coupon: couponResponse(coupon) });
    } catch (error) {
      sendAdminError(error, res);
    }
  });

  router.get('/dashboard', async (_req, res) => {
    try {
      const today = new Date();
      today.setUTCHours(0, 0, 0, 0);
      const [
        totalProducts,
        activeProducts,
        stockCounts,
        totalCustomers,
        groupedOrders,
        todaySales,
        allSales,
        recentOrders,
      ] = await Promise.all([
        prisma.product.count(),
        prisma.product.count({ where: { isActive: true } }),
        prisma.$queryRaw<Array<{ outOfStock: bigint; lowStock: bigint }>>`
          SELECT
            COUNT(*) FILTER (
              WHERE COALESCE(i."totalStock", 0) - COALESCE(i."reservedStock", 0) <= 0
            ) AS "outOfStock",
            COUNT(*) FILTER (
              WHERE COALESCE(i."totalStock", 0) - COALESCE(i."reservedStock", 0) > 0
                AND COALESCE(i."totalStock", 0) - COALESCE(i."reservedStock", 0)
                  <= p."lowStockThreshold"
            ) AS "lowStock"
          FROM "Product" AS p
          LEFT JOIN "Inventory" AS i ON i."productId" = p."id"
        `,
        prisma.user.count({ where: { role: 'CUSTOMER' } }),
        prisma.order.groupBy({ by: ['status'], _count: { _all: true } }),
        prisma.order.aggregate({
          where: { createdAt: { gte: today }, status: { not: 'CANCELLED' } },
          _sum: { total: true },
        }),
        prisma.order.aggregate({
          where: { status: { not: 'CANCELLED' } },
          _sum: { total: true },
        }),
        prisma.order.findMany({
          take: 5,
          orderBy: { createdAt: 'desc' },
          select: {
            id: true,
            orderNumber: true,
            status: true,
            total: true,
            createdAt: true,
            user: { select: { id: true, name: true } },
          },
        }),
      ]);

      const orderCounts = Object.fromEntries(
        groupedOrders.map(({ status, _count }) => [status, _count._all]),
      );
      const countStatus = (status: string) => Number(orderCounts[status] ?? 0);
      return res.json({
        products: {
          total: totalProducts,
          active: activeProducts,
          outOfStock: Number(stockCounts[0]?.outOfStock ?? 0),
          lowStock: Number(stockCounts[0]?.lowStock ?? 0),
        },
        customers: { total: totalCustomers },
        orders: {
          total: groupedOrders.reduce((total, row) => total + row._count._all, 0),
          pending: countStatus('PLACED') + countStatus('CONFIRMED'),
          processing: countStatus('PROCESSING'),
          outForDelivery: countStatus('OUT_FOR_DELIVERY'),
          delivered: countStatus('DELIVERED'),
          cancelled: countStatus('CANCELLED'),
        },
        sales: {
          today: Number(todaySales._sum.total ?? 0),
          total: Number(allSales._sum.total ?? 0),
        },
        recentOrders: recentOrders.map((order) => ({
          id: order.id,
          orderNumber: order.orderNumber,
          status: order.status,
          total: Number(order.total),
          createdAt: order.createdAt,
          customer: order.user,
        })),
      });
    } catch (error) {
      sendAdminError(error, res);
    }
  });

  router.get('/orders', async (req, res) => {
    const parsed = ordersQuery.safeParse(req.query);
    if (!parsed.success) return invalidInput(res, parsed.error);
    const { search, status, page, pageSize } = parsed.data;
    const where: Prisma.OrderWhereInput = {
      ...(status ? { status } : {}),
      ...(search
        ? {
          OR: [
            { orderNumber: { contains: search, mode: 'insensitive' } },
            { shippingName: { contains: search, mode: 'insensitive' } },
            { shippingPhone: { contains: search, mode: 'insensitive' } },
            { user: { name: { contains: search, mode: 'insensitive' } } },
          ],
        }
        : {}),
    };

    try {
      const [total, orders] = await Promise.all([
        prisma.order.count({ where }),
        prisma.order.findMany({
          where,
          orderBy: { createdAt: 'desc' },
          skip: (page - 1) * pageSize,
          take: pageSize,
          include: {
            user: { select: { id: true, name: true, email: true, phone: true } },
            items: {
              select: {
                id: true,
                productName: true,
                sku: true,
                quantity: true,
                price: true,
                total: true,
                isWholesale: true,
                product: { select: { imageUrl: true } },
                wholesaleItem: { select: { imageUrl: true } },
              },
            },
            payments: {
              select: {
                id: true,
                method: true,
                status: true,
                transactionId: true,
                amount: true,
                createdAt: true,
              },
            },
            statusHistory: {
              orderBy: { createdAt: 'asc' },
              select: { status: true, note: true, createdAt: true },
            },
            delivery: {
              select: {
                id: true,
                status: true,
                deliveryPersonId: true,
                assignedAt: true,
                cashCollected: true,
                deliveryPerson: {
                  select: { id: true, name: true, phone: true, isActive: true },
                },
                statusHistory: {
                  orderBy: { createdAt: 'desc' },
                  take: 10,
                  select: { status: true, note: true, createdAt: true },
                },
              },
            },
          },
        }),
      ]);
      return res.json({
        orders: orders.map((order) => ({
          id: order.id,
          orderNumber: order.orderNumber,
          status: order.status,
          paymentMethod: order.paymentMethod,
          paymentStatus: order.paymentStatus,
          subtotal: Number(order.subtotal),
          deliveryFee: Number(order.deliveryFee),
          discount: Number(order.discount),
          couponCode: order.couponCode,
          tip: Number(order.tip),
          total: Number(order.total),
          customer: order.user,
          shipping: {
            name: order.shippingName,
            phone: order.shippingPhone,
            address: order.shippingAddress,
            city: order.shippingCity,
            district: order.shippingDistrict,
            province: order.shippingProvince,
            postalCode: order.shippingPostalCode,
            instructions: order.notes,
          },
          items: order.items.map((item) => ({
            id: item.id,
            name: item.productName,
            sku: item.sku,
            quantity: item.quantity,
            price: Number(item.price),
            total: Number(item.total),
            isWholesale: item.isWholesale,
            imageUrl: item.wholesaleItem?.imageUrl ?? item.product?.imageUrl ?? null,
          })),
          payments: order.payments.map((payment) => ({
            ...payment,
            amount: Number(payment.amount),
            createdAt: payment.createdAt.toISOString(),
          })),
          delivery: order.delivery
            ? {
              ...order.delivery,
              cashCollected: Number(order.delivery.cashCollected),
              assignedAt: order.delivery.assignedAt?.toISOString() ?? null,
              statusHistory: order.delivery.statusHistory.map((entry) => ({
                ...entry,
                createdAt: entry.createdAt.toISOString(),
              })),
            }
            : null,
          statusHistory: order.statusHistory.map((entry) => ({
            ...entry,
            createdAt: entry.createdAt.toISOString(),
          })),
          scheduledDeliveryAt: order.scheduledDeliveryAt?.toISOString() ?? null,
          createdAt: order.createdAt.toISOString(),
        })),
        pagination: { page, pageSize, total },
      });

    } catch (error) {
      sendAdminError(error, res);
    }
  });

  router.delete('/orders/items', async (req, res) => {
    const parsed = clearOrderItemsInput.safeParse(req.body);
    if (!parsed.success) return invalidInput(res, parsed.error);
    try {
      const deletedItems = await clearAllOrderItemDetails(
        prisma,
        parsed.data.confirmation,
      );
      return res.json({ deletedItems });
    } catch (error) {
      sendAdminError(error, res);
    }
  });

  router.get('/customers', async (req, res) => {
    const parsed = customersQuery.safeParse(req.query);
    if (!parsed.success) return invalidInput(res, parsed.error);
    const { search, page, pageSize } = parsed.data;
    const where: Prisma.UserWhereInput = {
      role: 'CUSTOMER',
      ...(search
        ? {
          OR: [
            { name: { contains: search, mode: 'insensitive' } },
            { email: { contains: search, mode: 'insensitive' } },
            { phone: { contains: search, mode: 'insensitive' } },
            {
              orders: {
                some: {
                  orderNumber: { contains: search, mode: 'insensitive' },
                },
              },
            },
          ],
        }
        : {}),
    };

    try {
      const [total, customers] = await Promise.all([
        prisma.user.count({ where }),
        prisma.user.findMany({
          where,
          orderBy: { createdAt: 'desc' },
          skip: (page - 1) * pageSize,
          take: pageSize,
          select: {
            id: true,
            name: true,
            email: true,
            phone: true,
            isActive: true,
            createdAt: true,
            _count: { select: { orders: true } },
            addresses: {
              orderBy: [{ isDefault: 'desc' }, { updatedAt: 'desc' }],
              take: 3,
              select: {
                label: true,
                fullName: true,
                phone: true,
                addressLine1: true,
                addressLine2: true,
                city: true,
                district: true,
                province: true,
                latitude: true,
                longitude: true,
                isDefault: true,
              },
            },
            orders: {
              orderBy: { createdAt: 'desc' },
              take: 5,
              select: {
                orderNumber: true,
                status: true,
                paymentStatus: true,
                couponCode: true,
                total: true,
                createdAt: true,
              },
            },
          },
        }),
      ]);
      const customerIds = customers.map(({ id }) => id);
      const orderTotals = customerIds.length > 0
        ? await prisma.order.groupBy({
          by: ['userId'],
          where: { userId: { in: customerIds }, status: { not: 'CANCELLED' } },
          _sum: { total: true },
        })
        : [];
      const totalsByCustomer = new Map(
        orderTotals.map((row) => [row.userId, Number(row._sum.total ?? 0)]),
      );

      return res.json({
        customers: customers.map((customer) => ({
          id: customer.id,
          name: customer.name,
          email: customer.email,
          phone: customer.phone,
          isActive: customer.isActive,
          createdAt: customer.createdAt.toISOString(),
          orderCount: customer._count.orders,
          orderValue: totalsByCustomer.get(customer.id) ?? 0,
          addresses: customer.addresses,
          recentOrders: customer.orders.map((order) => ({
            ...order,
            total: Number(order.total),
            createdAt: order.createdAt.toISOString(),
          })),
        })),
        pagination: { page, pageSize, total },
      });
    } catch (error) {
      sendAdminError(error, res);
    }
  });

  router.get('/delivery/people', async (_req, res) => {
    try {
      const people = await prisma.user.findMany({
        where: { role: 'DELIVERY_PERSON' },
        orderBy: [{ isActive: 'desc' }, { name: 'asc' }],
        select: {
          id: true,
          name: true,
          email: true,
          phone: true,
          isActive: true,
          isAvailable: true,
          _count: {
            select: {
              deliveries: {
                where: {
                  status: { in: ['ASSIGNED', 'ACCEPTED', 'PICKED_UP', 'OUT_FOR_DELIVERY'] },
                },
              },
            },
          },
        },
      });
      return res.json({
        deliveryPeople: people.map(({ _count, ...person }) => ({
          ...person,
          activeDeliveries: _count.deliveries,
        })),
      });
    } catch (error) {
      sendAdminError(error, res);
    }
  });

  router.get('/delivery/cash-pending', async (_req, res) => {
    try {
      const deliveries = await prisma.delivery.findMany({
        where: {
          status: 'DELIVERED',
          cashCollected: { gt: 0 },
          cashHandedOverAt: null,
        },
        orderBy: { deliveredAt: 'asc' },
        select: {
          id: true,
          cashCollected: true,
          deliveredAt: true,
          deliveryPerson: { select: { id: true, name: true } },
          order: { select: { orderNumber: true } },
        },
      });
      return res.json({
        deliveries: deliveries.map((delivery) => ({
          id: delivery.id,
          orderNumber: delivery.order.orderNumber,
          deliveryPersonName: delivery.deliveryPerson?.name ?? 'Former staff member',
          cashCollected: Number(delivery.cashCollected),
          deliveredAt: delivery.deliveredAt?.toISOString() ?? null,
        })),
      });
    } catch (error) {
      sendAdminError(error, res);
    }
  });

  router.patch('/delivery/:id/cash-handover', async (req, res) => {
    const id = parseRecordId(req.params.id, res);
    if (!id) return;
    const adminId = res.locals.authenticatedUserId as string;
    try {
      const result = await prisma.$transaction(async (tx) => {
        const delivery = await tx.delivery.findUnique({
          where: { id },
          select: {
            id: true,
            status: true,
            cashCollected: true,
            cashHandedOverAt: true,
            order: { select: { orderNumber: true } },
          },
        });
        if (!delivery) return { kind: 'missing' as const };
        if (
          delivery.status !== 'DELIVERED' ||
          Number(delivery.cashCollected) <= 0
        ) {
          return { kind: 'not-eligible' as const };
        }
        if (delivery.cashHandedOverAt) return { kind: 'already-received' as const };

        const receivedAt = new Date();
        const updated = await tx.delivery.updateMany({
          where: {
            id,
            status: 'DELIVERED',
            cashHandedOverAt: null,
          },
          data: {
            cashHandedOver: delivery.cashCollected,
            cashHandedOverAt: receivedAt,
          },
        });
        if (updated.count !== 1) return { kind: 'already-received' as const };

        await tx.deliveryStatusHistory.create({
          data: {
            deliveryId: id,
            changedById: adminId,
            status: 'DELIVERED',
            note: `Store confirmed receipt of Rs. ${Number(delivery.cashCollected).toFixed(2)} customer COD for order ${delivery.order.orderNumber}.`,
          },
        });
        return {
          kind: 'received' as const,
          amount: Number(delivery.cashCollected),
          receivedAt,
        };
      });

      if (result.kind === 'missing') {
        return res.status(404).json({ error: 'Delivery record not found.' });
      }
      if (result.kind === 'not-eligible') {
        return res.status(409).json({ error: 'This delivery has no COD cash to hand over.' });
      }
      if (result.kind === 'already-received') {
        return res.status(409).json({ error: 'This COD cash has already been recorded as received.' });
      }
      return res.json({
        message: 'Customer COD receipt recorded.',
        cashHandedOver: result.amount,
        cashHandedOverAt: result.receivedAt.toISOString(),
      });
    } catch (error) {
      sendAdminError(error, res);
    }
  });

  router.post('/delivery/people', async (req, res) => {
    const parsed = deliveryPersonInput.safeParse(req.body);
    if (!parsed.success) return invalidInput(res, parsed.error);
    try {
      const email = normalizeEmail(parsed.data.email);
      const phone = normalizePhone(parsed.data.phone);
      if (await identityAlreadyInUse(prisma, { email, phone })) {
        return res.status(409).json({ error: 'An account with this email or phone already exists.' });
      }
      const person = await prisma.user.create({
        data: {
          name: parsed.data.name,
          email,
          phone,
          passwordHash: await bcrypt.hash(parsed.data.password, 12),
          role: 'DELIVERY_PERSON',
          isAvailable: false,
        },
        select: { id: true, name: true, email: true, phone: true, isActive: true, isAvailable: true },
      });
      return res.status(201).json({ deliveryPerson: person });
    } catch (error) {
      if (handleKnownError(error, res)) return;
      sendAdminError(error, res);
    }
  });

  router.patch('/delivery/people/:id/active', async (req, res) => {
    const id = parseRecordId(req.params.id, res);
    if (!id) return;
    const parsed = z.object({ isActive: z.boolean() }).strict().safeParse(req.body);
    if (!parsed.success) return invalidInput(res, parsed.error);
    try {
      const person = await prisma.user.findFirst({
        where: { id, role: 'DELIVERY_PERSON' },
        select: { id: true },
      });
      if (!person) return res.status(404).json({ error: 'Delivery staff account not found.' });
      if (!parsed.data.isActive) {
        const activeDeliveries = await prisma.delivery.count({
          where: {
            deliveryPersonId: id,
            status: { in: ['ACCEPTED', 'PICKED_UP', 'OUT_FOR_DELIVERY'] },
          },
        });
        if (activeDeliveries > 0) {
          return res.status(409).json({
            error: 'Reassign or finish active deliveries before deactivating this account.',
          });
        }
      }
      const updated = await prisma.user.update({
        where: { id },
        data: {
          isActive: parsed.data.isActive,
          ...(!parsed.data.isActive ? { isAvailable: false } : {}),
        },
        select: { id: true, isActive: true, isAvailable: true },
      });
      return res.json({ deliveryPerson: updated });
    } catch (error) {
      sendAdminError(error, res);
    }
  });

  router.patch('/orders/:id/delivery-person', async (req, res) => {
    const id = parseRecordId(req.params.id, res);
    if (!id) return;
    const parsed = deliveryAssignmentInput.safeParse(req.body);
    if (!parsed.success) return invalidInput(res, parsed.error);
    const adminId = res.locals.authenticatedUserId as string;
    const { deliveryPersonId } = parsed.data;

    try {
      const result = await prisma.$transaction(async (tx) => {
        const [order, person] = await Promise.all([
          tx.order.findUnique({
            where: { id },
            select: { id: true, orderNumber: true, status: true, userId: true },
          }),
          tx.user.findFirst({
            where: { id: deliveryPersonId, role: 'DELIVERY_PERSON', isActive: true, isAvailable: true },
            select: { id: true, name: true },
          }),
        ]);
        if (!order) return { kind: 'order-missing' as const };
        if (!person) return { kind: 'person-unavailable' as const };
        if (!['PROCESSING', 'OUT_FOR_DELIVERY'].includes(order.status)) {
          return { kind: 'order-not-ready' as const };
        }

        const current = await tx.delivery.findUnique({
          where: { orderId: id },
          select: { id: true, status: true, deliveryPersonId: true },
        });
        if (current?.deliveryPersonId === deliveryPersonId &&
            current.status !== 'DECLINED' && current.status !== 'FAILED') {
          return {
            kind: 'assigned' as const,
            deliveryId: current.id,
            personId: person.id,
            personName: person.name,
            previousPersonId: null,
            orderNumber: order.orderNumber,
            orderId: order.id,
          };
        }
        if (current && ['ACCEPTED', 'PICKED_UP', 'OUT_FOR_DELIVERY'].includes(current.status)) {
          return { kind: 'active-assignment' as const };
        }

        const delivery = await tx.delivery.upsert({
          where: { orderId: id },
          create: {
            orderId: id,
            deliveryPersonId,
            status: 'ASSIGNED',
            assignedAt: new Date(),
          },
          update: {
            deliveryPersonId,
            status: 'ASSIGNED',
            assignedAt: new Date(),
            pickedUpAt: null,
            deliveredAt: null,
            cashCollected: 0,
            cashCollectedAt: null,
          },
          select: { id: true },
        });
        await tx.deliveryStatusHistory.create({
          data: {
            deliveryId: delivery.id,
            changedById: adminId,
            status: 'ASSIGNED',
            note: current
              ? `Reassigned by store admin to ${person.name}.`
              : `Assigned by store admin to ${person.name}.`,
          },
        });
        return {
          kind: 'assigned' as const,
          deliveryId: delivery.id,
          personId: person.id,
          personName: person.name,
          previousPersonId: current?.deliveryPersonId ?? null,
          orderNumber: order.orderNumber,
          orderId: order.id,
        };
      });

      if (result.kind === 'order-missing') return res.status(404).json({ error: 'Order not found.' });
      if (result.kind === 'person-unavailable') {
        return res.status(409).json({ error: 'Choose an active delivery person who is on duty.' });
      }
      if (result.kind === 'order-not-ready') {
        return res.status(409).json({ error: 'Only orders being prepared or out for delivery can be assigned.' });
      }
      if (result.kind === 'active-assignment') {
        return res.status(409).json({ error: 'This delivery is in progress. Contact the assigned rider before reassignment.' });
      }
      if (result.previousPersonId && result.previousPersonId !== result.personId) {
        await prisma.notification.create({
          data: {
            userId: result.previousPersonId,
            type: 'DELIVERY_UPDATED',
            title: 'Delivery reassigned',
            body: `Order ${result.orderNumber} is no longer assigned to you.`,
            metadata: { deliveryId: result.deliveryId },
          },
        }).then(() => sendPushToUser(
          prisma,
          result.previousPersonId!,
          'Delivery reassigned',
          `Order ${result.orderNumber} is no longer assigned to you.`,
          { deliveryId: result.deliveryId },
        )).catch((error: unknown) => {
          console.error(`Unable to notify previous delivery staff about ${result.orderId}:`, error);
        });
      }
      await prisma.notification.create({
        data: {
          userId: result.personId,
          type: 'DELIVERY_ASSIGNED',
          title: 'New delivery assigned',
          body: `Order ${result.orderNumber} is ready for you to review.`,
          metadata: { deliveryId: result.deliveryId },
        },
      }).then(() => sendPushToUser(
        prisma,
        result.personId,
        'New delivery assigned',
        `Order ${result.orderNumber} is ready for you to review.`,
        { deliveryId: result.deliveryId, orderId: result.orderId },
      )).catch((error: unknown) => {
          console.error(`Unable to notify delivery staff about ${result.orderId}:`, error);
        });
      return res.json({ message: `Assigned to ${result.personName}.` });
    } catch (error) {
      sendAdminError(error, res);
    }
  });

  router.patch('/orders/:id/status', async (req, res) => {
    const id = parseRecordId(req.params.id, res);
    if (!id) return;
    const parsed = orderStatusInput.safeParse(req.body);
    if (!parsed.success) return invalidInput(res, parsed.error);
    const { status, note } = parsed.data;
    const transitions: Record<string, string[]> = {
      PLACED: ['CONFIRMED', 'CANCELLED'],
      CONFIRMED: ['PROCESSING', 'CANCELLED'],
      PROCESSING: ['OUT_FOR_DELIVERY', 'CANCELLED'],
      OUT_FOR_DELIVERY: ['DELIVERED'],
      DELIVERED: [],
      CANCELLED: [],
    };
    const adminId = res.locals.authenticatedUserId as string;

    try {
      const result = await prisma.$transaction(async (tx) => {
        const existing = await tx.order.findUnique({
          where: { id },
          select: {
            id: true,
            status: true,
            paymentStatus: true,
            couponCode: true,
            items: true,
            userId: true,
            orderNumber: true,
            delivery: { select: { id: true, status: true, deliveryPersonId: true } },
          },
        });
        if (!existing) return { kind: 'missing' as const };
        if (existing.delivery && status !== 'CANCELLED') {
          return { kind: 'delivery-managed' as const };
        }
        if (
          status === 'CANCELLED' &&
          existing.delivery &&
          ['ACCEPTED', 'PICKED_UP', 'OUT_FOR_DELIVERY'].includes(existing.delivery.status)
        ) {
          return { kind: 'active-delivery' as const };
        }
        if (!transitions[existing.status]?.includes(status)) {
          return { kind: 'invalid-transition' as const };
        }

        const changed = await tx.order.updateMany({
          where: { id, status: existing.status },
          data: {
            status,
            ...(status === 'CANCELLED' && existing.paymentStatus === 'PENDING'
              ? { paymentStatus: 'CANCELLED' as const }
              : {}),
          },
        });
        if (changed.count !== 1) return { kind: 'conflict' as const };

        if (status === 'CANCELLED') {
          if (existing.couponCode) {
            await tx.coupon.updateMany({
              where: { code: existing.couponCode, usedCount: { gt: 0 } },
              data: { usedCount: { decrement: 1 } },
            });
          }
          if (existing.delivery) {
            const deliveryChanged = await tx.delivery.updateMany({
              where: { id: existing.delivery.id, status: existing.delivery.status },
              data: { status: 'CANCELLED' },
            });
            if (deliveryChanged.count !== 1) return { kind: 'conflict' as const };
            await tx.deliveryStatusHistory.create({
              data: {
                deliveryId: existing.delivery.id,
                changedById: adminId,
                status: 'CANCELLED',
                note: `Order ${existing.orderNumber} cancelled by store admin before pickup.`,
              },
            });
          }
          const retailItems = existing.items.flatMap(({ productId, quantity }) =>
            productId ? [{ productId, quantity }] : [],
          );
          if (retailItems.length > 0) {
            await inventoryService.adjustInventory(
              tx,
              retailItems,
              `order:${existing.id}`,
              `Inventory restored after order cancellation by admin ${adminId}.`,
            );
          }
          for (const item of existing.items) {
            if (!item.productId && item.wholesaleItemId) {
              await tx.wholesaleItem.update({
                where: { id: item.wholesaleItemId },
                data: { stock: { increment: item.quantity } },
              });
            }
          }
        }

        await tx.orderStatusHistory.create({
          data: {
            orderId: id,
            status,
            note: note ?? `Order status changed to ${status} by admin ${adminId}.`,
          },
        });
        return {
          kind: 'updated' as const,
          userId: existing.userId,
          orderNumber: existing.orderNumber,
          deliveryPersonId: existing.delivery?.deliveryPersonId ?? null,
        };
      });

      if (result.kind === 'missing') return res.status(404).json({ error: 'Order not found.' });
      if (result.kind === 'invalid-transition') {
        return res.status(409).json({ error: 'That order status transition is not allowed.' });
      }
      if (result.kind === 'delivery-managed') {
        return res.status(409).json({
          error: 'The assigned delivery staff must update pickup and delivery status from their panel.',
        });
      }
      if (result.kind === 'active-delivery') {
        return res.status(409).json({
          error: 'This package is with delivery staff. Contact the rider before cancelling.',
        });
      }
      if (result.kind === 'conflict') {
        return res.status(409).json({ error: 'The order changed. Refresh and try again.' });
      }

      if (result.deliveryPersonId) {
        await prisma.notification.create({
          data: {
            userId: result.deliveryPersonId,
            type: 'DELIVERY_UPDATED',
            title: 'Delivery cancelled',
            body: `Order ${result.orderNumber} was cancelled by the store.`,
            metadata: { orderId: id },
          },
        }).catch((error: unknown) => {
          console.error(`Unable to notify delivery staff about cancelled order ${id}:`, error);
        });
      }

      const notificationTypes = {
        CONFIRMED: 'ORDER_CONFIRMED',
        PROCESSING: 'ORDER_PROCESSING',
        OUT_FOR_DELIVERY: 'ORDER_OUT_FOR_DELIVERY',
        DELIVERED: 'ORDER_DELIVERED',
        CANCELLED: 'ORDER_CANCELLED',
      } as const;
      const notificationType = notificationTypes[status as keyof typeof notificationTypes];
      if (notificationType) {
        await prisma.notification.create({
          data: {
            userId: result.userId,
            type: notificationType,
            title: `Order ${status.replaceAll('_', ' ').toLowerCase()}`,
            body: `Order ${result.orderNumber} is now ${status.replaceAll('_', ' ').toLowerCase()}.`,
            metadata: { orderId: id },
          },
        }).catch((error: unknown) => {
          console.error(`Unable to notify customer about order ${id}:`, error);
        });
      }

      return res.json({ message: 'Order status updated.', id, status });
    } catch (error) {
      sendAdminError(error, res);
    }
  });

  router.patch('/orders/:id/delivery-time', async (req, res) => {
    const id = parseRecordId(req.params.id, res);
    if (!id) return;
    const parsed = orderDeliveryTimeInput.safeParse(req.body);
    if (!parsed.success) return invalidInput(res, parsed.error);
    const scheduledDeliveryAt = parsed.data.scheduledDeliveryAt === null
      ? null
      : new Date(parsed.data.scheduledDeliveryAt);
    if (scheduledDeliveryAt !== null && scheduledDeliveryAt <= new Date()) {
      return res.status(400).json({
        error: 'Choose a delivery time in the future.',
      });
    }

    try {
      const result = await prisma.$transaction(async (tx) => {
        const order = await tx.order.findUnique({
          where: { id },
          select: { status: true },
        });
        if (!order) return { kind: 'missing' as const };
        if (order.status === 'DELIVERED' || order.status === 'CANCELLED') {
          return { kind: 'closed' as const };
        }
        const updated = await tx.order.updateMany({
          where: { id, status: order.status },
          data: { scheduledDeliveryAt },
        });
        return updated.count === 1
          ? { kind: 'updated' as const }
          : { kind: 'conflict' as const };
      });
      if (result.kind === 'missing') {
        return res.status(404).json({ error: 'Order not found.' });
      }
      if (result.kind === 'closed') {
        return res.status(409).json({
          error: 'Delivery time cannot be changed for a closed order.',
        });
      }
      if (result.kind === 'conflict') {
        return res.status(409).json({
          error: 'The order changed. Refresh and try again.',
        });
      }
      return res.json({
        message: 'Delivery time updated.',
        id,
        scheduledDeliveryAt: scheduledDeliveryAt?.toISOString() ?? null,
      });
    } catch (error) {
      sendAdminError(error, res);
    }
  });

  router.get('/categories', async (_req, res) => {
    try {
      const categories = await prisma.category.findMany({
        orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
        include: { _count: { select: { products: true } } },
      });
      return res.json({ categories });
    } catch (error) {
      sendAdminError(error, res);
    }
  });

  router.post('/categories', async (req, res) => {
    const parsed = createCategoryInput.safeParse(req.body);
    if (!parsed.success) return invalidInput(res, parsed.error);

    try {
      const category = await prisma.category.create({
        data: parsed.data,
        include: { _count: { select: { products: true } } },
      });
      return res.status(201).json({ category });
    } catch (error) {
      if (handleKnownError(error, res)) return;
      sendAdminError(error, res);
    }
  });

  router.patch('/categories/:id', async (req, res) => {
    const id = parseRecordId(req.params.id, res);
    if (!id) return;
    const parsed = categoryInput.safeParse(req.body);
    if (!parsed.success) return invalidInput(res, parsed.error);
    if (Object.keys(parsed.data).length === 0) {
      return res.status(400).json({ error: 'At least one field is required' });
    }

    try {
      const category = await prisma.category.update({
        where: { id },
        data: parsed.data,
        include: { _count: { select: { products: true } } },
      });
      return res.json({ category });
    } catch (error) {
      if (handleKnownError(error, res)) return;
      sendAdminError(error, res);
    }
  });

  router.delete('/categories/:id', async (req, res) => {
    const id = parseRecordId(req.params.id, res);
    if (!id) return;
    try {
      const category = await prisma.category.update({
        where: { id },
        data: { isActive: false },
        select: { id: true, name: true, slug: true, isActive: true },
      });
      return res.json({ category });
    } catch (error) {
      if (handleKnownError(error, res)) return;
      sendAdminError(error, res);
    }
  });

  router.get('/wholesale-items', async (req, res) => {
    const parsed = wholesaleItemsQuery.safeParse(req.query);
    if (!parsed.success) return invalidInput(res, parsed.error);
    const { search, categoryId, page, pageSize } = parsed.data;
    const where: Prisma.WholesaleItemWhereInput = {
      ...(categoryId ? { categoryId } : {}),
      ...(search
        ? {
          OR: [
            { name: { contains: search, mode: 'insensitive' } },
            { sku: { contains: search, mode: 'insensitive' } },
            { brand: { contains: search, mode: 'insensitive' } },
          ],
        }
        : {}),
    };
    try {
      const [total, items] = await Promise.all([
        prisma.wholesaleItem.count({ where }),
        prisma.wholesaleItem.findMany({
          where,
          orderBy: [{ updatedAt: 'desc' }, { name: 'asc' }],
          skip: (page - 1) * pageSize,
          take: pageSize,
          select: wholesaleItemSelect,
        }),
      ]);
      return res.json({
        wholesaleItems: items.map(wholesaleItemResponse),
        pagination: { page, pageSize, total },
      });
    } catch (error) {
      sendAdminError(error, res);
    }
  });

  router.post('/wholesale-items', receiveSingleImage, async (req, res) => {
    const body = wholesaleItemRequestBody(req);
    if (!body) return res.status(400).json({ error: 'Wholesale item fields are required.' });
    const parsed = createWholesaleItemInput.safeParse(body);
    if (!parsed.success) return invalidInput(res, parsed.error);
    const imageMimeType = req.file ? getImageMimeType(req.file.buffer) : null;
    if (req.file && !imageMimeType) {
      return res.status(400).json({ error: 'Use a valid JPEG, PNG, or WebP image.' });
    }
    try {
      const id = randomUUID();
      const item = await prisma.wholesaleItem.create({
        data: {
          id,
          ...parsed.data,
          ...(req.file && imageMimeType
            ? {
                imageData: req.file.buffer,
                imageMimeType,
                imageUrl: `/api/v1/wholesale/${id}/image`,
              }
            : {}),
        },
        select: wholesaleItemSelect,
      });
      return res.status(201).json({ wholesaleItem: wholesaleItemResponse(item) });
    } catch (error) {
      if (handleKnownError(error, res)) return;
      sendAdminError(error, res);
    }
  });

  router.patch('/wholesale-items/:id', receiveSingleImage, async (req, res) => {
    const id = parseRecordId(req.params.id, res);
    if (!id) return;
    const body = wholesaleItemRequestBody(req);
    if (!body) return res.status(400).json({ error: 'Wholesale item fields are required.' });
    const parsed = updateWholesaleItemInput.safeParse(body);
    if (!parsed.success) return invalidInput(res, parsed.error);
    const imageMimeType = req.file ? getImageMimeType(req.file.buffer) : null;
    if (req.file && !imageMimeType) {
      return res.status(400).json({ error: 'Use a valid JPEG, PNG, or WebP image.' });
    }
    try {
      const item = await prisma.wholesaleItem.update({
        where: { id },
        data: {
          ...parsed.data,
          ...(req.file && imageMimeType
            ? {
                imageData: req.file.buffer,
                imageMimeType,
                imageUrl: `/api/v1/wholesale/${id}/image`,
              }
            : parsed.data.imageUrl === null
              ? { imageData: null, imageMimeType: null }
              : {}),
        },
        select: wholesaleItemSelect,
      });
      return res.json({ wholesaleItem: wholesaleItemResponse(item) });
    } catch (error) {
      if (handleKnownError(error, res)) return;
      sendAdminError(error, res);
    }
  });

  router.delete('/wholesale-items/:id', async (req, res) => {
    const id = parseRecordId(req.params.id, res);
    if (!id) return;
    try {
      const item = await prisma.wholesaleItem.update({
        where: { id },
        data: { isActive: false },
        select: { id: true, isActive: true },
      });
      return res.json({ wholesaleItem: item });
    } catch (error) {
      if (handleKnownError(error, res)) return;
      sendAdminError(error, res);
    }
  });

  router.get('/products', async (req, res) => {
    const parsed = productsQuery.safeParse(req.query);
    if (!parsed.success) return invalidInput(res, parsed.error);
    const query = parsed.data;
    const availability = query.availability === 'available' || query.availability === 'in_stock'
      ? 'in_stock'
      : query.availability === 'unavailable' || query.availability === 'out_of_stock'
        ? 'out_of_stock'
        : undefined;
    const stockFilter = query.stock ?? availability;

    try {
      const and: Prisma.ProductWhereInput[] = [];
      if (query.search) {
        and.push({
          OR: [
            { name: { contains: query.search, mode: 'insensitive' } },
            { sku: { contains: query.search, mode: 'insensitive' } },
            { brand: { contains: query.search, mode: 'insensitive' } },
          ],
        });
      }
      const categoryLookup = query.categoryId ?? query.category;
      if (categoryLookup) {
        const category = await prisma.category.findFirst({
          where: { OR: [{ id: categoryLookup }, { slug: categoryLookup }] },
          select: { id: true },
        });
        if (!category) {
          return res.json({
            products: [],
            pagination: { page: query.page, pageSize: query.pageSize, total: 0 },
          });
        }
        and.push({ categoryId: category.id });
      }
      if (stockFilter) {
        const productIds = await availableProductIds(prisma, stockFilter);
        and.push({ id: { in: productIds } });
      }
      if (query.wholesale !== undefined) {
        and.push({ isWholesale: query.wholesale });
      }
      if (query.vendingDrink !== undefined) {
        and.push({ isVendingDrink: query.vendingDrink });
      }

      const where: Prisma.ProductWhereInput = and.length ? { AND: and } : {};
      const orderBy: Prisma.ProductOrderByWithRelationInput = {
        name_asc: { name: 'asc' },
        name_desc: { name: 'desc' },
        price_asc: { price: 'asc' },
        price_desc: { price: 'desc' },
        newest: { createdAt: 'desc' },
        oldest: { createdAt: 'asc' },
        stock_asc: { inventory: { totalStock: 'asc' } },
        stock_desc: { inventory: { totalStock: 'desc' } },
      }[query.sort] as Prisma.ProductOrderByWithRelationInput;

      const [total, products] = await Promise.all([
        prisma.product.count({ where }),
        prisma.product.findMany({
          where,
          orderBy,
          skip: (query.page - 1) * query.pageSize,
          take: query.pageSize,
          select: productSelect,
        }),
      ]);
      return res.json({
        products: products.map(productResponse),
        pagination: { page: query.page, pageSize: query.pageSize, total },
      });
    } catch (error) {
      sendAdminError(error, res);
    }
  });

  router.post('/products', receiveSingleImage, async (req, res) => {
    const body = productRequestBody(req);
    if (!body) {
      return res.status(400).json({ error: 'Product fields are required.' });
    }
    const parsed = createProductInput.safeParse(body);
    if (!parsed.success) return invalidInput(res, parsed.error);
    const { stock = 0, ...data } = parsed.data;
    if (data.price <= 0) return res.status(400).json({ error: 'Price must be greater than zero' });
    const salePriceError = validateProductSalePrice(data.price, data.originalPrice);
    if (salePriceError) return res.status(400).json({ error: salePriceError });
    const imageMimeType = req.file
      ? getImageMimeType(req.file.buffer)
      : null;
    if (req.file && !imageMimeType) {
      return res.status(400).json({ error: 'Use a valid JPEG, PNG, or WebP image.' });
    }

    try {
      const category = await prisma.category.findUnique({
        where: { id: data.categoryId },
        select: { name: true },
      });
      const unitError = validateProductUnit({
        name: data.name,
        categoryName: category?.name ?? '',
        unitLabel: data.unitLabel ?? '1 pc',
      });
      if (unitError) return res.status(400).json({ error: unitError });

      const product = await prisma.$transaction(async (tx) => {
        const created = await tx.product.create({
          data: {
            ...data,
            ...(req.file && imageMimeType
              ? {
                  imageData: req.file.buffer,
                  imageMimeType,
                }
              : {}),
          },
        });
        if (req.file && imageMimeType) {
          await tx.product.update({
            where: { id: created.id },
            data: { imageUrl: `/api/v1/products/${created.id}/image` },
          });
        }
        const adminId = res.locals.authenticatedUserId;
        await inventoryService.setStock(
          tx,
          created.id,
          stock,
          `admin:${adminId}`,
          `Initial stock set to ${stock} by admin ${adminId}.`,
        );
        return tx.product.findUnique({ where: { id: created.id }, select: productSelect });
      });
      if (!product) return res.status(500).json({ error: 'Unable to load the created product' });
      return res.status(201).json({ product: productResponse(product) });
    } catch (error) {
      if (error instanceof InventoryAdjustmentError) {
        return res.status(409).json({ error: error.message });
      }
      if (handleKnownError(error, res)) return;
      sendAdminError(error, res);
    }
  });

  router.patch('/products/:id', receiveSingleImage, async (req, res) => {
    const id = parseRecordId(req.params.id, res);
    if (!id) return;
    const body = productRequestBody(req);
    if (!body) {
      return res.status(400).json({ error: 'Product fields are invalid.' });
    }
    const parsed = updateProductInput.safeParse(body);
    if (!parsed.success) return invalidInput(res, parsed.error);
    const { stock, ...data } = parsed.data;
    if (data.price !== undefined && data.price <= 0) {
      return res.status(400).json({ error: 'Price must be greater than zero' });
    }
    const imageMimeType = req.file
      ? getImageMimeType(req.file.buffer)
      : null;
    if (req.file && !imageMimeType) {
      return res.status(400).json({ error: 'Use a valid JPEG, PNG, or WebP image.' });
    }

    try {
      const currentProduct = await prisma.product.findUnique({
        where: { id },
        select: {
          name: true,
          categoryId: true,
          unitLabel: true,
          price: true,
          originalPrice: true,
          category: { select: { name: true } },
        },
      });

      if (!currentProduct) {
        return res.status(404).json({ error: 'Product not found' });
      }
      const category =
        data.categoryId && data.categoryId !== currentProduct.categoryId
          ? await prisma.category.findUnique({
              where: { id: data.categoryId },
              select: { name: true },
            })
          : currentProduct.category;
      const unitError = validateProductUnit({
        name: data.name ?? currentProduct.name,
        categoryName: category?.name ?? '',
        unitLabel: data.unitLabel ?? currentProduct.unitLabel,
      });
      if (unitError) return res.status(400).json({ error: unitError });
      const salePriceError = validateProductSalePrice(
        data.price ?? Number(currentProduct.price),
        data.originalPrice === undefined
          ? currentProduct.originalPrice === null
            ? null
            : Number(currentProduct.originalPrice)
          : data.originalPrice,
      );
      if (salePriceError) {
        return res.status(400).json({ error: salePriceError });
      }
      const product = await prisma.$transaction(async (tx) => {
        const existing = await tx.product.findUnique({
          where: { id },
          select: { id: true },
        });
        if (!existing) return null;
        if (Object.keys(data).length > 0 || req.file) {
          await tx.product.update({
            where: { id },
            data: {
              ...data,
              ...(req.file && imageMimeType
                ? {
                    imageData: req.file.buffer,
                    imageMimeType,
                    imageUrl: `/api/v1/products/${id}/image`,
                  }
                : data.imageUrl === null
                  ? { imageData: null, imageMimeType: null }
                  : {}),
            },
          });
        }
        if (stock !== undefined) {
          const adminId = res.locals.authenticatedUserId;
          await inventoryService.setStock(
            tx,
            id,
            stock,
            `admin:${adminId}`,
            `Stock adjusted to ${stock} by admin ${adminId}.`,
          );
        }
        return tx.product.findUnique({ where: { id }, select: productSelect });
      });
      if (!product) return res.status(404).json({ error: 'Product not found' });
      return res.json({ product: productResponse(product) });
    } catch (error) {
      if (error instanceof InventoryAdjustmentError) {
        return res.status(409).json({ error: error.message });
      }
      if (handleKnownError(error, res)) return;
      sendAdminError(error, res);
    }
  });

  router.post('/products/:id/restock', async (req, res) => {
    const id = parseRecordId(req.params.id, res);
    if (!id) return;
    const parsed = restockInput.safeParse(req.body);
    if (!parsed.success) return invalidInput(res, parsed.error);
    try {
      const product = await prisma.$transaction(async (tx) => {
        const existing = await tx.product.findUnique({
          where: { id },
          select: { id: true },
        });
        if (!existing) return null;
        const adminId = res.locals.authenticatedUserId;
        await inventoryService.restock(
          tx,
          [{ productId: id, quantity: parsed.data.quantity }],
          `admin:${adminId}`,
          parsed.data.notes ?? 'Stock receipt added by store staff.',
          adminId,
        );
        return tx.product.findUnique({ where: { id }, select: productSelect });
      });
      if (!product) return res.status(404).json({ error: 'Product not found' });
      return res.json({ product: productResponse(product) });
    } catch (error) {
      if (error instanceof InventoryAdjustmentError) {
        return res.status(409).json({ error: error.message });
      }
      if (handleKnownError(error, res)) return;
      sendAdminError(error, res);
    }
  });

  router.get('/inventory/restock-history', async (req, res) => {
    const parsed = restockHistoryQuery.safeParse(req.query);
    if (!parsed.success) return invalidInput(res, parsed.error);
    const { page, pageSize } = parsed.data;
    const where = { type: 'RESTOCKED' as const };
    try {
      const [total, receipts] = await Promise.all([
        prisma.inventoryTransaction.count({ where }),
        prisma.inventoryTransaction.findMany({
          where,
          orderBy: { createdAt: 'desc' },
          skip: (page - 1) * pageSize,
          take: pageSize,
          select: {
            id: true,
            quantity: true,
            balanceAfter: true,
            notes: true,
            createdAt: true,
            performedBy: { select: { id: true, name: true } },
            inventory: {
              select: {
                product: {
                  select: { id: true, name: true, sku: true, unitLabel: true },
                },
              },
            },
          },
        }),
      ]);
      return res.json({
        receipts: receipts.map(({ inventory, performedBy, ...receipt }) => ({
          ...receipt,
          staff: performedBy,
          product: inventory.product,
        })),
        pagination: { page, pageSize, total },
      });
    } catch (error) {
      sendAdminError(error, res);
    }
  });

  router.delete('/products/:id', async (req, res) => {
    const id = parseRecordId(req.params.id, res);
    if (!id) return;
    try {
      const product = await prisma.product.update({
        where: { id },
        data: { isActive: false },
        select: { id: true, name: true, sku: true, isActive: true },
      });
      return res.json({ product });
    } catch (error) {
      if (handleKnownError(error, res)) return;
      sendAdminError(error, res);
    }
  });

  return router;
}
