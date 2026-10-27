CREATE TABLE "InvoiceSequence" (
  "year" INT4 NOT NULL,
  "nextNumber" INT4 NOT NULL DEFAULT 0,
  "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "InvoiceSequence_pkey" PRIMARY KEY ("year")
);

ALTER TABLE "Order" SET (schema_locked = false);
ALTER TABLE "PosSale" SET (schema_locked = false);
ALTER TABLE "User" SET (schema_locked = false);

ALTER TABLE "Order" ADD COLUMN "invoiceNumber" STRING;
CREATE UNIQUE INDEX "Order_invoiceNumber_key" ON "Order"("invoiceNumber");

ALTER TABLE "PosSale" ADD COLUMN "invoiceNumber" STRING;
CREATE UNIQUE INDEX "PosSale_invoiceNumber_key" ON "PosSale"("invoiceNumber");

CREATE TABLE "PosOfflineStreakPurchase" (
  "id" STRING NOT NULL,
  "invoiceNumber" STRING NOT NULL,
  "userId" STRING NOT NULL,
  "purchaseDate" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "PosOfflineStreakPurchase_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "PosOfflineStreakPurchase_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "PosOfflineStreakPurchase_invoiceNumber_key"
  ON "PosOfflineStreakPurchase"("invoiceNumber");
CREATE INDEX "PosOfflineStreakPurchase_userId_purchaseDate_idx"
  ON "PosOfflineStreakPurchase"("userId", "purchaseDate");

ALTER TABLE "Order" SET (schema_locked = true);
ALTER TABLE "PosSale" SET (schema_locked = true);
ALTER TABLE "User" SET (schema_locked = true);
