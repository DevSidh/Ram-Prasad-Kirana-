ALTER TABLE "PosSale" SET (schema_locked = false);

ALTER TABLE "PosSale"
ADD COLUMN "paidAmount" DECIMAL(12,2) NOT NULL DEFAULT 0;

UPDATE "PosSale"
SET "paidAmount" = "total"
WHERE "paymentStatus" = 'COMPLETED';

CREATE TABLE "PosPaymentCollection" (
    "id" STRING NOT NULL,
    "saleId" STRING NOT NULL,
    "recordedById" STRING NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "method" "PosPaymentMethod" NOT NULL,
    "note" STRING,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "PosPaymentCollection_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "PosPaymentCollection" SET (schema_locked = false);

CREATE INDEX "PosPaymentCollection_saleId_createdAt_idx"
ON "PosPaymentCollection"("saleId", "createdAt");
CREATE INDEX "PosPaymentCollection_createdAt_idx"
ON "PosPaymentCollection"("createdAt");
CREATE INDEX "PosPaymentCollection_recordedById_createdAt_idx"
ON "PosPaymentCollection"("recordedById", "createdAt");

ALTER TABLE "User" SET (schema_locked = false);

ALTER TABLE "PosPaymentCollection"
ADD CONSTRAINT "PosPaymentCollection_saleId_fkey"
FOREIGN KEY ("saleId") REFERENCES "PosSale"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "PosPaymentCollection"
ADD CONSTRAINT "PosPaymentCollection_recordedById_fkey"
FOREIGN KEY ("recordedById") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "PosPaymentCollection" SET (schema_locked = true);
ALTER TABLE "PosSale" SET (schema_locked = true);
ALTER TABLE "User" SET (schema_locked = true);
