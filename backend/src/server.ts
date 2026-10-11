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
import { createPasswordResetRouter } from './routes/password-reset.js';
import { sendPushToUser } from './services/push-notifications.js';
import { getUploadsDirectory } from './services/image-upload.js';
import { identityAlreadyInUse, normalizeEmail, normalizePhone } from './services/user-identity.js';
import { findAdminByPassword } from './services/admin-login.js';
import { orderInput } from './schemas/order.js';
import { InventoryService } from './services/inventory.js';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 4000;
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
  fallthrough: false,
}));

const authRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many authentication attempts. Try again later.' },
});
app.use('/api/v1/auth/login', authRateLimit);
app.use('/api/v1/auth/register', authRateLimit);

// In-Memory Fallback Store (Synchronized with Prisma schema structure for instant testing)
let memoryCategories = [
  { id: 'cat-1', name: 'Fruits & Vegetables', slug: 'fruits-vegetables', iconName: 'Apple', itemCount: 12 },
  { id: 'cat-2', name: 'Dairy & Eggs', slug: 'dairy-eggs', iconName: 'Milk', itemCount: 8 },
  { id: 'cat-3', name: 'Meat & Seafood', slug: 'meat-seafood', iconName: 'Fish', itemCount: 6 },
  { id: 'cat-4', name: 'Bakery', slug: 'bakery', iconName: 'Bread', itemCount: 6 },
  { id: 'cat-5', name: 'Rice & Grains', slug: 'rice-grains', iconName: 'Wheat', itemCount: 7 },
  { id: 'cat-6', name: 'Pulses & Beans', slug: 'pulses-beans', iconName: 'Layers', itemCount: 5 },
  { id: 'cat-7', name: 'Snacks', slug: 'snacks', iconName: 'Cookie', itemCount: 8 },
  { id: 'cat-8', name: 'Beverages', slug: 'beverages', iconName: 'Coffee', itemCount: 6 },
  { id: 'cat-9', name: 'Breakfast', slug: 'breakfast', iconName: 'Sun', itemCount: 5 },
  { id: 'cat-10', name: 'Frozen Foods', slug: 'frozen-foods', iconName: 'Snowflake', itemCount: 4 },
  { id: 'cat-11', name: 'Cooking Essentials', slug: 'cooking-essentials', iconName: 'Flame', itemCount: 8 },
  { id: 'cat-12', name: 'Spices', slug: 'spices', iconName: 'Sparkles', itemCount: 6 },
  { id: 'cat-13', name: 'Personal Care', slug: 'personal-care', iconName: 'Heart', itemCount: 4 },
  { id: 'cat-14', name: 'Household', slug: 'household', iconName: 'Home', itemCount: 4 },
  { id: 'cat-15', name: 'Baby Products', slug: 'baby-products', iconName: 'Smile', itemCount: 3 },
  { id: 'cat-16', name: 'Pet Supplies', slug: 'pet-supplies', iconName: 'Activity', itemCount: 3 },
];

let memoryProducts = [
  {
    id: 'prod-1',
    sku: 'FH-APP-001',
    name: 'Organic Honeycrisp Mountain Apples',
    slug: 'organic-honeycrisp-mountain-apples',
    categoryId: 'cat-1',
    categoryName: 'Fruits & Vegetables',
    brand: 'Mustang Orchards',
    price: 320,
    originalPrice: 380,
    discountPercent: 15,
    weight: '1 kg (4-5 pcs)',
    stock: 40,
    rating: 4.9,
    reviewCount: 38,
    isOrganic: true,
    isFeatured: true,
    isBestSeller: true,
    description: 'Crisp mountain apples hand-harvested from Mustang orchards.',
    origin: 'Mustang, Nepal',
    imageUrl: 'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?w=600&auto=format&fit=crop',
  },
  {
    id: 'prod-2',
    sku: 'FH-CIT-002',
    name: 'Pokhara Sweet Blood Oranges',
    slug: 'pokhara-sweet-blood-oranges',
    categoryId: 'cat-1',
    categoryName: 'Fruits & Vegetables',
    brand: 'Pokhara Valley Groves',
    price: 240,
    originalPrice: 280,
    discountPercent: 14,
    weight: '1 kg',
    stock: 28,
    rating: 4.8,
    reviewCount: 22,
    isOrganic: true,
    isFeatured: true,
    isBestSeller: false,
    description: 'Sweet crimson-fleshed citrus with rich Vitamin C.',
    origin: 'Pokhara Valley',
    imageUrl: 'https://images.unsplash.com/photo-1557800636-894a64c1696f?w=600&auto=format&fit=crop',
  },
  {
    id: 'prod-3',
    sku: 'FH-MILK-003',
    name: 'Farm Fresh A2 Whole Milk',
    slug: 'farm-fresh-a2-whole-milk',
    categoryId: 'cat-2',
    categoryName: 'Dairy & Eggs',
    brand: 'Himalayan Pastures',
    price: 150,
    originalPrice: 170,
    discountPercent: 11,
    weight: '1 Litre Glass Bottle',
    stock: 35,
    rating: 4.9,
    reviewCount: 67,
    isOrganic: true,
    isFeatured: true,
    isBestSeller: true,
    description: 'Non-homogenized, slow-pasteurized A2 milk with natural cream top.',
    origin: 'Kavre Farm',
    imageUrl: 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=600&auto=format&fit=crop',
  },
  {
    id: 'prod-4',
    sku: 'FH-EGG-004',
    name: 'Pasture-Raised Organic Brown Eggs',
    slug: 'pasture-raised-organic-brown-eggs',
    categoryId: 'cat-2',
    categoryName: 'Dairy & Eggs',
    brand: 'Hillside Free Range',
    price: 360,
    originalPrice: 400,
    discountPercent: 10,
    weight: '12 pcs pack (1 dozen)',
    stock: 50,
    rating: 4.9,
    reviewCount: 88,
    isOrganic: true,
    isFeatured: false,
    isBestSeller: true,
    description: 'Golden yolks from hens roaming freely on natural mountain pastures.',
    origin: 'Lalitpur Hills',
    imageUrl: 'https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?w=600&auto=format&fit=crop',
  },
  {
    id: 'prod-5',
    sku: 'FH-BRD-005',
    name: 'Slow-Fermented Artisanal Sourdough Boule',
    slug: 'slow-fermented-artisanal-sourdough',
    categoryId: 'cat-4',
    categoryName: 'Bakery',
    brand: 'Kathmandu Artisan Bakers',
    price: 290,
    originalPrice: 320,
    discountPercent: 9,
    weight: '750 g Loaf',
    stock: 18,
    rating: 5.0,
    reviewCount: 42,
    isOrganic: true,
    isFeatured: true,
    isBestSeller: false,
    description: 'Naturally leavened sourdough with open crumb and blistering crust.',
    origin: 'Patan Lab',
    imageUrl: 'https://images.unsplash.com/photo-1589367920969-ab8e050bbb04?w=600&auto=format&fit=crop',
  },
];

const { authenticateToken, requireAdmin, requireDeliveryPerson } =
  createAuthMiddleware(prisma, AUTH_SECRET);
app.use('/api/v1/admin', createAdminRouter(prisma, authenticateToken, requireAdmin));
app.use(
  '/api/v1/delivery',
  createDeliveryRouter(prisma, authenticateToken, requireDeliveryPerson),
);
app.use('/api/v1/account', createAccountRouter(prisma, authenticateToken));
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
  items: { include: { product: { include: { category: true } } } },
  address: true,
} satisfies Prisma.OrderInclude;

type OrderRecord = Prisma.OrderGetPayload<{ include: typeof orderInclude }>;

function orderResponse(order: OrderRecord) {
  return {
    id: order.id,
    orderNumber: order.orderNumber,
    items: order.items.map((item) => ({
      quantity: item.quantity,
      product: {
        id: item.product.id,
        name: item.product.name,
        brand: item.product.brand,
        categoryId: item.product.categoryId,
        categoryName: item.product.category.name,
        categorySlug: item.product.category.slug,
        price: Number(item.product.price),
        originalPrice: item.product.originalPrice === null
          ? null
          : Number(item.product.originalPrice),
        rating: Number(item.product.rating),
        reviewCount: item.product.reviewCount,
        description: item.product.description ?? '',
        imageUrl: item.product.imageUrl ?? '',
      },
    })),
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
    paymentMethod: order.paymentMethod,
    paymentStatus: order.paymentStatus,
    subtotal: Number(order.subtotal),
    deliveryFee: Number(order.deliveryFee),
    discount: Number(order.discount),
    tip: Number(order.tip),
    total: Number(order.total),
    createdAt: order.createdAt.toISOString(),
  };
}

// ==================== AUTHENTICATION ROUTES ====================
app.post('/api/v1/auth/register', async (req: Request, res: Response) => {
  const { fullName, email, phone, password } = req.body;

  if (typeof fullName !== 'string' || typeof email !== 'string' || typeof password !== 'string') {
    return res.status(400).json({ error: 'Full name, email and password are required' });
  }

  const normalizedName = fullName.trim();
  const normalizedEmail = normalizeEmail(email);
  const normalizedPhone = normalizePhone(phone);

  if (normalizedName.length === 0 || normalizedName.length > 120) {
    return res.status(400).json({ error: 'Full name must be between 1 and 120 characters' });
  }

  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizedEmail)) {
    return res.status(400).json({ error: 'A valid email address is required' });
  }
  if (phone !== undefined && phone !== null && typeof phone !== 'string') {
    return res.status(400).json({ error: 'Enter a valid phone number' });
  }

  if (password.length < 8 || password.length > 128) {
    return res.status(400).json({ error: 'Password must be between 8 and 128 characters long' });
  }
  if (typeof phone === 'string' && phone.trim().length > 0 &&
      (!normalizedPhone || normalizedPhone.length < 7 || normalizedPhone.length > 30)) {
    return res.status(400).json({ error: 'Enter a valid phone number' });
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
      },
    });
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

    return res.status(201).json({
      message: 'User registered successfully',
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
        where: { role: 'ADMIN', isActive: true },
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
      where: { isActive: true },
      orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
      include: {
        _count: {
          select: { products: { where: { isActive: true } } },
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

app.get('/api/v1/products', async (req: Request, res: Response) => {
  const category = typeof req.query.category === 'string' ? req.query.category : undefined;
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
        where: { OR: [{ id: category }, { slug: category }], isActive: true },
        select: { id: true },
      })
      : null;

    if (category && category !== 'all' && !categoryRecord) {
      return res.json({ data: [], pagination: { total: 0, page, limit } });
    }

    const where: Prisma.ProductWhereInput = {
      isActive: true,
      category: { isActive: true },
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
        include: {
          category: { select: { name: true, slug: true } },
          inventory: { select: { totalStock: true, reservedStock: true } },
        },
      }),
    ]);

    const data = products.map(({ category: productCategory, inventory, ...product }) => {
      const price = Number(product.price);
      return {
        ...product,
        price,
        originalPrice: null,
        discountPercent: 0,
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

app.get('/api/v1/products/:id', async (req: Request, res: Response) => {
  try {
    const product = await prisma.product.findFirst({
      where: {
        OR: [{ id: req.params.id }, { slug: req.params.id }],
        isActive: true,
        category: { isActive: true },
      },
      include: {
        category: { select: { name: true, slug: true } },
        inventory: { select: { totalStock: true, reservedStock: true } },
      },
    });
    if (!product) return res.status(404).json({ error: 'Product not found' });

    const { category: productCategory, inventory, ...fields } = product;
    const price = Number(product.price);
    return res.json({
      data: {
        ...fields,
        price,
        originalPrice: null,
        discountPercent: 0,
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
class OrderStockError extends Error {}

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
      const address = await transaction.address.findFirst({
        where: { id: input.addressId, userId },
      });
      if (!address) throw new Error('Delivery address not found.');

      const productIds = [...new Set(input.items.map((item) => item.productId))];
      const products = await transaction.product.findMany({
        where: { id: { in: productIds }, isActive: true, category: { isActive: true } },
        include: { inventory: true },
      });
      const productsById = new Map(products.map((product) => [product.id, product]));
      const subtotal = input.items.reduce((sum, item) => {
        const product = productsById.get(item.productId);
        if (!product) throw new OrderStockError(`This item is no longer available.`);
        return sum + Number(product.price) * item.quantity;
      }, 0);

      for (const item of input.items) {
        const product = productsById.get(item.productId);
        const inventory = product?.inventory;
        if (!product || !inventory ||
            inventory.totalStock - inventory.reservedStock < item.quantity) {
          throw new OrderStockError(
            `${product?.name ?? 'An item'} does not have enough stock.`,
          );
        }
      }

      const discount = 0;
      const deliveryFee = subtotal >= 1000 ? 0 : 50;
      const total = subtotal + deliveryFee + input.tip;
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
          tip: input.tip,
          total,
          idempotencyKey: input.idempotencyKey,
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
              const product = productsById.get(item.productId)!;
              const price = Number(product.price);
              return {
                productId: product.id,
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
        await inventoryService.reserveStockForOrder(
          transaction,
          input.items,
          created.id,
        );
        await inventoryService.commitReservedStock(
          transaction,
          input.items,
          created.id,
        );
      } catch (error) {
        if (error instanceof Error && error.message.startsWith('INSUFFICIENT_STOCK:')) {
          throw new OrderStockError('An item was just purchased by another customer.');
        }
        throw error;
      }
      return created.id;
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
        include: { items: true },
      });
      if (!existing) return { kind: 'missing' as const };
      if (existing.status !== 'PLACED' && existing.status !== 'CONFIRMED') {
        return { kind: 'not-cancellable' as const };
      }
      const updated = await transaction.order.updateMany({
        where: {
          id: existing.id,
          userId,
          status: { in: ['PLACED', 'CONFIRMED'] },
        },
        data: { status: 'CANCELLED', paymentStatus: 'CANCELLED' },
      });
      if (updated.count !== 1) return { kind: 'not-cancellable' as const };
      for (const item of existing.items) {
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

app.post('/api/v1/coupons/validate', (_req: Request, res: Response) =>
  res.status(410).json({
    valid: false,
    message: 'Promotional discounts are currently unavailable.',
  }),
);

// Health check
app.get('/health', async (_req: Request, res: Response) => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    return res.json({
      status: 'ok',
      service: 'Ram Prasad General Store API',
      database: 'connected',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error('Health check database query failed:', error);
    return res.status(503).json({
      status: 'unavailable',
      service: 'Ram Prasad General Store API',
      database: 'disconnected',
      timestamp: new Date().toISOString(),
    });
  }
});

if (process.env.NODE_ENV !== 'test') {
  app.listen(PORT, () => {
    console.log(`Ram Prasad General Store API running on port ${PORT}`);
  });
}

export default app;
