import assert from 'node:assert/strict';
import { orderCartCleanupWhere } from '../src/services/order-cart-cleanup.js';

const submittedOrder = [
  { productId: 'apples', quantity: 2, isWholesale: false },
  { productId: 'rice', quantity: 5, isWholesale: true },
];

assert.deepEqual(
  orderCartCleanupWhere('cart-1', submittedOrder),
  {
    cartId: 'cart-1',
    OR: [
      { productId: 'apples', quantity: 2, isWholesale: false },
      { productId: 'rice', quantity: 5, isWholesale: true },
    ],
  },
);

console.log('Order cart snapshot cleanup tests passed.');
