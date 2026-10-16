ALTER TABLE "CartItem"
ADD COLUMN "isWholesale" BOOL NOT NULL DEFAULT false;

CREATE TABLE "StoredImage" (
    "id" STRING NOT NULL,
    "imageData" BYTES NOT NULL,
    "mimeType" STRING NOT NULL,
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "StoredImage_pkey" PRIMARY KEY ("id")
);
