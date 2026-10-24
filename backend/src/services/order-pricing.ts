interface OrderPricingInput {
  subtotal: number;
  deliveryFee: number;
  discount: number;
  tip: number;
}

export function calculateOrderPricing({
  subtotal,
  deliveryFee,
  discount,
  tip,
}: OrderPricingInput): { tip: number; total: number } {
  return {
    tip,
    total: subtotal + deliveryFee - discount + tip,
  };
}
