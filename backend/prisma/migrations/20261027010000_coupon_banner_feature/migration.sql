ALTER TABLE "Coupon" SET (schema_locked = false);

ALTER TABLE "Coupon"
ADD COLUMN "isBannerFeatured" BOOLEAN NOT NULL DEFAULT false;

CREATE UNIQUE INDEX "Coupon_single_banner_featured"
ON "Coupon" ("isBannerFeatured")
WHERE "isBannerFeatured" = true AND "isDeleted" = false;

UPDATE "Coupon"
SET "isBannerFeatured" = true
WHERE "id" = (
  SELECT "id"
  FROM "Coupon"
  WHERE "code" = 'DIWALI50'
    AND "isActive" = true
    AND "isDeleted" = false
    AND "productId" IS NULL
    AND "assignedUserId" IS NULL
  ORDER BY "createdAt" DESC
  LIMIT 1
);

ALTER TABLE "Coupon" SET (schema_locked = true);
