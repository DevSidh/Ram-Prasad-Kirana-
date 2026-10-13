const cancellableOrderStatuses = new Set([
  'PLACED',
  'CONFIRMED',
  'PROCESSING',
]);
const inactiveDeliveryStatuses = new Set([
  'DECLINED',
  'CANCELLED',
  'FAILED',
]);

export function canCustomerCancelOrder(
  orderStatus: string,
  deliveryStatus: string | null,
): boolean {
  return cancellableOrderStatuses.has(orderStatus) &&
    (deliveryStatus === null || inactiveDeliveryStatuses.has(deliveryStatus));
}
