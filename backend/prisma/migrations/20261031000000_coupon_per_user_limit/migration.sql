ALTER TABLE "Coupon"
ADD COLUMN "perUserLimit" INT8;

CREATE INDEX "Order_userId_couponCode_status_idx"
ON "Order" ("userId", "couponCode", "status");
