ALTER TABLE "Product" SET (schema_locked = false);

ALTER TABLE "Product"
ADD COLUMN "isVendingDrink" BOOL NOT NULL DEFAULT false;

ALTER TABLE "Product" SET (schema_locked = true);
