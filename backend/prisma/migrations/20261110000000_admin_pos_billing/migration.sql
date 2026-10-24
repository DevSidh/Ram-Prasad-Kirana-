CREATE TYPE "PosShiftStatus" AS ENUM ('OPEN', 'CLOSED');
CREATE TYPE "PosSaleStatus" AS ENUM ('COMPLETED', 'PARTIALLY_REFUNDED', 'REFUNDED', 'CANCELLED');
CREATE TYPE "PosPaymentMethod" AS ENUM ('CASH', 'DIGITAL', 'PENDING');
CREATE TYPE "PosRefundStatus" AS ENUM ('REQUESTED', 'APPROVED', 'REJECTED');
CREATE TYPE "PosCashMovementType" AS ENUM ('CASH_IN', 'CASH_OUT');

CREATE TABLE "PosShift" (
    "id" STRING NOT NULL,
    "cashierId" STRING NOT NULL,
    "status" "PosShiftStatus" NOT NULL DEFAULT 'OPEN',
    "openingCash" DECIMAL(12,2) NOT NULL,
    "expectedClosingCash" DECIMAL(12,2),
    "actualClosingCash" DECIMAL(12,2),
    "openedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "closedAt" TIMESTAMP(3),
    CONSTRAINT "PosShift_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "PosSale" (
    "id" STRING NOT NULL,
    "receiptNumber" STRING NOT NULL,
    "shiftId" STRING NOT NULL,
    "customerName" STRING,
    "customerPhone" STRING,
    "status" "PosSaleStatus" NOT NULL DEFAULT 'COMPLETED',
    "paymentMethod" "PosPaymentMethod" NOT NULL,
    "paymentStatus" "PaymentStatus" NOT NULL DEFAULT 'COMPLETED',
    "subtotal" DECIMAL(12,2) NOT NULL,
    "discount" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "total" DECIMAL(12,2) NOT NULL,
    "refundedAmount" DECIMAL(12,2) NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "PosSale_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "PosSaleItem" (
    "id" STRING NOT NULL,
    "saleId" STRING NOT NULL,
    "productId" STRING,
    "productName" STRING NOT NULL,
    "sku" STRING NOT NULL,
    "quantity" INT4 NOT NULL,
    "weightGrams" INT4,
    "unitPrice" DECIMAL(12,2) NOT NULL,
    "lineTotal" DECIMAL(12,2) NOT NULL,
    CONSTRAINT "PosSaleItem_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "PosHeldSale" (
    "id" STRING NOT NULL,
    "shiftId" STRING NOT NULL,
    "customerName" STRING,
    "customerPhone" STRING,
    "items" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "PosHeldSale_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "PosRefund" (
    "id" STRING NOT NULL,
    "saleId" STRING NOT NULL,
    "requestedById" STRING NOT NULL,
    "resolvedById" STRING,
    "amount" DECIMAL(12,2) NOT NULL,
    "reason" STRING NOT NULL,
    "status" "PosRefundStatus" NOT NULL DEFAULT 'REQUESTED',
    "restockStock" BOOL NOT NULL DEFAULT false,
    "requestedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "resolvedAt" TIMESTAMP(3),
    CONSTRAINT "PosRefund_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "PosCashMovement" (
    "id" STRING NOT NULL,
    "shiftId" STRING NOT NULL,
    "actorId" STRING NOT NULL,
    "type" "PosCashMovementType" NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "note" STRING NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "PosCashMovement_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "PosShift_cashierId_status_idx" ON "PosShift"("cashierId", "status");
CREATE INDEX "PosShift_openedAt_idx" ON "PosShift"("openedAt");
CREATE UNIQUE INDEX "PosSale_receiptNumber_key" ON "PosSale"("receiptNumber");
CREATE INDEX "PosSale_shiftId_createdAt_idx" ON "PosSale"("shiftId", "createdAt");
CREATE INDEX "PosSale_createdAt_status_idx" ON "PosSale"("createdAt", "status");
CREATE INDEX "PosSale_paymentStatus_idx" ON "PosSale"("paymentStatus");
CREATE INDEX "PosSaleItem_saleId_idx" ON "PosSaleItem"("saleId");
CREATE INDEX "PosSaleItem_productId_idx" ON "PosSaleItem"("productId");
CREATE INDEX "PosHeldSale_shiftId_createdAt_idx" ON "PosHeldSale"("shiftId", "createdAt");
CREATE INDEX "PosRefund_status_requestedAt_idx" ON "PosRefund"("status", "requestedAt");
CREATE INDEX "PosRefund_saleId_idx" ON "PosRefund"("saleId");
CREATE INDEX "PosCashMovement_shiftId_createdAt_idx" ON "PosCashMovement"("shiftId", "createdAt");

ALTER TABLE "PosShift" ADD CONSTRAINT "PosShift_cashierId_fkey"
  FOREIGN KEY ("cashierId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "PosSale" ADD CONSTRAINT "PosSale_shiftId_fkey"
  FOREIGN KEY ("shiftId") REFERENCES "PosShift"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "PosSaleItem" ADD CONSTRAINT "PosSaleItem_saleId_fkey"
  FOREIGN KEY ("saleId") REFERENCES "PosSale"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "PosSaleItem" ADD CONSTRAINT "PosSaleItem_productId_fkey"
  FOREIGN KEY ("productId") REFERENCES "Product"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "PosHeldSale" ADD CONSTRAINT "PosHeldSale_shiftId_fkey"
  FOREIGN KEY ("shiftId") REFERENCES "PosShift"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "PosRefund" ADD CONSTRAINT "PosRefund_saleId_fkey"
  FOREIGN KEY ("saleId") REFERENCES "PosSale"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "PosRefund" ADD CONSTRAINT "PosRefund_requestedById_fkey"
  FOREIGN KEY ("requestedById") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "PosRefund" ADD CONSTRAINT "PosRefund_resolvedById_fkey"
  FOREIGN KEY ("resolvedById") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "PosCashMovement" ADD CONSTRAINT "PosCashMovement_shiftId_fkey"
  FOREIGN KEY ("shiftId") REFERENCES "PosShift"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "PosCashMovement" ADD CONSTRAINT "PosCashMovement_actorId_fkey"
  FOREIGN KEY ("actorId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
