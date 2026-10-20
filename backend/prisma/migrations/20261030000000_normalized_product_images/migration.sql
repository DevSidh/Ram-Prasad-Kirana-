ALTER TABLE "Product"
ADD COLUMN "normalizedImageData" BYTES NULL,
ADD COLUMN "normalizedMimeType" STRING NULL;

ALTER TABLE "WholesaleItem"
ADD COLUMN "normalizedImageData" BYTES NULL,
ADD COLUMN "normalizedMimeType" STRING NULL;

ALTER TABLE "StoredImage"
ADD COLUMN "normalizedImageData" BYTES NULL,
ADD COLUMN "normalizedMimeType" STRING NULL;
