ALTER TABLE "PosSale" SET (schema_locked = false);

ALTER TABLE "PosSale"
ADD COLUMN "vatRate" DECIMAL(6, 2) NOT NULL DEFAULT 0,
ADD COLUMN "vatAmount" DECIMAL(12, 2) NOT NULL DEFAULT 0;

ALTER TABLE "PosSale" SET (schema_locked = true);
