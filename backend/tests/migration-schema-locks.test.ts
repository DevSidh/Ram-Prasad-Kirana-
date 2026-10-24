import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const migrationsRoot = resolve(
  dirname(fileURLToPath(import.meta.url)),
  '../prisma/migrations',
);

function migration(name: string): string {
  return readFileSync(resolve(migrationsRoot, name, 'migration.sql'), 'utf8')
    .replace(/\r\n/g, '\n');
}

function assertOrder(sql: string, ...statements: string[]): void {
  let position = -1;
  for (const statement of statements) {
    const nextPosition = sql.indexOf(statement, position + 1);
    assert.notEqual(nextPosition, -1, `Missing or out-of-order SQL: ${statement}`);
    position = nextPosition;
  }
}

assertOrder(
  migration('20261009000000_password_reset_otp'),
  'ALTER TABLE "PasswordResetOtp" SET (schema_locked = false)',
  'CREATE INDEX "PasswordResetOtp_expiresAt_idx"',
  'ALTER TABLE "PasswordResetOtp" SET (schema_locked = true)',
);

assertOrder(
  migration('20261011000000_device_push_tokens'),
  'ALTER TABLE "DeviceToken" SET (schema_locked = false)',
  'CREATE UNIQUE INDEX "DeviceToken_token_key"',
  'ALTER TABLE "DeviceToken" SET (schema_locked = true)',
);

assertOrder(
  migration('20261012000000_delivery_staff_panel'),
  'ALTER TABLE "DeliveryStatusHistory" SET (schema_locked = false)',
  'CREATE INDEX IF NOT EXISTS "DeliveryStatusHistory_deliveryId_idx"',
  'ADD CONSTRAINT IF NOT EXISTS "DeliveryStatusHistory_deliveryId_fkey"',
  'ALTER TABLE "DeliveryStatusHistory" SET (schema_locked = true)',
);

assertOrder(
  migration('20261024000000_separate_wholesale_catalog'),
  'ALTER TABLE "Product" SET (schema_locked = false)',
  'ALTER TABLE "CartItem" DROP CONSTRAINT',
  'ALTER TABLE "Product" SET (schema_locked = true)',
);

assertOrder(
  migration('20261025000000_product_vending_drink'),
  'ALTER TABLE "Product" SET (schema_locked = false)',
  'ADD COLUMN "isVendingDrink"',
  'ALTER TABLE "Product" SET (schema_locked = true)',
);

assertOrder(
  migration('20261026000000_email_verification'),
  'ALTER TABLE "EmailVerificationOtp" SET (schema_locked = false)',
  'CREATE INDEX "EmailVerificationOtp_expiresAt_idx"',
  'ALTER TABLE "EmailVerificationOtp" SET (schema_locked = true)',
);

const normalizedImages = migration('20261030000000_normalized_product_images');
for (const table of ['Product', 'WholesaleItem', 'StoredImage']) {
  assertOrder(
    normalizedImages,
    `ALTER TABLE "${table}" SET (schema_locked = false)`,
    `ALTER TABLE "${table}"`,
    `ALTER TABLE "${table}" SET (schema_locked = true)`,
  );
}

assertOrder(
  migration('20261031000000_coupon_per_user_limit'),
  'ALTER TABLE "Order" SET (schema_locked = false)',
  'CREATE INDEX "Order_userId_couponCode_status_idx"',
  'ALTER TABLE "Order" SET (schema_locked = true)',
);

const billing = migration('20261110000000_admin_pos_billing');
for (const table of [
  'PosShift',
  'PosSale',
  'PosSaleItem',
  'PosHeldSale',
  'PosRefund',
  'PosCashMovement',
  'User',
  'Product',
]) {
  assert.ok(
    billing.includes(`ALTER TABLE "${table}" SET (schema_locked = false)`),
    `${table} must be unlocked before POS billing DDL`,
  );
  assert.ok(
    billing.includes(`ALTER TABLE "${table}" SET (schema_locked = true)`),
    `${table} must be re-locked after POS billing DDL`,
  );
}
assertOrder(
  billing,
  'ALTER TABLE "User" SET (schema_locked = false)',
  'ALTER TABLE "PosShift" ADD CONSTRAINT',
  'ALTER TABLE "Product" SET (schema_locked = true)',
);

const exchanges = migration('20261112000000_pos_exchanges');
for (const table of [
  'PosExchange',
  'PosExchangeItem',
  'User',
  'Product',
  'PosSale',
  'PosShift',
  'PosSaleItem',
]) {
  assert.ok(
    exchanges.includes(`ALTER TABLE "${table}" SET (schema_locked = false)`),
    `${table} must be unlocked before POS exchange DDL`,
  );
  assert.ok(
    exchanges.includes(`ALTER TABLE "${table}" SET (schema_locked = true)`),
    `${table} must be re-locked after POS exchange DDL`,
  );
}
assertOrder(
  exchanges,
  'ALTER TABLE "User" SET (schema_locked = false)',
  `ALTER TABLE "PosExchange"
    ADD CONSTRAINT`,
  'ALTER TABLE "PosSaleItem" SET (schema_locked = true)',
);

const scalarAlignment = migration('20261113000000_align_scalar_types');
for (const [table, column] of [
  ['Product', 'lowStockThreshold'],
  ['CartItem', 'weightGrams'],
  ['OrderItem', 'weightGrams'],
  ['Coupon', 'perUserLimit'],
]) {
  const rangeGuard = new RegExp(
    `SELECT 1 FROM "${table}"\\s+WHERE "${column}" < -2147483648\\s+OR "${column}" > 2147483647`,
  );
  assert.match(
    scalarAlignment,
    rangeGuard,
    `${table}.${column} must reject values outside the signed INT4 range`,
  );
}
assertOrder(
  scalarAlignment,
  'INSERT INTO "_migration_int4_preflight"',
  'DROP TABLE "_migration_int4_preflight"',
  'ALTER TABLE "Product" SET (schema_locked = false)',
  'ALTER TABLE "Product"\nALTER COLUMN "lowStockThreshold" SET DATA TYPE INT4',
  'ALTER TABLE "Coupon" SET (schema_locked = true)',
);

console.log('Migration schema-lock and range-guard regression tests passed.');
