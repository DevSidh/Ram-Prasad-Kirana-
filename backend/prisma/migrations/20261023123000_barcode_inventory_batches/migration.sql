ALTER TABLE "Product" SET (schema_locked = false);
ALTER TABLE "Order" SET (schema_locked = false);

ALTER TABLE "Product"
ADD COLUMN "barcode" STRING;

CREATE UNIQUE INDEX "Product_barcode_key" ON "Product"("barcode");

CREATE TABLE "InventoryBatch" (
  "id" STRING NOT NULL,
  "productId" STRING NOT NULL,
  "lotNumber" STRING,
  "manufacturedAt" TIMESTAMP(3),
  "expiresAt" TIMESTAMP(3),
  "noExpiry" BOOL NOT NULL DEFAULT false,
  "datesVerified" BOOL NOT NULL DEFAULT false,
  "receivedQuantity" INT4 NOT NULL,
  "remainingQuantity" INT4 NOT NULL,
  "purchasePrice" DECIMAL(65,30),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "InventoryBatch_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "InventoryBatch" SET (schema_locked = false);

CREATE INDEX "InventoryBatch_productId_expiresAt_idx"
ON "InventoryBatch"("productId", "expiresAt");
CREATE INDEX "InventoryBatch_expiresAt_idx"
ON "InventoryBatch"("expiresAt");

ALTER TABLE "InventoryBatch"
ADD CONSTRAINT "InventoryBatch_productId_fkey"
FOREIGN KEY ("productId") REFERENCES "Product"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "OrderBatchAllocation" (
  "id" STRING NOT NULL,
  "orderId" STRING NOT NULL,
  "productId" STRING NOT NULL,
  "batchId" STRING NOT NULL,
  "quantity" INT4 NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "OrderBatchAllocation_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "OrderBatchAllocation" SET (schema_locked = false);

CREATE INDEX "OrderBatchAllocation_orderId_idx"
ON "OrderBatchAllocation"("orderId");
CREATE INDEX "OrderBatchAllocation_batchId_idx"
ON "OrderBatchAllocation"("batchId");

ALTER TABLE "OrderBatchAllocation"
ADD CONSTRAINT "OrderBatchAllocation_orderId_fkey"
FOREIGN KEY ("orderId") REFERENCES "Order"("id")
ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "OrderBatchAllocation"
ADD CONSTRAINT "OrderBatchAllocation_productId_fkey"
FOREIGN KEY ("productId") REFERENCES "Product"("id")
ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "OrderBatchAllocation"
ADD CONSTRAINT "OrderBatchAllocation_batchId_fkey"
FOREIGN KEY ("batchId") REFERENCES "InventoryBatch"("id")
ON DELETE RESTRICT ON UPDATE CASCADE;

INSERT INTO "InventoryBatch" (
  "id", "productId", "lotNumber", "noExpiry", "datesVerified",
  "receivedQuantity", "remainingQuantity", "createdAt", "updatedAt"
)
SELECT
  gen_random_uuid()::STRING,
  inventory."productId",
  'LEGACY-' || inventory."id",
  false,
  false,
  inventory."totalStock",
  inventory."totalStock",
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
FROM "Inventory" AS inventory
WHERE inventory."totalStock" > 0;

ALTER TABLE "Product" SET (schema_locked = true);
ALTER TABLE "Order" SET (schema_locked = true);
ALTER TABLE "InventoryBatch" SET (schema_locked = true);
ALTER TABLE "OrderBatchAllocation" SET (schema_locked = true);
