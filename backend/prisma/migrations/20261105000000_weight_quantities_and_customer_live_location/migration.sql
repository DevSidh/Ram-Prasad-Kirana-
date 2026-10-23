ALTER TABLE "CartItem" SET (schema_locked = false);
ALTER TABLE "OrderItem" SET (schema_locked = false);
ALTER TABLE "Delivery" SET (schema_locked = false);

ALTER TABLE "CartItem"
ADD COLUMN "weightGrams" INTEGER;

ALTER TABLE "OrderItem"
ADD COLUMN "weightGrams" INTEGER;

ALTER TABLE "Delivery"
ADD COLUMN "customerLatitude" DOUBLE PRECISION,
ADD COLUMN "customerLongitude" DOUBLE PRECISION,
ADD COLUMN "customerLocationUpdatedAt" TIMESTAMP(3);

ALTER TABLE "CartItem" SET (schema_locked = true);
ALTER TABLE "OrderItem" SET (schema_locked = true);
ALTER TABLE "Delivery" SET (schema_locked = true);

UPDATE "Inventory" AS inventory
SET
  "totalStock" = ROUND(
    inventory."totalStock"::numeric
      * SUBSTRING(product."unitLabel" FROM '^[[:space:]]*([0-9]+([.][0-9]+)?)')::numeric
      * CASE
        WHEN product."unitLabel" ~* 'kg[[:space:]]*$' THEN 1000
        ELSE 1
      END
  )::integer,
  "reservedStock" = ROUND(
    inventory."reservedStock"::numeric
      * SUBSTRING(product."unitLabel" FROM '^[[:space:]]*([0-9]+([.][0-9]+)?)')::numeric
      * CASE
        WHEN product."unitLabel" ~* 'kg[[:space:]]*$' THEN 1000
        ELSE 1
      END
  )::integer
FROM "Product" AS product
WHERE product.id = inventory."productId"
  AND product."unitLabel" ~* '^[[:space:]]*[0-9]+([.][0-9]+)?[[:space:]]*(kg|g)[[:space:]]*$';

UPDATE "InventoryBatch" AS batch
SET
  "receivedQuantity" = ROUND(
    batch."receivedQuantity"::numeric
      * SUBSTRING(product."unitLabel" FROM '^[[:space:]]*([0-9]+([.][0-9]+)?)')::numeric
      * CASE
        WHEN product."unitLabel" ~* 'kg[[:space:]]*$' THEN 1000
        ELSE 1
      END
  )::integer,
  "remainingQuantity" = ROUND(
    batch."remainingQuantity"::numeric
      * SUBSTRING(product."unitLabel" FROM '^[[:space:]]*([0-9]+([.][0-9]+)?)')::numeric
      * CASE
        WHEN product."unitLabel" ~* 'kg[[:space:]]*$' THEN 1000
        ELSE 1
      END
  )::integer
FROM "Product" AS product
WHERE product."id" = batch."productId"
  AND product."unitLabel" ~* '^[[:space:]]*[0-9]+([.][0-9]+)?[[:space:]]*(kg|g)[[:space:]]*$';

UPDATE "InventoryTransaction" AS entry
SET
  quantity = ROUND(
    entry.quantity::numeric
      * SUBSTRING(product."unitLabel" FROM '^[[:space:]]*([0-9]+([.][0-9]+)?)')::numeric
      * CASE
        WHEN product."unitLabel" ~* 'kg[[:space:]]*$' THEN 1000
        ELSE 1
      END
  )::integer,
  "balanceAfter" = ROUND(
    entry."balanceAfter"::numeric
      * SUBSTRING(product."unitLabel" FROM '^[[:space:]]*([0-9]+([.][0-9]+)?)')::numeric
      * CASE
        WHEN product."unitLabel" ~* 'kg[[:space:]]*$' THEN 1000
        ELSE 1
      END
  )::integer
FROM "Inventory" AS inventory
JOIN "Product" AS product ON product.id = inventory."productId"
WHERE entry."inventoryId" = inventory.id
  AND product."unitLabel" ~* '^[[:space:]]*[0-9]+([.][0-9]+)?[[:space:]]*(kg|g)[[:space:]]*$';
