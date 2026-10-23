ALTER TABLE "Coupon" SET (schema_locked = false);

ALTER TABLE "Coupon"
ADD COLUMN "isAnnounced" BOOL NOT NULL DEFAULT false;

UPDATE "Coupon"
SET "isAnnounced" = true
WHERE "isActive" = true
  AND "isDeleted" = false
  AND "productId" IS NULL
  AND "assignedUserId" IS NULL;

UPDATE "Coupon"
SET "code" = 'REMOVED-' || "id"
WHERE "isDeleted" = true;

ALTER TABLE "Coupon" SET (schema_locked = true);
