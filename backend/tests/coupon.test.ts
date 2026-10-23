import assert from 'node:assert/strict';
import {
  calculateCouponEligibleSubtotal,
  checkCoupon,
  toPublicCouponOffer,
} from '../src/services/coupon.js';

const baseCoupon = {
  isActive: true,
  discountType: 'PERCENTAGE' as const,
  discountPercent: 15,
  discountAmount: null,
  minOrderAmount: 500,
  maxDiscount: 200,
  usageLimit: 3,
  perUserLimit: 2,
  usedCount: 1,
  expiresAt: new Date('2027-01-01T00:00:00.000Z'),
};
const now = new Date('2026-06-01T00:00:00.000Z');

assert.equal(
  calculateCouponEligibleSubtotal(null, [
    { productId: 'p1', subtotal: 200, isWholesale: false },
    { productId: 'p2', subtotal: 300, isWholesale: false },
    { productId: 'w1', subtotal: 900, isWholesale: true },
  ]),
  500,
);
assert.equal(
  calculateCouponEligibleSubtotal('p2', [
    { productId: 'p1', subtotal: 200, isWholesale: false },
    { productId: 'p2', subtotal: 300, isWholesale: false },
  ]),
  300,
);

assert.deepEqual(checkCoupon(baseCoupon, 1000, now), {
  valid: true,
  discount: 150,
  message: 'Coupon applied successfully.',
});
assert.equal(checkCoupon(baseCoupon, 2000, now).valid, true);
assert.equal(checkCoupon(baseCoupon, 2000, now).discount, 200);
assert.equal(checkCoupon(baseCoupon, 400, now).valid, false);
assert.equal(checkCoupon({ ...baseCoupon, isActive: false }, 1000, now).valid, false);
assert.equal(checkCoupon({ ...baseCoupon, usedCount: 3 }, 1000, now).valid, false);
assert.equal(checkCoupon(baseCoupon, 1000, now, 2).valid, false);
assert.equal(checkCoupon(baseCoupon, 1000, now, 1).valid, true);
assert.equal(
  checkCoupon(
    { ...baseCoupon, assignedUserId: 'customer-1' },
    1000,
    now,
    0,
    'customer-1',
  ).valid,
  true,
);
assert.equal(
  checkCoupon(
    { ...baseCoupon, assignedUserId: 'customer-1' },
    1000,
    now,
    0,
    'customer-2',
  ).valid,
  false,
);
assert.equal(
  checkCoupon({ ...baseCoupon, expiresAt: now }, 1000, now).valid,
  false,
);
assert.equal(
  checkCoupon({
    ...baseCoupon,
    discountType: 'FIXED',
    discountPercent: null,
    discountAmount: 250,
    minOrderAmount: 0,
    maxDiscount: null,
  }, 100, now).discount,
  100,
  'Fixed discounts cannot reduce an order subtotal below zero.',
);
assert.deepEqual(
  toPublicCouponOffer({ ...baseCoupon, id: 'offer-1', code: 'SAVE15' }, now),
  {
    id: 'offer-1',
    enabled: true,
    discountType: 'PERCENTAGE',
    percent: 15,
    maxDiscount: 200,
    amount: null,
    code: 'SAVE15',
    endsAt: '2027-01-01T00:00:00.000Z',
    minOrderAmount: 500,
  },
);
assert.deepEqual(
  toPublicCouponOffer({
    ...baseCoupon,
    discountType: 'FIXED',
    discountPercent: null,
    discountAmount: 50,
    minOrderAmount: 0,
    maxDiscount: null,
    id: 'diwali-offer',
    code: 'DIWALI50',
  }, now),
  {
    id: 'diwali-offer',
    enabled: true,
    discountType: 'FIXED',
    percent: null,
    maxDiscount: null,
    amount: 50,
    code: 'DIWALI50',
    endsAt: '2027-01-01T00:00:00.000Z',
    minOrderAmount: 0,
  },
);
assert.equal(
  toPublicCouponOffer(
    { ...baseCoupon, id: 'expired', code: 'EXPIRED', expiresAt: now },
    now,
  ),
  null,
);
assert.equal(
  toPublicCouponOffer(
    { ...baseCoupon, id: 'used', code: 'USED', usedCount: 3 },
    now,
  ),
  null,
);
assert.equal(
  toPublicCouponOffer(
    {
      ...baseCoupon,
      id: 'assigned',
      code: 'ASSIGNED',
      productId: 'product-1',
      assignedUserId: 'customer-1',
    },
    now,
  ),
  null,
);

console.log('Coupon eligibility, discount, and public-offer tests passed.');
