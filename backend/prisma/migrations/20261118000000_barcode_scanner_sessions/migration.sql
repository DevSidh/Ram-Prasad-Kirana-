CREATE TABLE "BarcodeScannerSession" (
  "code" STRING NOT NULL,
  "ownerId" STRING NOT NULL,
  "barcode" STRING,
  "expiresAt" TIMESTAMPTZ NOT NULL,
  "connectedAt" TIMESTAMPTZ,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "BarcodeScannerSession_pkey" PRIMARY KEY ("code")
);

ALTER TABLE "BarcodeScannerSession" SET (schema_locked = false);

CREATE INDEX "BarcodeScannerSession_expiresAt_idx"
  ON "BarcodeScannerSession"("expiresAt");
CREATE INDEX "BarcodeScannerSession_ownerId_expiresAt_idx"
  ON "BarcodeScannerSession"("ownerId", "expiresAt");

ALTER TABLE "BarcodeScannerSession" SET (schema_locked = true);
