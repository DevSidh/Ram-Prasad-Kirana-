CREATE TABLE "WholesaleItem" (
    "id" STRING NOT NULL,
    "sku" STRING NOT NULL,
    "name" STRING NOT NULL,
    "slug" STRING NOT NULL,
    "categoryId" STRING NOT NULL,
    "brand" STRING,
    "price" DECIMAL NOT NULL,
    "stock" INT4 NOT NULL DEFAULT 0,
    "minimumQuantity" INT4 NOT NULL DEFAULT 1,
    "description" STRING,
    "origin" STRING,
    "imageUrl" STRING,
    "imageData" BYTES,
    "imageMimeType" STRING,
    "unitLabel" STRING NOT NULL DEFAULT '1 pc',
    "isActive" BOOL NOT NULL DEFAULT true,
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "WholesaleItem_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "WholesaleItem_sku_key" UNIQUE ("sku"),
    CONSTRAINT "WholesaleItem_slug_key" UNIQUE ("slug"),
    CONSTRAINT "WholesaleItem_categoryId_fkey"
      FOREIGN KEY ("categoryId") REFERENCES "Category" ("id")
      ON DELETE RESTRICT ON UPDATE CASCADE
);

ALTER TABLE "WholesaleItem" SET (schema_locked = false);

INSERT INTO "WholesaleItem" (
    "id", "sku", "name", "slug", "categoryId", "brand", "price", "stock",
    "minimumQuantity", "description", "origin", "imageUrl", "imageData",
    "imageMimeType", "unitLabel", "isActive", "createdAt", "updatedAt"
)
SELECT
    'legacy-wholesale-' || p."id",
    'WHOLESALE-' || p."sku",
    p."name",
    p."slug" || '-wholesale',
    p."categoryId",
    p."brand",
    p."wholesalePrice",
    0,
    LEAST(p."wholesaleMinimumQuantity", 100),
    p."description",
    p."origin",
    p."imageUrl",
    p."imageData",
    p."imageMimeType",
    p."unitLabel",
    p."isActive",
    p."createdAt",
    p."updatedAt"
FROM "Product" AS p
WHERE p."isWholesale" = true
  AND p."wholesalePrice" IS NOT NULL;

ALTER TABLE "CartItem" ALTER COLUMN "productId" DROP NOT NULL;
ALTER TABLE "CartItem" DROP CONSTRAINT IF EXISTS "CartItem_productId_fkey";
ALTER TABLE "CartItem"
ADD CONSTRAINT "CartItem_productId_fkey"
FOREIGN KEY ("productId") REFERENCES "Product" ("id")
ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "CartItem" ADD COLUMN "wholesaleItemId" STRING;
ALTER TABLE "OrderItem" ALTER COLUMN "productId" DROP NOT NULL;
ALTER TABLE "OrderItem" DROP CONSTRAINT IF EXISTS "OrderItem_productId_fkey";
ALTER TABLE "OrderItem"
ADD CONSTRAINT "OrderItem_productId_fkey"
FOREIGN KEY ("productId") REFERENCES "Product" ("id")
ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "OrderItem" ADD COLUMN "wholesaleItemId" STRING;
ALTER TABLE "OrderItem" ADD COLUMN "isWholesale" BOOL NOT NULL DEFAULT false;

UPDATE "CartItem" AS c
SET "wholesaleItemId" = 'legacy-wholesale-' || c."productId",
    "productId" = NULL
WHERE c."isWholesale" = true
  AND c."productId" IN (
    SELECT p."id"
    FROM "Product" AS p
    WHERE p."isWholesale" = true
      AND p."wholesalePrice" IS NOT NULL
  );

UPDATE "CartItem"
SET "isWholesale" = false
WHERE "isWholesale" = true
  AND "wholesaleItemId" IS NULL;

UPDATE "OrderItem" AS oi
SET "isWholesale" = true
WHERE oi."productId" IN (
    SELECT p."id"
    FROM "Product" AS p
    WHERE p."isWholesale" = true
      AND p."wholesalePrice" IS NOT NULL
);

UPDATE "Product"
SET "isWholesale" = false,
    "wholesalePrice" = NULL,
    "wholesaleMinimumQuantity" = 1
WHERE "isWholesale" = true;

CREATE INDEX "WholesaleItem_categoryId_idx" ON "WholesaleItem" ("categoryId");
CREATE INDEX "WholesaleItem_isActive_idx" ON "WholesaleItem" ("isActive");
CREATE INDEX "WholesaleItem_name_idx" ON "WholesaleItem" ("name");
CREATE INDEX "CartItem_wholesaleItemId_idx" ON "CartItem" ("wholesaleItemId");
CREATE INDEX "OrderItem_wholesaleItemId_idx" ON "OrderItem" ("wholesaleItemId");

ALTER TABLE "CartItem"
ADD CONSTRAINT "CartItem_wholesaleItemId_fkey"
FOREIGN KEY ("wholesaleItemId") REFERENCES "WholesaleItem" ("id")
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "OrderItem"
ADD CONSTRAINT "OrderItem_wholesaleItemId_fkey"
FOREIGN KEY ("wholesaleItemId") REFERENCES "WholesaleItem" ("id")
ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "WholesaleItem" SET (schema_locked = true);
