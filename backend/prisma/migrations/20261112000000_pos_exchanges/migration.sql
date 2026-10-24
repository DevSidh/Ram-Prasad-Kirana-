CREATE TYPE "PosExchangeStatus" AS ENUM (
    'COMPLETED',
    'REFUND_REQUESTED',
    'REFUND_APPROVED',
    'REFUND_REJECTED'
);

CREATE TYPE "PosExchangeItemType" AS ENUM ('RETURN', 'REPLACEMENT');

CREATE TABLE "PosExchange" (
    "id" STRING NOT NULL,
    "idempotencyKey" STRING NOT NULL,
    "saleId" STRING NOT NULL,
    "cashierId" STRING NOT NULL,
    "shiftId" STRING NOT NULL,
    "resolvedById" STRING,
    "returnedCredit" DECIMAL(12,2) NOT NULL,
    "replacementTotal" DECIMAL(12,2) NOT NULL,
    "difference" DECIMAL(12,2) NOT NULL,
    "paymentMethod" "PosPaymentMethod",
    "refundPaymentMethod" "PosPaymentMethod",
    "status" "PosExchangeStatus" NOT NULL DEFAULT 'COMPLETED',
    "restockReturnedItems" BOOL NOT NULL DEFAULT true,
    "reason" STRING,
    "requestedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "resolvedAt" TIMESTAMP(3),
    CONSTRAINT "PosExchange_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "PosExchangeItem" (
    "id" STRING NOT NULL,
    "exchangeId" STRING NOT NULL,
    "saleItemId" STRING,
    "productId" STRING,
    "type" "PosExchangeItemType" NOT NULL,
    "productName" STRING NOT NULL,
    "sku" STRING NOT NULL,
    "quantity" INT4 NOT NULL,
    "weightGrams" INT4,
    "unitPrice" DECIMAL(12,2) NOT NULL,
    "lineTotal" DECIMAL(12,2) NOT NULL,
    CONSTRAINT "PosExchangeItem_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "PosExchange_idempotencyKey_key"
    ON "PosExchange"("idempotencyKey");
CREATE INDEX "PosExchange_saleId_requestedAt_idx"
    ON "PosExchange"("saleId", "requestedAt");
CREATE INDEX "PosExchange_status_requestedAt_idx"
    ON "PosExchange"("status", "requestedAt");
CREATE INDEX "PosExchange_cashierId_requestedAt_idx"
    ON "PosExchange"("cashierId", "requestedAt");
CREATE INDEX "PosExchange_shiftId_idx" ON "PosExchange"("shiftId");
CREATE INDEX "PosExchangeItem_exchangeId_idx"
    ON "PosExchangeItem"("exchangeId");
CREATE INDEX "PosExchangeItem_saleItemId_idx"
    ON "PosExchangeItem"("saleItemId");
CREATE INDEX "PosExchangeItem_productId_idx"
    ON "PosExchangeItem"("productId");

ALTER TABLE "PosExchange"
    ADD CONSTRAINT "PosExchange_saleId_fkey"
    FOREIGN KEY ("saleId") REFERENCES "PosSale"("id")
    ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "PosExchange"
    ADD CONSTRAINT "PosExchange_cashierId_fkey"
    FOREIGN KEY ("cashierId") REFERENCES "User"("id")
    ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "PosExchange"
    ADD CONSTRAINT "PosExchange_shiftId_fkey"
    FOREIGN KEY ("shiftId") REFERENCES "PosShift"("id")
    ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "PosExchange"
    ADD CONSTRAINT "PosExchange_resolvedById_fkey"
    FOREIGN KEY ("resolvedById") REFERENCES "User"("id")
    ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "PosExchangeItem"
    ADD CONSTRAINT "PosExchangeItem_exchangeId_fkey"
    FOREIGN KEY ("exchangeId") REFERENCES "PosExchange"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "PosExchangeItem"
    ADD CONSTRAINT "PosExchangeItem_saleItemId_fkey"
    FOREIGN KEY ("saleItemId") REFERENCES "PosSaleItem"("id")
    ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "PosExchangeItem"
    ADD CONSTRAINT "PosExchangeItem_productId_fkey"
    FOREIGN KEY ("productId") REFERENCES "Product"("id")
    ON DELETE SET NULL ON UPDATE CASCADE;
