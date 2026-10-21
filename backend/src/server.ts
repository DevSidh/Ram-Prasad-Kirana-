import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import { rateLimit } from 'express-rate-limit';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import path from 'node:path';
import { Prisma, PrismaClient } from '@prisma/client';
import { z } from 'zod';
import { createAuthMiddleware } from './middleware/auth.js';
import { createAccountRouter } from './routes/account.js';
import { createAdminRouter } from './routes/admin.js';
import { createDeliveryRouter } from './routes/delivery.js';
import { createEmailVerificationRouter } from './routes/email-verification.js';
import { createPasswordResetRouter } from './routes/password-reset.js';
import { createPlacesRouter } from './routes/places.js';
import { createPublicLegalRouter } from './routes/public-legal.js';
import { sendPushToUser } from './services/push-notifications.js';
import { getUploadsDirectory } from './services/image-upload.js';
import {
  getNormalizedProductImage,
  getNormalizedWholesaleImage,
} from './services/product-image.js';
import {
  identityAlreadyInUse,
  normalizeEmail,
  normalizeSignupPhone,
} from './services/user-identity.js';
import { findAdminByPassword } from './services/admin-login.js';
import { orderInput } from './schemas/order.js';
import { InventoryService } from './services/inventory.js';
import { canCustomerCancelOrder } from './services/order-cancellation.js';
import { orderCartCleanupWhere } from './services/order-cart-cleanup.js';
import { checkCoupon, toPublicCouponOffer } from './services/coupon.js';
import {
  CUSTOMER_CATALOG_CATEGORY_FILTER,
  CUSTOMER_CATALOG_PRODUCT_FILTER,
} from './services/customer-catalog.js';
import {
  assertWithinDeliveryServiceArea,
  DEFAULT_DELIVERY_FEE,
  DeliveryPricingError,
} from './services/delivery-pricing.js';
import {
  DEFAULT_WEEKLY_HOURS,
  getStoreAvailability,
} from './services/store-hours.js';
import { getEmailDeliveryConfigurationStatus } from './services/email-sender.js';

dotenv.config();

const app = express();
const PORT = Number(process.env.PORT ?? 4000);
if (!Number.isInteger(PORT) || PORT < 1 || PORT > 65535) {
  throw new Error('PORT must be a valid TCP port between 1 and 65535.');
}
app.set('trust proxy', process.env.RENDER === 'true' ? 1 : false);
const AUTH_SECRET = process.env.AUTH_SECRET;
const ADMIN_USERNAME = process.env.ADMIN_USERNAME?.trim().toLowerCase();
const ADMIN_EMAIL = process.env.ADMIN_EMAIL?.trim().toLowerCase();
const prisma = new PrismaClient();
const inventoryService = new InventoryService(prisma);
const productionCorsOrigins = new Set(
  (process.env.CORS_ORIGINS ?? '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean),
);

if (!AUTH_SECRET || AUTH_SECRET.length < 32) {
  throw new Error('Missing required AUTH_SECRET environment variable. Set a secure secret before starting the backend.');
}

const JWT_EXPIRES_IN_SECONDS = (() => {
  const configuredValue = process.env.JWT_EXPIRES_IN || '7d';
  const match = /^(\d+)(s|m|h|d)$/.exec(configuredValue);
  if (!match) {
    throw new Error('JWT_EXPIRES_IN must be a duration such as 15m, 12h, or 7d.');
  }

  const duration = Number(match[1]);
  const unitInSeconds: Record<string, number> = {
    s: 1,
    m: 60,
    h: 60 * 60,
    d: 24 * 60 * 60,
  };
  const seconds = duration * unitInSeconds[match[2]];
  if (!Number.isSafeInteger(seconds) || seconds <= 0) {
    throw new Error('JWT_EXPIRES_IN must be a positive, safe duration.');
  }
  return seconds;
})();

app.use(helmet());
app.use(cors({
  origin(origin, callback) {
    if (!origin || process.env.NODE_ENV !== 'production') {
      return callback(null, true);
    }
    return callback(null, productionCorsOrigins.has(origin));
  },
  credentials: false,
}));
app.use(express.json({ limit: '100kb' }));
app.use('/uploads', express.static(getUploadsDirectory(), {
  maxAge: '1d',
  immutable: true,
}));
app.use('/uploads', express.static(path.join(process.cwd(), 'catalog-uploads'), {
  maxAge: '1d',
  immutable: true,
  fallthrough: true,
}));
app.use(createPublicLegalRouter());

const authRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many authentication attempts. Try again later.' },
});
app.use('/api/v1/auth/login', authRateLimit);
app.use('/api/v1/auth/register', authRateLimit);
app.use(
  '/api/v1/auth/email-verification',
  createEmailVerificationRouter(prisma, AUTH_SECRET, JWT_EXPIRES_IN_SECONDS),
);

const { authenticateToken, requireAdmin, requireDeliveryPerson } =
  createAuthMiddleware(prisma, AUTH_SECRET);
app.use('/api/v1/admin', createAdminRouter(prisma, authenticateToken, requireAdmin));
app.use(
  '/api/v1/delivery',
  createDeliveryRouter(prisma, authenticateToken, requireDeliveryPerson),
);
app.use('/api/v1/account', createAccountRouter(prisma, authenticateToken));
app.use('/api/v1/places', createPlacesRouter(authenticateToken));
app.use('/api/v1/auth/password-reset', createPasswordResetRouter(prisma));

function queueOrderNotification(
  userId: string,
  orderId: string,
  type: 'ORDER_PLACED' | 'ORDER_CANCELLED',
  title: string,
  body: string,
): void {
  void prisma.notification.create({
    data: {
      userId,
      type,
      title,
      body,
      metadata: { orderId },
    },
  }).then(() => sendPushToUser(prisma, userId, title, body, { orderId }))
    .catch((error: unknown) => {
      console.error(`Unable to deliver ${type} notification for ${orderId}:`, error);
    });
}

const orderInclude = {
  items: {
    include: {
      product: {
        select: {
          id: true,
          name: true,
          brand: true,
          categoryId: true,
          price: true,
          originalPrice: true,
          rating: true,
          reviewCount: true,
          description: true,
          imageUrl: true,
          imageMimeType: true,
          unitLabel: true,
          updatedAt: true,
          category: { select: { name: true, slug: true } },
        },
      },
      wholesaleItem: {
        select: {
          id: true,
          name: true,
          brand: true,
          categoryId: true,
          price: true,
          minimumQuantity: true,
          description: true,
          imageUrl: true,
          imageMimeType: true,
          unitLabel: true,
          updatedAt: true,
          category: { select: { name: true, slug: true } },
        },
      },
    },
  },
  address: true,
  delivery: {
    include: {
      deliveryPerson: {
        select: { name: true, phone: true },
      },
    },
  },
} satisfies Prisma.OrderInclude;

type OrderRecord = Prisma.OrderGetPayload<{ include: typeof orderInclude }>;

function orderResponse(order: OrderRecord) {
  const deliveryLocationIsFresh =
    order.status === 'OUT_FOR_DELIVERY' &&
    order.delivery?.status === 'OUT_FOR_DELIVERY' &&
    order.delivery.locationUpdatedAt !== null &&
    Date.now() - order.delivery.locationUpdatedAt.getTime() <= 120_000;
  return {
    id: order.id,
    orderNumber: order.orderNumber,
    items: order.items.map((item) => {
      const wholesaleItem = item.wholesaleItem;
      const product = item.product;
      const category = wholesaleItem?.category ?? product?.category;
      if (!category) {
        throw new Error(`Order item ${item.id} has no catalog record.`);
      }
      const imageUrl = wholesaleItem?.imageUrl ?? product?.imageUrl ?? '';
      const imageMimeType = wholesaleItem?.imageMimeType ?? product?.imageMimeType;
      const updatedAt = wholesaleItem?.updatedAt ?? product?.updatedAt;
      return {
        quantity: item.quantity,
        isWholesale: item.isWholesale,
        product: {
          id: wholesaleItem?.id ?? product?.id ?? item.productId ?? '',
          name: wholesaleItem?.name ?? product?.name ?? item.productName,
          brand: wholesaleItem?.brand ?? product?.brand ?? null,
          categoryId: wholesaleItem?.categoryId ?? product?.categoryId ?? '',
          categoryName: category.name,
          categorySlug: category.slug,
          price: Number(item.price),
          originalPrice: product?.originalPrice
            ? Number(product.originalPrice)
            : null,
          weight: wholesaleItem?.unitLabel ?? product?.unitLabel ?? '1 pc',
          rating: product ? Number(product.rating) : 0,
          reviewCount: product?.reviewCount ?? 0,
          isWholesale: item.isWholesale,
          wholesalePrice: item.isWholesale
            ? Number(wholesaleItem?.price ?? item.price)
            : null,
          wholesaleMinimumQuantity: wholesaleItem?.minimumQuantity ?? 1,
          description: wholesaleItem?.description ?? product?.description ?? '',
          imageUrl: imageMimeType && updatedAt && imageUrl
            ? `${imageUrl}?v=${updatedAt.getTime()}`
            : imageUrl,
        },
      };
    }),
    address: order.address
      ? {
        id: order.address.id,
        title: order.address.label ?? 'Delivery address',
        fullName: order.address.fullName,
        phone: order.address.phone,
        province: order.address.province ?? '',
        city: order.address.city,
        street: order.address.addressLine1,
        landmark: order.address.addressLine2,
        instructions: order.address.instructions,
        isDefault: order.address.isDefault,
        latitude: order.address.latitude,
        longitude: order.address.longitude,
      }
      : {
        id: '',
        title: 'Delivery address',
        fullName: order.shippingName,
        phone: order.shippingPhone,
        province: order.shippingProvince ?? '',
        city: order.shippingCity,
        street: order.shippingAddress,
        landmark: null,
        instructions: order.notes,
        isDefault: false,
      },
    status: order.status,
    deliveryPersonName: order.delivery?.deliveryPerson?.name ?? null,
    deliveryPersonPhone: order.delivery?.deliveryPerson?.phone ?? null,
    deliveryPersonLatitude: deliveryLocationIsFresh
      ? order.delivery?.latitude ?? null
      : null,
    deliveryPersonLongitude: deliveryLocationIsFresh
      ? order.delivery?.longitude ?? null
      : null,
    deliveryLocationUpdatedAt: deliveryLocationIsFresh
      ? order.delivery?.locationUpdatedAt?.toISOString() ?? null
      : null,
    paymentMethod: order.paymentMethod,
    paymentStatus: order.paymentStatus,
    subtotal: Number(order.subtotal),
    deliveryFee: Number(order.deliveryFee),
    discount: Number(order.discount),
    couponCode: order.couponCode,
    tip: Number(order.tip),
    total: Number(order.total),
    createdAt: order.createdAt.toISOString(),
    scheduledDeliveryAt: order.scheduledDeliveryAt?.toISOString() ?? null,
  };
}

// ==================== AUTHENTICATION ROUTES ====================
app.post('/api/v1/auth/register', async (req: Request, res: Response) => {
  const { fullName, email, phone, password } = req.body;

  if (typeof fullName !== 'string' || typeof email !== 'string' ||
    typeof phone !== 'string' || typeof password !== 'string') {
    return res.status(400).json({
      error: 'Full name, email, phone number and password are required',
    });
  }

  const normalizedName = fullName.trim();
  const normalizedEmail = normalizeEmail(email);
  const normalizedPhone = normalizeSignupPhone(phone);

  if (normalizedName.length === 0 || normalizedName.length > 120) {
    return res.status(400).json({ error: 'Full name must be between 1 and 120 characters' });
  }

  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizedEmail)) {
    return res.status(400).json({ error: 'A valid email address is required' });
  }
  if (password.length < 8 || password.length > 128) {
    return res.status(400).json({ error: 'Password must be between 8 and 128 characters long' });
  }
  if (!normalizedPhone) {
    return res.status(400).json({ error: 'Enter a valid 10-digit phone number' });
  }

  try {
    if (await identityAlreadyInUse(prisma, {
      email: normalizedEmail,
      phone: normalizedPhone,
    })) {
      return res.status(409).json({ error: 'An account with this email or phone already exists' });
    }
    const passwordHash = await bcrypt.hash(password, 12);
    const user = await prisma.user.create({
      data: {
        name: normalizedName,
        email: normalizedEmail,
        phone: normalizedPhone,
        passwordHash,
        emailVerified: false,
      },
    });

    return res.status(201).json({
      message: 'Account created. Verify your email address to finish registration.',
      requiresEmailVerification: true,
      email: user.email,
    });
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
      return res.status(409).json({ error: 'An account with this email or phone already exists' });
    }

    console.error('User registration failed:', error);
    return res.status(500).json({ error: 'Unable to create account at this time' });
  }
});

const loginUserSelect = {
  id: true,
  email: true,
  name: true,
  phone: true,
  role: true,
  avatarUrl: true,
  isActive: true,
  emailVerified: true,
  passwordHash: true,
  tokenVersion: true,
} satisfies Prisma.UserSelect;

app.post('/api/v1/auth/login', async (req: Request, res: Response) => {
  const { email, username, password } = req.body;
  if (typeof password !== 'string') {
    return res.status(400).json({ error: 'Password is required' });
  }

  let user: Prisma.UserGetPayload<{ select: typeof loginUserSelect }> | null =
    null;
  let adminIdentifierUsed = false;
  try {
    if (typeof username === 'string') {
      const identifier = username.trim().toLowerCase();
      const isConfiguredUsername =
        Boolean(ADMIN_USERNAME) && identifier === ADMIN_USERNAME;
      const isConfiguredEmail =
        Boolean(ADMIN_EMAIL) && identifier === ADMIN_EMAIL;
      const isAdminIdentifier = isConfiguredUsername || isConfiguredEmail;
      if (!isAdminIdentifier) {
        return res.status(401).json({ error: 'Invalid username or password' });
      }

      adminIdentifierUsed = true;
      const admins = await prisma.user.findMany({
        where: {
          role: 'ADMIN',
          isActive: true,
          ...(ADMIN_EMAIL ? { email: ADMIN_EMAIL } : {}),
        },
        select: loginUserSelect,
      });
      user = await findAdminByPassword(admins, password, bcrypt.compare);
      if (!user) {
        return res.status(401).json({ error: 'Invalid username or password' });
      }
    } else if (typeof email === 'string') {
      const normalizedEmail = email.trim().toLowerCase();
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizedEmail)) {
        return res.status(400).json({ error: 'A valid email address is required' });
      }
      user = await prisma.user.findUnique({
        where: { email: normalizedEmail },
        select: loginUserSelect,
      });
      if (
        !user ||
        !user.isActive ||
        !(await bcrypt.compare(password, user.passwordHash))
      ) {
        return res.status(401).json({ error: 'Invalid email or password' });
      }
      if (!user.emailVerified) {
        return res.status(403).json({
          error: 'Verify your email address before signing in.',
          requiresEmailVerification: true,
          email: user.email,
        });
      }
    } else {
      return res.status(400).json({ error: 'Email or admin username is required' });
    }

    if (!user || (adminIdentifierUsed && user.role !== 'ADMIN')) {
      return res.status(401).json({ error: 'Invalid username or password' });
    }

    const token = jwt.sign(
      {
        id: user.id,
        email: user.email,
        fullName: user.name,
        role: user.role,
        tokenVersion: user.tokenVersion,
      },
      AUTH_SECRET,
      { expiresIn: JWT_EXPIRES_IN_SECONDS }
    );

    return res.json({
      token,
      user: {
        id: user.id,
        email: user.email,
        fullName: user.name,
        phone: user.phone,
        role: user.role,
        avatarUrl: user.avatarUrl,
      },
    });
  } catch (error) {
    console.error('User login failed:', error);
    return res.status(500).json({ error: 'Unable to sign in at this time' });
  }
});

// ==================== PRODUCTS & CATEGORIES ROUTES ====================
app.get('/api/v1/categories', async (_req: Request, res: Response) => {
  try {
    const categories = await prisma.category.findMany({
      where: CUSTOMER_CATALOG_CATEGORY_FILTER,
      orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
      include: {
        _count: {
          select: { products: { where: CUSTOMER_CATALOG_PRODUCT_FILTER } },
        },
      },
    });

    return res.json({
      data: categories.map(({ _count, ...category }) => ({
        ...category,
        itemCount: _count.products,
      })),
    });
  } catch (error) {
    console.error('Public category listing failed:', error);
    return res.status(500).json({ error: 'Unable to load store categories' });
  }
});

app.get('/api/v1/store/availability', async (_req: Request, res: Response) => {
  try {
    res.setHeader('Cache-Control', 'no-store');
    const settings = await prisma.storeSetting.findUnique({ where: { id: 'store' } });
    return res.json(getStoreAvailability(
      settings?.isOrderingEnabled ?? true,
      settings?.weeklyHours ?? DEFAULT_WEEKLY_HOURS,
    ));
  } catch (error) {
    console.error('Public store availability lookup failed:', error);
    return res.status(500).json({ error: 'Unable to check store availability.' });
  }
});

app.get('/api/v1/products', async (req: Request, res: Response) => {
  const category = typeof req.query.category === 'string' ? req.query.category : undefined;
  const vendingDrink = req.query.vendingDrink === 'true';
  const search = typeof req.query.search === 'string' ? req.query.search.trim() : undefined;
  const sort = typeof req.query.sort === 'string' ? req.query.sort : undefined;
  const page = typeof req.query.page === 'string' ? Number(req.query.page) : 1;
  const limit = typeof req.query.limit === 'string' ? Number(req.query.limit) : 100;
  if (!Number.isSafeInteger(page) || page < 1 ||
    !Number.isSafeInteger(limit) || limit < 1 || limit > 100) {
    return res.status(400).json({
      error: 'Page must be a positive integer and limit must be between 1 and 100.',
    });
  }

  try {
    const categoryRecord = category && category !== 'all'
      ? await prisma.category.findFirst({
        where: {
          AND: [
            { OR: [{ id: category }, { slug: category }] },
            CUSTOMER_CATALOG_CATEGORY_FILTER,
          ],
        },
        select: { id: true },
      })
      : null;

    if (category && category !== 'all' && !categoryRecord) {
      return res.json({ data: [], pagination: { total: 0, page, limit } });
    }

    const where: Prisma.ProductWhereInput = {
      ...CUSTOMER_CATALOG_PRODUCT_FILTER,
      ...(vendingDrink ? { isVendingDrink: true } : {}),
      ...(categoryRecord ? { categoryId: categoryRecord.id } : {}),
      ...(search
        ? {
          OR: [
            { name: { contains: search, mode: 'insensitive' } },
            { brand: { contains: search, mode: 'insensitive' } },
            { description: { contains: search, mode: 'insensitive' } },
          ],
        }
        : {}),
    };
    const [total, products] = await Promise.all([
      prisma.product.count({ where }),
      prisma.product.findMany({
        where,
        orderBy: sort === 'price_asc'
          ? { price: 'asc' }
          : sort === 'price_desc'
            ? { price: 'desc' }
            : sort === 'rating'
              ? { rating: 'desc' }
              : { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
        select: {
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
          category: { select: { name: true, slug: true } },
          inventory: { select: { totalStock: true, reservedStock: true } },
        },
      }),
    ]);

    const data = products.map(({ category: productCategory, inventory, imageMimeType, ...product }) => {
      const price = Number(product.price);
      const originalPrice = product.originalPrice === null
        ? null
        : Number(product.originalPrice);
      return {
        ...product,
        price,
        originalPrice,
        wholesalePrice: product.wholesalePrice === null
          ? null
          : Number(product.wholesalePrice),
        discountPercent: originalPrice !== null && originalPrice > price
          ? Math.round(((originalPrice - price) / originalPrice) * 100)
          : 0,
        weight: product.unitLabel,
        imageUrl: imageMimeType && product.imageUrl
          ? `${product.imageUrl}?v=${product.updatedAt.getTime()}`
          : product.imageUrl,
        rating: Number(product.rating),
        categoryName: productCategory.name,
        categorySlug: productCategory.slug,
        stock: Math.max(0, (inventory?.totalStock ?? 0) - (inventory?.reservedStock ?? 0)),
      };
    });

    return res.json({
      data,
      pagination: { total, page, limit },
    });
  } catch (error) {
    console.error('Public product listing failed:', error);
    return res.status(500).json({ error: 'Unable to load store products' });
  }
});

app.get('/api/v1/products/:id/image', async (req: Request, res: Response) => {
  try {
    const product = await prisma.product.findFirst({
      where: {
        id: req.params.id,
        ...CUSTOMER_CATALOG_PRODUCT_FILTER,
      },
      select: { imageData: true, imageMimeType: true },
    });
    if (!product?.imageData || !product.imageMimeType) {
      return res.status(404).json({ error: 'Product image not found.' });
    }
    if (req.query.original === '1') {
      res.setHeader('Cache-Control', 'public, max-age=86400');
      return res.type(product.imageMimeType).send(product.imageData);
    }
    const normalized = await getNormalizedProductImage(prisma, req.params.id);
    if (!normalized) {
      return res.status(404).json({ error: 'Product image not found.' });
    }
    res.setHeader('Cache-Control', 'public, max-age=86400');
    return res.type(normalized.mimeType).send(normalized.data);
  } catch (error) {
    console.error('Product image lookup failed:', error);
    return res.status(500).json({ error: 'Unable to load this product image.' });
  }
});

app.get('/api/v1/wholesale', async (req: Request, res: Response) => {
  const page = Number(req.query.page ?? 1);
  const limit = Number(req.query.limit ?? 20);
  const search = typeof req.query.search === 'string'
    ? req.query.search.trim().slice(0, 200)
    : '';
  if (!Number.isInteger(page) || page < 1 ||
    !Number.isInteger(limit) || limit < 1 || limit > 100) {
    return res.status(400).json({ error: 'Invalid wholesale catalog pagination.' });
  }
  try {
    const where: Prisma.WholesaleItemWhereInput = {
      isActive: true,
      category: { isActive: true },
      ...(search
        ? {
          OR: [
            { name: { contains: search, mode: 'insensitive' } },
            { brand: { contains: search, mode: 'insensitive' } },
            { description: { contains: search, mode: 'insensitive' } },
          ],
        }
        : {}),
    };
    const [total, items] = await Promise.all([
      prisma.wholesaleItem.count({ where }),
      prisma.wholesaleItem.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
        select: {
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
          updatedAt: true,
          category: { select: { name: true, slug: true } },
        },
      }),
    ]);
    return res.json({
      data: items.map(({ imageMimeType, category, ...item }) => ({
        ...item,
        price: Number(item.price),
        isWholesale: true,
        wholesalePrice: Number(item.price),
        wholesaleMinimumQuantity: item.minimumQuantity,
        categoryName: category.name,
        categorySlug: category.slug,
        imageUrl: imageMimeType && item.imageUrl
          ? `${item.imageUrl}?v=${item.updatedAt.getTime()}`
          : item.imageUrl,
      })),
      pagination: { total, page, limit },
    });
  } catch (error) {
    console.error('Wholesale catalog listing failed:', error);
    return res.status(500).json({ error: 'Unable to load wholesale items.' });
  }
});

app.get('/api/v1/wholesale/:id/image', async (req: Request, res: Response) => {
  try {
    const item = await prisma.wholesaleItem.findFirst({
      where: { id: req.params.id, isActive: true },
      select: { imageData: true, imageMimeType: true },
    });
    if (!item?.imageData || !item.imageMimeType) {
      return res.status(404).json({ error: 'Wholesale item image not found.' });
    }
    if (req.query.original === '1') {
      res.setHeader('Cache-Control', 'public, max-age=86400');
      return res.type(item.imageMimeType).send(Buffer.from(item.imageData));
    }
    const normalized = await getNormalizedWholesaleImage(prisma, req.params.id);
    if (!normalized) {
      return res.status(404).json({ error: 'Wholesale item image not found.' });
    }
    res.setHeader('Cache-Control', 'public, max-age=86400');
    return res.type(normalized.mimeType).send(normalized.data);
  } catch (error) {
    console.error('Wholesale item image lookup failed:', error);
    return res.status(500).json({ error: 'Unable to load this wholesale image.' });
  }
});

app.get('/api/v1/images/:id', async (req: Request, res: Response) => {
  try {
    const image = await prisma.storedImage.findUnique({
      where: { id: req.params.id },
      select: {
        imageData: true,
        mimeType: true,
        normalizedImageData: true,
        normalizedMimeType: true,
      },
    });
    if (!image) {
      return res.status(404).json({ error: 'Image not found.' });
    }
    res.setHeader('Cache-Control', 'public, max-age=86400');
    return res
      .type(image.normalizedMimeType ?? image.mimeType)
      .send(Buffer.from(image.normalizedImageData ?? image.imageData));
  } catch (error) {
    console.error('Stored image lookup failed:', error);
    return res.status(500).json({ error: 'Unable to load this image.' });
  }
});

app.get('/api/v1/products/:id', async (req: Request, res: Response) => {
  try {
    const product = await prisma.product.findFirst({
      where: {
        AND: [
          { OR: [{ id: req.params.id }, { slug: req.params.id }] },
          CUSTOMER_CATALOG_PRODUCT_FILTER,
        ],
      },
      select: {
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
        category: { select: { name: true, slug: true } },
        inventory: { select: { totalStock: true, reservedStock: true } },
      },
    });
    if (!product) return res.status(404).json({ error: 'Product not found' });

    const { category: productCategory, inventory, imageMimeType, ...fields } = product;
    const price = Number(product.price);
    const originalPrice = product.originalPrice === null
      ? null
      : Number(product.originalPrice);
    return res.json({
      data: {
        ...fields,
        price,
        originalPrice,
        wholesalePrice: product.wholesalePrice === null
          ? null
          : Number(product.wholesalePrice),
        discountPercent: originalPrice !== null && originalPrice > price
          ? Math.round(((originalPrice - price) / originalPrice) * 100)
          : 0,
        weight: product.unitLabel,
        imageUrl: imageMimeType && product.imageUrl
          ? `${product.imageUrl}?v=${product.updatedAt.getTime()}`
          : product.imageUrl,
        rating: Number(product.rating),
        categoryName: productCategory.name,
        categorySlug: productCategory.slug,
        stock: Math.max(0, (inventory?.totalStock ?? 0) - (inventory?.reservedStock ?? 0)),
      },
    });
  } catch (error) {
    console.error('Public product lookup failed:', error);
    return res.status(500).json({ error: 'Unable to load this store product' });
  }
});

// ==================== CHECKOUT & ORDERS (CONCURRENCY SAFE) ====================
class OrderStockError extends Error { }
class StoreUnavailableError extends Error { }
class CouponRejectedError extends Error { }

app.post('/api/v1/orders', authenticateToken, async (req: Request, res: Response) => {
  const userId = res.locals.authenticatedUserId as string | undefined;

  if (!userId) return res.status(401).json({ error: 'Authentication is required' });
  const parsed = orderInput.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({
      error: 'Check the cart, delivery address, and payment details.',
      details: parsed.error.issues.map((issue) => ({
        field: issue.path.join('.'),
        message: issue.message,
      })),
    });
  }
  const input = parsed.data;
  if (
    input.scheduledDeliveryAt &&
    new Date(input.scheduledDeliveryAt) <= new Date()
  ) {
    return res.status(400).json({
      error: 'Choose a delivery time in the future.',
    });
  }

  try {
    if (input.idempotencyKey) {
      const existing = await prisma.order.findFirst({
        where: { userId, idempotencyKey: input.idempotencyKey },
        include: orderInclude,
      });
      if (existing) {
        return res.status(200).json({
          order: orderResponse(existing),
          duplicatePrevented: true,
        });
      }
    }

    const createdOrderId = await prisma.$transaction(async (transaction) => {
      const storeSettings = await transaction.storeSetting.findUnique({
        where: { id: 'store' },
      });
      const availability = getStoreAvailability(
        storeSettings?.isOrderingEnabled ?? true,
        storeSettings?.weeklyHours ?? DEFAULT_WEEKLY_HOURS,
      );
      if (!availability.isAcceptingOrders) {
        throw new StoreUnavailableError(availability.statusMessage);
      }

      const address = await transaction.address.findFirst({
        where: { id: input.addressId, userId },
      });
      if (!address) throw new Error('Delivery address not found.');
      assertWithinDeliveryServiceArea(address.latitude, address.longitude);
      const productIds = [...new Set(
        input.items.filter((item) => !item.isWholesale).map((item) => item.productId),
      )];
      const wholesaleItemIds = [...new Set(
        input.items.filter((item) => item.isWholesale).map((item) => item.productId),
      )];
      const [products, wholesaleItems] = await Promise.all([
        transaction.product.findMany({
          where: {
            AND: [
              { id: { in: productIds }, isWholesale: false },
              CUSTOMER_CATALOG_PRODUCT_FILTER,
            ],
          },
          include: { inventory: true },
        }),
        transaction.wholesaleItem.findMany({
          where: {
            id: { in: wholesaleItemIds },
            isActive: true,
            category: { isActive: true },
          },
        }),
      ]);
      const productsById = new Map(products.map((product) => [product.id, product]));
      const wholesaleItemsById = new Map(
        wholesaleItems.map((item) => [item.id, item]),
      );
      let couponEligibleSubtotal = 0;
      const subtotal = input.items.reduce((sum, item) => {
        if (item.isWholesale) {
          const wholesaleItem = wholesaleItemsById.get(item.productId);
          if (!wholesaleItem) {
            throw new OrderStockError('This wholesale item is no longer available.');
          }
          if (item.quantity < wholesaleItem.minimumQuantity) {
            throw new OrderStockError(
              `${wholesaleItem.name} does not meet the current wholesale minimum quantity.`,
            );
          }
          return sum + Number(wholesaleItem.price) * item.quantity;
        }
        const product = productsById.get(item.productId);
        if (!product) throw new OrderStockError('This item is no longer available.');
        const price = Number(product.price);
        couponEligibleSubtotal += price * item.quantity;
        return sum + price * item.quantity;
      }, 0);

      let couponCode: string | null = null;
      let discount = 0;
      if (input.couponCode) {
        const coupon = await transaction.coupon.findUnique({
          where: { code: input.couponCode },
        });
        if (!coupon) {
          throw new CouponRejectedError('That coupon code is not valid.');
        }
        if (couponEligibleSubtotal <= 0) {
          throw new CouponRejectedError(
            'Coupons do not apply to wholesale-priced items.',
          );
        }
        const userUsedCount = coupon.perUserLimit === null
          ? 0
          : await transaction.order.count({
            where: {
              userId,
              couponCode: coupon.code,
              status: { not: 'CANCELLED' },
            },
          });
        const couponCheck = checkCoupon(
          coupon,
          couponEligibleSubtotal,
          new Date(),
          userUsedCount,
        );
        if (!couponCheck.valid) {
          throw new CouponRejectedError(couponCheck.message);
        }
        const now = new Date();
        const usage = await transaction.coupon.updateMany({
          where: {
            id: coupon.id,
            isActive: true,
            ...(coupon.usageLimit === null
              ? {}
              : { usedCount: { lt: coupon.usageLimit } }),
            OR: [{ expiresAt: null }, { expiresAt: { gt: now } }],
          },
          data: { usedCount: { increment: 1 } },
        });
        if (usage.count !== 1) {
          throw new CouponRejectedError(
            'This coupon has just expired or reached its redemption limit.',
          );
        }
        couponCode = coupon.code;
        discount = couponCheck.discount;
      }

      const stockByProduct = new Map<string, number>();
      const stockByWholesaleItem = new Map<string, number>();
      for (const item of input.items) {
        const stock = item.isWholesale ? stockByWholesaleItem : stockByProduct;
        stock.set(item.productId, (stock.get(item.productId) ?? 0) + item.quantity);
      }
      for (const [wholesaleItemId, quantity] of stockByWholesaleItem) {
        const item = wholesaleItemsById.get(wholesaleItemId);
        if (!item || item.stock < quantity) {
          throw new OrderStockError(
            `${item?.name ?? 'A wholesale item'} does not have enough stock.`,
          );
        }
      }
      for (const [productId, quantity] of stockByProduct) {
        const product = productsById.get(productId);
        const inventory = product?.inventory;
        if (!product || !inventory ||
          inventory.totalStock - inventory.reservedStock < quantity) {
          throw new OrderStockError(
            `${product?.name ?? 'An item'} does not have enough stock.`,
          );
        }
      }

      const deliveryFee = DEFAULT_DELIVERY_FEE;
      const total = subtotal + deliveryFee - discount;
      const orderNumber = `FH-${Date.now()}-${Math.floor(Math.random() * 1000)}`;

      const created = await transaction.order.create({
        data: {
          orderNumber,
          userId,
          addressId: address.id,
          status: 'PLACED',
          paymentMethod: input.paymentMethod,
          paymentStatus: 'PENDING',
          subtotal,
          deliveryFee,
          discount,
          tip: 0,
          total,
          couponCode,
          idempotencyKey: input.idempotencyKey,
          scheduledDeliveryAt: input.scheduledDeliveryAt
            ? new Date(input.scheduledDeliveryAt)
            : null,
          shippingName: address.fullName,
          shippingPhone: address.phone,
          shippingAddress: [
            address.addressLine1,
            address.addressLine2,
          ].filter(Boolean).join(', '),
          shippingCity: address.city,
          shippingDistrict: address.district,
          shippingProvince: address.province,
          shippingPostalCode: address.postalCode,
          notes: address.instructions,
          items: {
            create: input.items.map((item) => {
              const product = item.isWholesale
                ? wholesaleItemsById.get(item.productId)!
                : productsById.get(item.productId)!;
              const price = Number(product.price);
              return {
                productId: item.isWholesale ? null : product.id,
                wholesaleItemId: item.isWholesale ? product.id : null,
                isWholesale: item.isWholesale,
                productName: product.name,
                sku: product.sku,
                quantity: item.quantity,
                price,
                total: price * item.quantity,
              };
            }),
          },
          statusHistory: { create: { status: 'PLACED', note: 'Order placed by customer.' } },
        },
      });
      try {
        const retailStock = [...stockByProduct].map(([productId, quantity]) => ({
          productId,
          quantity,
        }));
        if (retailStock.length > 0) {
          await inventoryService.reserveStockForOrder(
            transaction,
            retailStock,
            created.id,
          );
          await inventoryService.commitReservedStock(
            transaction,
            retailStock,
            created.id,
          );
        }
        for (const [wholesaleItemId, quantity] of stockByWholesaleItem) {
          const changed = await transaction.wholesaleItem.updateMany({
            where: { id: wholesaleItemId, isActive: true, stock: { gte: quantity } },
            data: { stock: { decrement: quantity } },
          });
          if (changed.count !== 1) {
            throw new OrderStockError(
              'A wholesale item was just purchased by another customer.',
            );
          }
        }
      } catch (error) {
        if (error instanceof Error && error.message.startsWith('INSUFFICIENT_STOCK:')) {
          throw new OrderStockError('An item was just purchased by another customer.');
        }
        throw error;
      }
      const cart = await transaction.cart.findUnique({
        where: { userId },
        select: { id: true },
      });
      if (cart) {
        await transaction.cartItem.deleteMany({
          where: orderCartCleanupWhere(cart.id, input.items),
        });
      }
      return created.id;
    }, {
      maxWait: 10_000,
      timeout: 20_000,
    });
    const created = await prisma.order.findUnique({
      where: { id: createdOrderId },
      include: orderInclude,
    });
    if (!created) {
      throw new Error('Placed order could not be loaded after checkout.');
    }

    queueOrderNotification(
      userId,
      created.id,
      'ORDER_PLACED',
      'Order received',
      `Order ${created.orderNumber} has been placed successfully.`,
    );
    return res.status(201).json({
      message: 'Order placed successfully',
      order: orderResponse(created),
    });
  } catch (error) {
    if (error instanceof DeliveryPricingError) {
      return res.status(error.statusCode).json({ error: error.message });
    }
    if (error instanceof CouponRejectedError) {
      return res.status(409).json({ error: error.message });
    }
    if (error instanceof StoreUnavailableError) {
      return res.status(409).json({ error: error.message });
    }
    if (error instanceof OrderStockError) {
      return res.status(409).json({ error: error.message });
    }
    if (error instanceof Error && error.message === 'Delivery address not found.') {
      return res.status(404).json({ error: error.message });
    }
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002' &&
      input.idempotencyKey) {
      const existing = await prisma.order.findFirst({
        where: { userId, idempotencyKey: input.idempotencyKey },
        include: orderInclude,
      });
      if (existing) {
        return res.status(200).json({
          order: orderResponse(existing),
          duplicatePrevented: true,
        });
      }
    }
    console.error('Order placement failed:', error);
    return res.status(500).json({ error: 'Unable to place this order right now.' });
  }
});

app.get('/api/v1/orders', authenticateToken, (req: Request, res: Response) => {
  const userId = res.locals.authenticatedUserId as string | undefined;
  if (!userId) return res.status(401).json({ error: 'Authentication is required' });
  return prisma.order.findMany({
    where: { userId },
    orderBy: { createdAt: 'desc' },
    take: 100,
    include: orderInclude,
  }).then((orders) => res.json({ data: orders.map(orderResponse) }))
    .catch((error: unknown) => {
      console.error('Order list failed:', error);
      return res.status(500).json({ error: 'Unable to load your orders.' });
    });
});

app.post('/api/v1/orders/:id/cancel', authenticateToken, async (req: Request, res: Response) => {
  const userId = res.locals.authenticatedUserId as string | undefined;
  if (!userId) return res.status(401).json({ error: 'Authentication is required' });
  try {
    const result = await prisma.$transaction(async (transaction) => {
      const existing = await transaction.order.findFirst({
        where: { id: req.params.id, userId },
        include: {
          items: true,
          delivery: { select: { status: true } },
        },
      });
      if (!existing) return { kind: 'missing' as const };
      if (!canCustomerCancelOrder(
        existing.status,
        existing.delivery?.status ?? null,
      )) {
        return { kind: 'not-cancellable' as const };
      }
      const updated = await transaction.order.updateMany({
        where: {
          id: existing.id,
          userId,
          status: { in: ['PLACED', 'CONFIRMED', 'PROCESSING'] },
        },
        data: { status: 'CANCELLED', paymentStatus: 'CANCELLED' },
      });
      if (updated.count !== 1) return { kind: 'not-cancellable' as const };
      if (existing.couponCode) {
        await transaction.coupon.updateMany({
          where: { code: existing.couponCode, usedCount: { gt: 0 } },
          data: { usedCount: { decrement: 1 } },
        });
      }
      for (const item of existing.items) {
        if (item.productId) {
          const restocked = await transaction.inventory.updateMany({
            where: { productId: item.productId },
            data: {
              totalStock: { increment: item.quantity },
              version: { increment: 1 },
            },
          });
          if (restocked.count === 1) {
            const inventory = await transaction.inventory.findUnique({
              where: { productId: item.productId },
              select: { id: true, totalStock: true, reservedStock: true },
            });
            if (inventory) {
              await transaction.inventoryTransaction.create({
                data: {
                  inventoryId: inventory.id,
                  type: 'RESTOCKED',
                  quantity: item.quantity,
                  balanceAfter: inventory.totalStock - inventory.reservedStock,
                  referenceId: existing.id,
                  notes: `Stock returned after cancellation of Order #${existing.orderNumber}.`,
                },
              });
            }
          }
        } else if (item.wholesaleItemId) {
          await transaction.wholesaleItem.update({
            where: { id: item.wholesaleItemId },
            data: { stock: { increment: item.quantity } },
          });
        }
      }
      await transaction.orderStatusHistory.create({
        data: {
          orderId: existing.id,
          status: 'CANCELLED',
          note: 'Order cancelled by customer.',
        },
      });
      const order = await transaction.order.findUnique({
        where: { id: existing.id },
        include: orderInclude,
      });
      return order ? { kind: 'cancelled' as const, order } : { kind: 'missing' as const };
    });
    if (result.kind === 'missing') return res.status(404).json({ error: 'Order not found' });
    if (result.kind === 'not-cancellable') {
      return res.status(409).json({ error: 'This order can no longer be cancelled.' });
    }
    queueOrderNotification(
      userId,
      result.order.id,
      'ORDER_CANCELLED',
      'Order cancelled',
      `Order ${result.order.orderNumber} has been cancelled.`,
    );
    return res.json({ order: orderResponse(result.order) });
  } catch (error) {
    console.error('Order cancellation failed:', error);
    return res.status(500).json({ error: 'Unable to cancel this order right now.' });
  }
});

app.get('/api/v1/orders/:id', authenticateToken, async (req: Request, res: Response) => {
  const userId = res.locals.authenticatedUserId as string | undefined;
  if (!userId) return res.status(401).json({ error: 'Authentication is required' });
  try {
    const order = await prisma.order.findFirst({
      where: {
        userId,
        OR: [{ id: req.params.id }, { orderNumber: req.params.id }],
      },
      include: orderInclude,
    });
    if (!order) return res.status(404).json({ error: 'Order not found' });
    return res.json({ order: orderResponse(order) });
  } catch (error) {
    console.error('Order lookup failed:', error);
    return res.status(500).json({ error: 'Unable to load this order.' });
  }
});

app.get('/api/v1/coupons/offer', async (_req: Request, res: Response) => {
  try {
    const now = new Date();
    const coupons = await prisma.coupon.findMany({
      where: {
        isActive: true,
        OR: [{ expiresAt: null }, { expiresAt: { gt: now } }],
      },
      select: {
        id: true,
        code: true,
        isActive: true,
        discountType: true,
        discountPercent: true,
        discountAmount: true,
        minOrderAmount: true,
        maxDiscount: true,
        usageLimit: true,
        usedCount: true,
        expiresAt: true,
      },
      orderBy: [{ createdAt: 'desc' }, { code: 'asc' }],
    });
    const offer = coupons
      .map((coupon) => toPublicCouponOffer(coupon, now))
      .find((candidate) => candidate !== null) ?? null;
    return res.json({ offer });
  } catch (error) {
    console.error('Public coupon offer lookup failed:', error);
    return res.status(500).json({ error: 'Unable to load the current offer.' });
  }
});

app.post(
  '/api/v1/coupons/validate',
  authenticateToken,
  rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 20,
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: 'Too many coupon checks. Try again later.' },
  }),
  async (req: Request, res: Response) => {
    const input = z.object({
      code: z.string().trim().min(3).max(40)
        .transform((code) => code.toUpperCase()),
      subtotal: z.number().finite().positive(),
    }).strict().safeParse(req.body);
    if (!input.success) {
      return res.status(400).json({
        error: 'Enter a coupon code and a valid basket subtotal.',
        details: input.error.issues.map((issue) => ({
          field: issue.path.join('.'),
          message: issue.message,
        })),
      });
    }

    try {
      const userId = res.locals.authenticatedUserId as string | undefined;
      if (!userId) {
        return res.status(401).json({ error: 'Authentication is required.' });
      }
      const coupon = await prisma.coupon.findUnique({
        where: { code: input.data.code },
      });
      if (!coupon) {
        return res.json({
          valid: false,
          discount: 0,
          message: 'That coupon code is not valid.',
        });
      }
      const userUsedCount = coupon.perUserLimit === null
        ? 0
        : await prisma.order.count({
          where: {
            userId,
            couponCode: coupon.code,
            status: { not: 'CANCELLED' },
          },
        });
      const result = checkCoupon(
        coupon,
        input.data.subtotal,
        new Date(),
        userUsedCount,
      );
      return res.json({
        valid: result.valid,
        code: result.valid ? coupon.code : null,
        discount: result.discount,
        message: result.message,
      });
    } catch (error) {
      console.error('Coupon validation failed:', error);
      return res.status(500).json({ error: 'Unable to validate this coupon.' });
    }
  },
);

const healthCheck = async (_req: Request, res: Response) => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    return res.json({
      status: 'ok',
      service: 'Ram Prasad General Store API',
      database: 'connected',
      emailDelivery: getEmailDeliveryConfigurationStatus(),
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error('Health check database query failed:', error);
    return res.status(503).json({
      status: 'unavailable',
      service: 'Ram Prasad General Store API',
      database: 'disconnected',
      emailDelivery: getEmailDeliveryConfigurationStatus(),
      timestamp: new Date().toISOString(),
    });
  }
};

app.get('/health', healthCheck);
app.get('/api/v1/health', healthCheck);

if (process.env.NODE_ENV !== 'test') {
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`Ram Prasad General Store API running on port ${PORT}`);
  });
}

export default app;
