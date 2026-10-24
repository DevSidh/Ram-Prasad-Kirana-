ALTER TABLE "SupplierPurchaseBill" SET (schema_locked = false);

ALTER TABLE "SupplierPurchaseBill"
ADD COLUMN "photoData" BYTES,
ADD COLUMN "photoMimeType" STRING;

ALTER TABLE "SupplierPurchaseBill" SET (schema_locked = true);
