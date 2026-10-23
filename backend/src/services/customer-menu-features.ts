export const CUSTOMER_MENU_FEATURE_KEYS = [
  'orders',
  'addresses',
  'savedItems',
  'buyingStreak',
  'appearance',
  'language',
  'payments',
  'notifications',
  'notificationPreferences',
  'coupons',
  'help',
  'legal',
  'deleteAccount',
] as const;

export type CustomerMenuFeatures = Record<
  (typeof CUSTOMER_MENU_FEATURE_KEYS)[number],
  boolean
>;

export function normalizeCustomerMenuFeatures(value: unknown): CustomerMenuFeatures {
  const settings =
    typeof value === 'object' && value !== null && !Array.isArray(value)
      ? value as Record<string, unknown>
      : {};
  return Object.fromEntries(
    CUSTOMER_MENU_FEATURE_KEYS.map((key) => [
      key,
      typeof settings[key] === 'boolean' ? settings[key] : true,
    ]),
  ) as CustomerMenuFeatures;
}
