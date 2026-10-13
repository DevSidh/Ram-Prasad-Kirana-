import assert from 'node:assert/strict';
import { canCustomerCancelOrder } from '../src/services/order-cancellation.js';

for (const status of ['PLACED', 'CONFIRMED', 'PROCESSING']) {
  assert.equal(canCustomerCancelOrder(status, null), true);
}

assert.equal(canCustomerCancelOrder('PROCESSING', 'DECLINED'), true);
assert.equal(canCustomerCancelOrder('PROCESSING', 'FAILED'), true);
assert.equal(canCustomerCancelOrder('OUT_FOR_DELIVERY', null), false);
assert.equal(canCustomerCancelOrder('PROCESSING', 'ACCEPTED'), false);
assert.equal(canCustomerCancelOrder('PROCESSING', 'PICKED_UP'), false);

console.log('Customer order cancellation eligibility tests passed.');
