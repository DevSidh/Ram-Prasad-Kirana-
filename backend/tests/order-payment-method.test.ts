import assert from 'node:assert/strict';
import { orderInput } from '../src/schemas/order.js';

const order = {
  items: [{ productId: 'product-1', quantity: 1 }],
  addressId: 'address-1',
  paymentMethod: 'COD',
};

assert.equal(orderInput.safeParse(order).success, true);

for (const paymentMethod of ['ESEWA', 'KHALTI', 'CARD']) {
  const result = orderInput.safeParse({ ...order, paymentMethod });
  assert.equal(result.success, false, `${paymentMethod} should be rejected`);
  if (!result.success) {
    assert.equal(
      result.error.issues[0].message,
      'Online payment is not available yet. Choose Cash on Delivery.',
    );
  }
}

console.log('Order payment method validation tests passed.');
