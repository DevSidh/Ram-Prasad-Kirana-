ALTER TABLE "Product" ADD COLUMN "isWholesale" BOOL NOT NULL DEFAULT false;
ALTER TABLE "Product" ADD COLUMN "wholesalePrice" DECIMAL;
ALTER TABLE "Product" ADD COLUMN "wholesaleMinimumQuantity" INT4 NOT NULL DEFAULT 1;
