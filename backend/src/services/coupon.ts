export interface CouponForValidation {
  isActive: boolean;
  discountType: 'PERCENTAGE' | 'FIXED';
  discountPercent: number | string | { toNumber(): number } | null;
  discountAmount: number | string | { toNumber(): number } | null;
  minOrderAmount: number | string | { toNumber(): number };
  maxDiscount: number | string | { toNumber(): number } | null;
  usageLimit: number | null;
  perUserLimit?: number | null;
  usedCount: number;
  expiresAt: Date | null;
  productId?: string | null;
  assignedUserId?: string | null;
}

type CouponCheck =
  | { valid: true; discount: number; message: string }
  | { valid: false; discount: 0; message: string };

export function calculateCouponEligibleSubtotal(
  couponProductId: string | null,
  items: readonly {
    productId: string;
    subtotal: number;
    isWholesale: boolean;
  }[],
): number {
  return items.reduce(
    (sum, item) =>
      !item.isWholesale &&
      (couponProductId === null || item.productId === couponProductId)
        ? sum + item.subtotal
        : sum,
    0,
  );
}

interface PublicCouponOfferBase {
  id: string;
  enabled: true;
  code: string;
  endsAt: string | null;
}

export type PublicCouponOffer =
  | (PublicCouponOfferBase & {
      discountType: 'PERCENTAGE';
      percent: number;
      maxDiscount: number;
      amount: null;
      minOrderAmount: number;
    })
  | (PublicCouponOfferBase & {
      discountType: 'FIXED';
      percent: null;
      maxDiscount: null;
      amount: number;
      minOrderAmount: number;
    });

export function toPublicCouponOffer(
  coupon: CouponForValidation & { id: string; code: string },
  now: Date = new Date(),
): PublicCouponOffer | null {
  if (
    !coupon.isActive ||
    coupon.productId != null ||
    coupon.assignedUserId != null ||
    (coupon.expiresAt !== null && coupon.expiresAt <= now) ||
    (coupon.usageLimit !== null && coupon.usedCount >= coupon.usageLimit)
  ) {
    return null;
  }

  const minOrderAmount = numericValue(coupon.minOrderAmount);
  if (minOrderAmount === null || minOrderAmount < 0) return null;

  const base = {
    id: coupon.id,
    enabled: true as const,
    code: coupon.code,
    endsAt: coupon.expiresAt?.toISOString() ?? null,
    minOrderAmount: Math.round(minOrderAmount),
  };
  if (coupon.discountType === 'PERCENTAGE') {
    const percent = numericValue(coupon.discountPercent);
    const maxDiscount = numericValue(coupon.maxDiscount);
    if (
      percent === null ||
      percent <= 0 ||
      percent > 100 ||
      maxDiscount === null ||
      maxDiscount <= 0
    ) {
      return null;
    }
    return {
      ...base,
      discountType: 'PERCENTAGE',
      percent: Math.round(percent),
      maxDiscount: Math.round(maxDiscount),
      amount: null,
    };
  }

  const amount = numericValue(coupon.discountAmount);
  if (amount === null || amount <= 0) return null;
  return {
    ...base,
    discountType: 'FIXED',
    percent: null,
    maxDiscount: null,
    amount: Math.round(amount),
  };
}

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
  userUsedCount = 0,
  userId?: string,
): CouponCheck {
  if (coupon.assignedUserId != null && coupon.assignedUserId !== userId) {
    return {
      valid: false,
      discount: 0,
      message: 'This coupon was issued to a different customer.',
    };
  }
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
  if (
    coupon.perUserLimit != null &&
    userUsedCount >= coupon.perUserLimit
  ) {
    return {
      valid: false,
      discount: 0,
      message: 'You have reached the redemption limit for this coupon.',
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
