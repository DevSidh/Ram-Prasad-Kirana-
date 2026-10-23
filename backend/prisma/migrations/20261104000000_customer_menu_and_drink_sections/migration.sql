ALTER TABLE "Product" SET (schema_locked = false);
ALTER TABLE "StoreSetting" SET (schema_locked = false);

ALTER TABLE "Product" ADD COLUMN "vendingSection" STRING;
ALTER TABLE "StoreSetting"
    ADD COLUMN "customerMenuFeatures" JSONB NOT NULL DEFAULT '{}';

ALTER TABLE "Product" SET (schema_locked = true);
ALTER TABLE "StoreSetting" SET (schema_locked = true);
