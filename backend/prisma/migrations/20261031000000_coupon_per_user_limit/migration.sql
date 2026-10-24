ALTER TABLE "Coupon"
ADD COLUMN "perUserLimit" INT8;

ALTER TABLE "Order" SET (schema_locked = false);

CREATE INDEX "Order_userId_couponCode_status_idx"
ON "Order" ("userId", "couponCode", "status");

ALTER TABLE "Order" SET (schema_locked = true);
