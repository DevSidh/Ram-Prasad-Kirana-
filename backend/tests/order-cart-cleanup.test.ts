import assert from 'node:assert/strict';
import { orderCartCleanupWhere } from '../src/services/order-cart-cleanup.js';
import { orderInput } from '../src/schemas/order.js';

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
      { wholesaleItemId: 'rice', quantity: 5, isWholesale: true },
    ],
  },
);

const validWholesaleOrder = orderInput.safeParse({
  items: [
    { productId: 'rice-wholesale', quantity: 5, isWholesale: true },
  ],
  addressId: 'address-1',
  paymentMethod: 'COD',
});
assert.equal(validWholesaleOrder.success, true);
assert.equal(orderInput.safeParse({
  items: [
    { productId: 'rice', quantity: 2 },
    { productId: 'rice', quantity: 3 },
  ],
  addressId: 'address-1',
  paymentMethod: 'COD',
}).success, false);

console.log('Order cart snapshot cleanup tests passed.');
