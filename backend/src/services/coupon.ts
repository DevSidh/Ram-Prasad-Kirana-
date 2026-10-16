export interface CouponForValidation {
  isActive: boolean;
  discountType: 'PERCENTAGE' | 'FIXED';
  discountPercent: number | string | { toNumber(): number } | null;
  discountAmount: number | string | { toNumber(): number } | null;
  minOrderAmount: number | string | { toNumber(): number };
  maxDiscount: number | string | { toNumber(): number } | null;
  usageLimit: number | null;
  usedCount: number;
  expiresAt: Date | null;
}

type CouponCheck =
  | { valid: true; discount: number; message: string }
  | { valid: false; discount: 0; message: string };

function numericValue(
  value: number | string | { toNumber(): number } | null,
): number | null {
  if (value === null) return null;
  const number = typeof value === 'object' ? value.toNumber() : Number(value);
  return Number.isFinite(number) ? number : null;
}

export function checkCoupon(
  coupon: CouponForValidation,
  subtotal: number,
  now: Date = new Date(),
): CouponCheck {
  if (!coupon.isActive) {
    return { valid: false, discount: 0, message: 'This coupon is not active.' };
  }
  if (coupon.expiresAt && coupon.expiresAt <= now) {
    return { valid: false, discount: 0, message: 'This coupon has expired.' };
  }
  if (coupon.usageLimit !== null && coupon.usedCount >= coupon.usageLimit) {
    return {
      valid: false,
      discount: 0,
      message: 'This coupon has reached its redemption limit.',
    };
  }
  const minimum = numericValue(coupon.minOrderAmount);
  if (minimum === null) throw new Error('Coupon minimum order amount is invalid.');
  if (subtotal < minimum) {
    return {
      valid: false,
      discount: 0,
      message: `Add ${Math.ceil(minimum - subtotal)} more to use this coupon.`,
    };
  }

  const value = numericValue(
    coupon.discountType === 'PERCENTAGE'
      ? coupon.discountPercent
      : coupon.discountAmount,
  );
  if (value === null || value <= 0) {
    throw new Error('Coupon discount configuration is invalid.');
  }

  let discount = coupon.discountType === 'PERCENTAGE'
    ? subtotal * value / 100
    : value;
  if (coupon.discountType === 'PERCENTAGE' && coupon.maxDiscount !== null) {
    const maximum = numericValue(coupon.maxDiscount);
    if (maximum === null || maximum < 0) {
      throw new Error('Coupon maximum discount is invalid.');
    }
    discount = Math.min(discount, maximum);
  }
  discount = Math.round(Math.min(Math.max(discount, 0), subtotal) * 100) / 100;
  return { valid: true, discount, message: 'Coupon applied successfully.' };
}
