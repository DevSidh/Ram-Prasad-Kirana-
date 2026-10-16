import assert from 'node:assert/strict';
import express, { type RequestHandler } from 'express';
import type { PrismaClient } from '@prisma/client';
import { createAccountRouter } from '../src/routes/account.js';

let storedCartItems: Array<Record<string, unknown>> = [];
let storedWishlistIds: string[] = [];
const wholesaleItem = {
  id: 'wholesale-1',
  sku: 'WHOLESALE-RICE',
  name: 'Bulk rice',
  categoryId: 'category-1',
  brand: null,
  price: 180,
  stock: 40,
  minimumQuantity: 5,
  description: null,
  origin: null,
  imageUrl: null,
  imageMimeType: null,
  unitLabel: '1 kg',
  isActive: true,
  updatedAt: new Date('2026-01-01T00:00:00.000Z'),
  category: { name: 'Pantry', slug: 'pantry', isActive: true },
};
const product = {
  id: 'product-1',
  sku: 'SKU-1',
  name: 'Apples',
  categoryId: 'category-1',
  brand: null,
  price: 200,
  originalPrice: null,
  isWholesale: false,
  wholesalePrice: null,
  wholesaleMinimumQuantity: 1,
  rating: 5,
  reviewCount: 0,
  description: 'Fresh apples',
  origin: null,
  imageUrl: null,
  imageMimeType: null,
  unitLabel: '1 kg',
  isOrganic: false,
  isFeatured: false,
  isBestSeller: false,
  isActive: true,
  updatedAt: new Date('2026-01-01T00:00:00.000Z'),
  inventory: { totalStock: 10, reservedStock: 0 },
  category: { name: 'Fruit', slug: 'fruit', isActive: true },
};

const transaction = {
  cart: {
    upsert: async () => ({ id: 'cart-1' }),
  },
  cartItem: {
    deleteMany: async () => {
      storedCartItems = [];
    },
    createMany: async ({ data }: { data: Array<Record<string, unknown>> }) => {
      storedCartItems = data;
    },
  },
  wishlist: {
    upsert: async () => ({ id: 'wishlist-1' }),
  },
  wishlistItem: {
    deleteMany: async () => {
      storedWishlistIds = [];
    },
    createMany: async ({
      data,
    }: {
      data: Array<{ productId: string }>;
    }) => {
      storedWishlistIds = data.map((item) => item.productId);
    },
  },
};

const prisma = {
  $transaction: async <T>(callback: (client: typeof transaction) => Promise<T>) =>
    callback(transaction),
  cart: {
    findUnique: async () => ({
      items: storedCartItems.map((item) => {
        const isWholesale = item.isWholesale === true;
        return {
          ...item,
          product: isWholesale ? null : product,
          wholesaleItem: isWholesale ? wholesaleItem : null,
        };
      }),
    }),
  },
  cartItem: transaction.cartItem,
  product: {
    findMany: async ({ where }: { where: { id: { in: string[] } } }) =>
      where.id.in.includes(product.id) ? [product] : [],
  },
  wholesaleItem: {
    findMany: async ({ where }: { where: { id: { in: string[] } } }) =>
      where.id.in.includes(wholesaleItem.id) ? [wholesaleItem] : [],
  },
  wishlist: {
    findUnique: async () => ({
      items: storedWishlistIds.map((productId) => ({ productId })),
    }),
  },
  wishlistItem: transaction.wishlistItem,
  address: {
    findFirst: async () => ({ latitude: null, longitude: null }),
  },
} as unknown as PrismaClient;

const authenticate: RequestHandler = (req, res, next) => {
  const userId = req.header('x-test-user');
  if (userId) res.locals.authenticatedUserId = userId;
  next();
};

const app = express();
app.use(express.json());
app.use('/account', createAccountRouter(prisma, authenticate));

async function run(): Promise<void> {
  const server = app.listen(0);
  try {
    await new Promise<void>((resolve) => server.once('listening', resolve));
    const address = server.address();
    assert(address && typeof address !== 'string');
    const baseUrl = `http://127.0.0.1:${address.port}/account`;
    const headers = {
      'content-type': 'application/json',
      'x-test-user': 'customer-1',
    };

    const unauthenticated = await fetch(`${baseUrl}/cart`);
    assert.equal(unauthenticated.status, 401);

    const initialCart = await fetch(`${baseUrl}/cart`, { headers });
    assert.deepEqual(await initialCart.json(), { items: [] });

    const saveCart = await fetch(`${baseUrl}/cart`, {
      method: 'PUT',
      headers,
      body: JSON.stringify({
        items: [{ productId: 'product-1', quantity: 2, isWholesale: false }],
      }),
    });
    assert.equal(saveCart.status, 204);
    assert.equal(storedCartItems.length, 1);
    assert.equal(storedCartItems[0].productId, 'product-1');
    assert.equal(storedCartItems[0].quantity, 2);
    assert.equal(storedCartItems[0].isWholesale, false);
    const loadedRetailCart = await fetch(`${baseUrl}/cart`, { headers });
    const retailCart = await loadedRetailCart.json() as {
      items: Array<{ product: { id: string }; isWholesale: boolean }>;
    };
    assert.equal(retailCart.items.length, 1);
    assert.equal(retailCart.items[0]?.product.id, 'product-1');
    assert.equal(retailCart.items[0]?.isWholesale, false);

    const saveWholesaleCart = await fetch(`${baseUrl}/cart`, {
      method: 'PUT',
      headers,
      body: JSON.stringify({
        items: [
          { productId: 'wholesale-1', quantity: 5, isWholesale: true },
        ],
      }),
    });
    assert.equal(saveWholesaleCart.status, 204);
    assert.equal(storedCartItems[0].productId, null);
    assert.equal(storedCartItems[0].wholesaleItemId, 'wholesale-1');
    const loadedWholesaleCart = await fetch(`${baseUrl}/cart`, { headers });
    assert.deepEqual(await loadedWholesaleCart.json(), {
      items: [
        {
          product: {
            id: 'wholesale-1',
            sku: 'WHOLESALE-RICE',
            name: 'Bulk rice',
            categoryId: 'category-1',
            categoryName: 'Pantry',
            categorySlug: 'pantry',
            brand: null,
            price: 180,
            originalPrice: null,
            discountPercent: 0,
            unitLabel: '1 kg',
            stock: 40,
            rating: 0,
            reviewCount: 0,
            isOrganic: false,
            isFeatured: false,
            isBestSeller: false,
            isWholesale: true,
            wholesalePrice: 180,
            wholesaleMinimumQuantity: 5,
            description: '',
            origin: null,
            imageUrl: '',
          },
          quantity: 5,
          isWholesale: true,
        },
      ],
    });

    const saveWishlist = await fetch(`${baseUrl}/wishlist`, {
      method: 'PUT',
      headers,
      body: JSON.stringify({ productIds: ['product-1'] }),
    });
    assert.equal(saveWishlist.status, 204);
    assert.deepEqual(storedWishlistIds, ['product-1']);

    const loadWishlist = await fetch(`${baseUrl}/wishlist`, { headers });
    assert.deepEqual(await loadWishlist.json(), {
      productIds: ['product-1'],
    });

    const quoteWithoutMapPin = await fetch(`${baseUrl}/delivery-quote`, {
      method: 'POST',
      headers,
      body: JSON.stringify({ addressId: 'address-1' }),
    });
    assert.equal(quoteWithoutMapPin.status, 200);
    assert.deepEqual(await quoteWithoutMapPin.json(), { deliveryFee: 40 });
    console.log('Account cart and wishlist persistence tests passed.');
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
    });
  }
}

run().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
