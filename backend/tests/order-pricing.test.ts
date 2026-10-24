import assert from 'node:assert/strict';
import { calculateOrderPricing } from '../src/services/order-pricing.js';

const pricing = calculateOrderPricing({
  subtotal: 1000,
  deliveryFee: 50,
  discount: 100,
  tip: 125,
});

assert.deepEqual(pricing, { tip: 125, total: 1075 });
console.log('Order pricing preserves tips in the amount due.');
