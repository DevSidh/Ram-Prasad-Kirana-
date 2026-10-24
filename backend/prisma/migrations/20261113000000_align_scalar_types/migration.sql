SET use_declarative_schema_changer = on;

CREATE TABLE "_migration_int4_preflight" (
    "id" INT4 NOT NULL PRIMARY KEY,
    "valid" BOOL NOT NULL CHECK ("valid")
);
ALTER TABLE "_migration_int4_preflight" SET (schema_locked = false);

INSERT INTO "_migration_int4_preflight" ("id", "valid")
SELECT 1,
    NOT EXISTS (
        SELECT 1 FROM "Product"
        WHERE "lowStockThreshold" < -2147483648
           OR "lowStockThreshold" > 2147483647
    )
    AND NOT EXISTS (
        SELECT 1 FROM "CartItem"
        WHERE "weightGrams" < -2147483648
           OR "weightGrams" > 2147483647
    )
    AND NOT EXISTS (
        SELECT 1 FROM "OrderItem"
        WHERE "weightGrams" < -2147483648
           OR "weightGrams" > 2147483647
    )
    AND NOT EXISTS (
        SELECT 1 FROM "Coupon"
        WHERE "perUserLimit" < -2147483648
           OR "perUserLimit" > 2147483647
    );

DROP TABLE "_migration_int4_preflight";

ALTER TABLE "Product" SET (schema_locked = false);
ALTER TABLE "CartItem" SET (schema_locked = false);
ALTER TABLE "OrderItem" SET (schema_locked = false);
ALTER TABLE "Coupon" SET (schema_locked = false);

ALTER TABLE "Product"
ALTER COLUMN "lowStockThreshold" SET DATA TYPE INT4;
ALTER TABLE "CartItem"
ALTER COLUMN "weightGrams" SET DATA TYPE INT4;
ALTER TABLE "OrderItem"
ALTER COLUMN "weightGrams" SET DATA TYPE INT4;
ALTER TABLE "Coupon"
ALTER COLUMN "perUserLimit" SET DATA TYPE INT4;

ALTER TABLE "Product" SET (schema_locked = true);
ALTER TABLE "CartItem" SET (schema_locked = true);
ALTER TABLE "OrderItem" SET (schema_locked = true);
ALTER TABLE "Coupon" SET (schema_locked = true);
