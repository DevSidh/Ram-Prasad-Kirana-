ALTER TABLE "Product" SET (schema_locked = false);
ALTER TABLE "Coupon" SET (schema_locked = false);
ALTER TABLE "User" SET (schema_locked = false);

ALTER TABLE "Product"
ADD COLUMN "imageUrls" JSONB NOT NULL DEFAULT '[]'::JSONB;

ALTER TABLE "Coupon"
ADD COLUMN "productId" STRING,
ADD COLUMN "assignedUserId" STRING;

CREATE INDEX "Coupon_productId_idx" ON "Coupon"("productId");
CREATE INDEX "Coupon_assignedUserId_idx" ON "Coupon"("assignedUserId");

ALTER TABLE "Coupon"
ADD CONSTRAINT "Coupon_productId_fkey"
FOREIGN KEY ("productId") REFERENCES "Product"("id")
ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "Coupon"
ADD CONSTRAINT "Coupon_assignedUserId_fkey"
FOREIGN KEY ("assignedUserId") REFERENCES "User"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Product" SET (schema_locked = true);
ALTER TABLE "Coupon" SET (schema_locked = true);
ALTER TABLE "User" SET (schema_locked = true);
