CREATE TYPE "SupplierPurchaseBillStatus" AS ENUM ('RECEIVED');

CREATE TABLE "SupplierPurchaseBill" (
    "id" STRING NOT NULL,
    "supplierName" STRING NOT NULL,
    "supplierPhone" STRING,
    "invoiceNumber" STRING NOT NULL,
    "invoiceDate" TIMESTAMP(3) NOT NULL,
    "deliveryPerson" STRING,
    "notes" STRING,
    "totalCost" DECIMAL NOT NULL,
    "status" "SupplierPurchaseBillStatus" NOT NULL DEFAULT 'RECEIVED',
    "createdById" STRING,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SupplierPurchaseBill_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "SupplierPurchaseBillItem" (
    "id" STRING NOT NULL,
    "billId" STRING NOT NULL,
    "productId" STRING NOT NULL,
    "name" STRING NOT NULL,
    "sku" STRING NOT NULL,
    "unitLabel" STRING NOT NULL,
    "quantity" DECIMAL NOT NULL,
    "unitCost" DECIMAL NOT NULL,
    "lineTotal" DECIMAL NOT NULL,

    CONSTRAINT "SupplierPurchaseBillItem_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "SupplierPurchaseBill" SET (schema_locked = false);
ALTER TABLE "SupplierPurchaseBillItem" SET (schema_locked = false);

CREATE INDEX "SupplierPurchaseBill_invoiceDate_idx" ON "SupplierPurchaseBill"("invoiceDate");
CREATE INDEX "SupplierPurchaseBill_createdAt_idx" ON "SupplierPurchaseBill"("createdAt");
CREATE INDEX "SupplierPurchaseBill_supplierName_idx" ON "SupplierPurchaseBill"("supplierName");
CREATE UNIQUE INDEX "SupplierPurchaseBill_supplierName_invoiceNumber_key" ON "SupplierPurchaseBill"("supplierName", "invoiceNumber");
CREATE INDEX "SupplierPurchaseBillItem_billId_idx" ON "SupplierPurchaseBillItem"("billId");
CREATE INDEX "SupplierPurchaseBillItem_productId_idx" ON "SupplierPurchaseBillItem"("productId");

ALTER TABLE "User" SET (schema_locked = false);
ALTER TABLE "Product" SET (schema_locked = false);

ALTER TABLE "SupplierPurchaseBill"
ADD CONSTRAINT "SupplierPurchaseBill_createdById_fkey"
FOREIGN KEY ("createdById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "SupplierPurchaseBillItem"
ADD CONSTRAINT "SupplierPurchaseBillItem_billId_fkey"
FOREIGN KEY ("billId") REFERENCES "SupplierPurchaseBill"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "SupplierPurchaseBillItem"
ADD CONSTRAINT "SupplierPurchaseBillItem_productId_fkey"
FOREIGN KEY ("productId") REFERENCES "Product"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "SupplierPurchaseBill" SET (schema_locked = true);
ALTER TABLE "SupplierPurchaseBillItem" SET (schema_locked = true);
ALTER TABLE "User" SET (schema_locked = true);
ALTER TABLE "Product" SET (schema_locked = true);
