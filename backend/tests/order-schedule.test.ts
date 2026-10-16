import assert from 'node:assert/strict';
import { orderInput } from '../src/schemas/order.js';

const validOrder = {
  items: [{ productId: 'product-1', quantity: 1 }],
  addressId: 'address-1',
  paymentMethod: 'COD',
};

assert.equal(
  orderInput.safeParse({
    ...validOrder,
    scheduledDeliveryAt: '2026-10-18T12:00:00.000Z',
  }).success,
  true,
);
assert.equal(
  orderInput.safeParse({
    ...validOrder,
    scheduledDeliveryAt: 'not-a-date',
  }).success,
  false,
);

console.log('Order delivery schedule validation tests passed.');
