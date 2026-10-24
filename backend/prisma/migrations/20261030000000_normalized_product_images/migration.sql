ALTER TABLE "Product" SET (schema_locked = false);
ALTER TABLE "WholesaleItem" SET (schema_locked = false);
ALTER TABLE "StoredImage" SET (schema_locked = false);

ALTER TABLE "Product"
ADD COLUMN "normalizedImageData" BYTES NULL,
ADD COLUMN "normalizedMimeType" STRING NULL;

ALTER TABLE "WholesaleItem"
ADD COLUMN "normalizedImageData" BYTES NULL,
ADD COLUMN "normalizedMimeType" STRING NULL;

ALTER TABLE "StoredImage"
ADD COLUMN "normalizedImageData" BYTES NULL,
ADD COLUMN "normalizedMimeType" STRING NULL;

ALTER TABLE "Product" SET (schema_locked = true);
ALTER TABLE "WholesaleItem" SET (schema_locked = true);
ALTER TABLE "StoredImage" SET (schema_locked = true);
