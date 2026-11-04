-- Additive only. No historical bills or collections are changed.
CREATE TABLE "PosFonepayRequest" (
  "id" STRING NOT NULL PRIMARY KEY,
  "saleId" STRING NOT NULL,
  "reference" STRING NOT NULL,
  "activeKey" STRING,
  "requestedById" STRING NOT NULL,
  "environment" STRING NOT NULL,
  "merchantCode" STRING NOT NULL,
  "merchantName" STRING,
  "currency" STRING NOT NULL DEFAULT 'NPR',
  "amount" DECIMAL(12,2) NOT NULL,
  "billFingerprint" STRING NOT NULL,
  "invoiceNumber" STRING NOT NULL,
  "state" STRING NOT NULL DEFAULT 'CREATING',
  "qrPayload" STRING,
  "expiresAt" TIMESTAMP(3),
  "lastCheckedAt" TIMESTAMP(3),
  "providerTransactionId" STRING,
  "failureCode" STRING,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "PosFonepayRequest_amount_check" CHECK ("amount" > 0 AND "currency" = 'NPR'),
  CONSTRAINT "PosFonepayRequest_state_check" CHECK ("state" IN ('CREATING','READY','PENDING','UNKNOWN','PAID','TEST_VERIFIED','FAILED','EXPIRED','CANCELLED','STALE','REVIEW'))
);
ALTER TABLE "PosFonepayRequest" SET (schema_locked = false);
CREATE UNIQUE INDEX "PosFonepayRequest_reference_key" ON "PosFonepayRequest"("reference");
CREATE UNIQUE INDEX "PosFonepayRequest_activeKey_key" ON "PosFonepayRequest"("activeKey");
CREATE UNIQUE INDEX "PosFonepayRequest_environment_merchantCode_providerTransactionId_key" ON "PosFonepayRequest"("environment", "merchantCode", "providerTransactionId");
CREATE INDEX "PosFonepayRequest_saleId_createdAt_idx" ON "PosFonepayRequest"("saleId", "createdAt");
CREATE INDEX "PosFonepayRequest_state_expiresAt_idx" ON "PosFonepayRequest"("state", "expiresAt");
ALTER TABLE "PosSale" SET (schema_locked = false);
ALTER TABLE "PosFonepayRequest" ADD CONSTRAINT "PosFonepayRequest_saleId_fkey" FOREIGN KEY ("saleId") REFERENCES "PosSale"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "PosSale" SET (schema_locked = true);
ALTER TABLE "PosFonepayRequest" SET (schema_locked = true);
