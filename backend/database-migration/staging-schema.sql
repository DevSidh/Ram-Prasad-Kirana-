-- LOSSLESS STAGING ONLY. Not compatible with the current application runtime.
-- Foreign keys must be enabled by the importing connection.
CREATE TABLE "User" (
  "id" TEXT NOT NULL,
  "userNumber" INTEGER NOT NULL,
  "name" TEXT NOT NULL,
  "email" TEXT NOT NULL,
  "phone" TEXT,
  "avatarUrl" TEXT,
  "avatarData" BLOB,
  "avatarMimeType" TEXT,
  "passwordHash" TEXT NOT NULL,
  "role" TEXT NOT NULL DEFAULT 'CUSTOMER' CHECK ("role" IN ('CUSTOMER', 'ADMIN', 'DELIVERY_PERSON', 'BILLING_STAFF')),
  "isActive" INTEGER NOT NULL DEFAULT 1 CHECK ("isActive" IN (0, 1)),
  "emailVerified" INTEGER NOT NULL DEFAULT 1 CHECK ("emailVerified" IN (0, 1)),
  "phoneVerified" INTEGER NOT NULL DEFAULT 0 CHECK ("phoneVerified" IN (0, 1)),
  "tokenVersion" INTEGER NOT NULL DEFAULT '0' CHECK ("tokenVersion" BETWEEN -2147483648 AND 2147483647),
  "isAvailable" INTEGER NOT NULL DEFAULT 1 CHECK ("isAvailable" IN (0, 1)),
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  UNIQUE ("userNumber"),
  UNIQUE ("email"),
  UNIQUE ("phone")
);

CREATE INDEX "User_role_idx" ON "User" ("role");

CREATE INDEX "User_createdAt_idx" ON "User" ("createdAt");

CREATE TABLE "BuyingStreakPurchaseDay" (
  "id" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "dayKey" TEXT NOT NULL,
  "createdAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  UNIQUE ("userId", "dayKey"),
  FOREIGN KEY ("userId") REFERENCES "User" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE TABLE "InvoiceSequence" (
  "year" INTEGER NOT NULL CHECK ("year" BETWEEN -2147483648 AND 2147483647),
  "nextNumber" INTEGER NOT NULL DEFAULT '0' CHECK ("nextNumber" BETWEEN -2147483648 AND 2147483647),
  "updatedAt" TEXT NOT NULL,
  PRIMARY KEY ("year")
);

CREATE TABLE "BarcodeScannerSession" (
  "code" TEXT NOT NULL,
  "ownerId" TEXT NOT NULL,
  "barcode" TEXT,
  "expiresAt" TEXT NOT NULL,
  "connectedAt" TEXT,
  "createdAt" TEXT NOT NULL,
  PRIMARY KEY ("code")
);

CREATE INDEX "BarcodeScannerSession_expiresAt_idx" ON "BarcodeScannerSession" ("expiresAt");

CREATE INDEX "BarcodeScannerSession_ownerId_expiresAt_idx" ON "BarcodeScannerSession" ("ownerId", "expiresAt");

CREATE TABLE "BuyingStreakRewardConfig" (
  "id" TEXT NOT NULL,
  "day" INTEGER NOT NULL CHECK ("day" BETWEEN -2147483648 AND 2147483647),
  "title" TEXT NOT NULL,
  "description" TEXT NOT NULL,
  "couponId" TEXT,
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  UNIQUE ("day"),
  FOREIGN KEY ("couponId") REFERENCES "Coupon" ("id") ON DELETE SET NULL ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE TABLE "BuyingStreakRewardProgress" (
  "id" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "day" INTEGER NOT NULL CHECK ("day" BETWEEN -2147483648 AND 2147483647),
  "title" TEXT NOT NULL,
  "description" TEXT NOT NULL,
  "couponTemplateId" TEXT,
  "couponId" TEXT,
  "unlockedAt" TEXT NOT NULL,
  "claimedAt" TEXT,
  PRIMARY KEY ("id"),
  UNIQUE ("userId", "day"),
  UNIQUE ("couponId"),
  FOREIGN KEY ("userId") REFERENCES "User" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY ("couponTemplateId") REFERENCES "Coupon" ("id") ON DELETE SET NULL ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY ("couponId") REFERENCES "Coupon" ("id") ON DELETE SET NULL ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "BuyingStreakRewardProgress_userId_claimedAt_idx" ON "BuyingStreakRewardProgress" ("userId", "claimedAt");

CREATE TABLE "CustomerRemovalAudit" (
  "id" TEXT NOT NULL,
  "customerId" TEXT NOT NULL,
  "customerDisplayId" INTEGER NOT NULL,
  "removedById" TEXT NOT NULL,
  "removedAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  FOREIGN KEY ("customerId") REFERENCES "User" ("id") ON DELETE RESTRICT ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY ("removedById") REFERENCES "User" ("id") ON DELETE RESTRICT ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "CustomerRemovalAudit_removedAt_idx" ON "CustomerRemovalAudit" ("removedAt");

CREATE INDEX "CustomerRemovalAudit_customerId_removedAt_idx" ON "CustomerRemovalAudit" ("customerId", "removedAt");

CREATE TABLE "PasswordResetOtp" (
  "email" TEXT NOT NULL,
  "otpHash" TEXT NOT NULL,
  "expiresAt" TEXT NOT NULL,
  "attempts" INTEGER NOT NULL DEFAULT '0' CHECK ("attempts" BETWEEN -2147483648 AND 2147483647),
  "createdAt" TEXT NOT NULL,
  PRIMARY KEY ("email")
);

CREATE INDEX "PasswordResetOtp_expiresAt_idx" ON "PasswordResetOtp" ("expiresAt");

CREATE TABLE "EmailVerificationOtp" (
  "email" TEXT NOT NULL,
  "otpHash" TEXT NOT NULL,
  "expiresAt" TEXT NOT NULL,
  "attempts" INTEGER NOT NULL DEFAULT '0' CHECK ("attempts" BETWEEN -2147483648 AND 2147483647),
  "createdAt" TEXT NOT NULL,
  PRIMARY KEY ("email")
);

CREATE INDEX "EmailVerificationOtp_expiresAt_idx" ON "EmailVerificationOtp" ("expiresAt");

CREATE TABLE "PendingRegistration" (
  "email" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "phone" TEXT NOT NULL,
  "passwordHash" TEXT NOT NULL,
  "expiresAt" TEXT NOT NULL,
  "createdAt" TEXT NOT NULL,
  PRIMARY KEY ("email")
);

CREATE INDEX "PendingRegistration_expiresAt_idx" ON "PendingRegistration" ("expiresAt");

CREATE TABLE "Address" (
  "id" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "label" TEXT,
  "fullName" TEXT NOT NULL,
  "phone" TEXT NOT NULL,
  "addressLine1" TEXT NOT NULL,
  "addressLine2" TEXT,
  "city" TEXT NOT NULL,
  "district" TEXT,
  "province" TEXT,
  "postalCode" TEXT,
  "instructions" TEXT,
  "latitude" REAL,
  "longitude" REAL,
  "isDefault" INTEGER NOT NULL DEFAULT 0 CHECK ("isDefault" IN (0, 1)),
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  FOREIGN KEY ("userId") REFERENCES "User" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "Address_userId_idx" ON "Address" ("userId");

CREATE TABLE "Category" (
  "id" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "slug" TEXT NOT NULL,
  "description" TEXT,
  "imageUrl" TEXT,
  "isActive" INTEGER NOT NULL DEFAULT 1 CHECK ("isActive" IN (0, 1)),
  "sortOrder" INTEGER NOT NULL DEFAULT '0' CHECK ("sortOrder" BETWEEN -2147483648 AND 2147483647),
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  UNIQUE ("slug")
);

CREATE INDEX "Category_isActive_idx" ON "Category" ("isActive");

CREATE INDEX "Category_sortOrder_idx" ON "Category" ("sortOrder");

CREATE TABLE "Product" (
  "id" TEXT NOT NULL,
  "sku" TEXT NOT NULL,
  "barcode" TEXT,
  "name" TEXT NOT NULL,
  "slug" TEXT NOT NULL,
  "categoryId" TEXT NOT NULL,
  "brand" TEXT,
  "price" TEXT NOT NULL,
  "originalPrice" TEXT,
  "rating" TEXT NOT NULL DEFAULT '0',
  "reviewCount" INTEGER NOT NULL DEFAULT '0' CHECK ("reviewCount" BETWEEN -2147483648 AND 2147483647),
  "description" TEXT,
  "origin" TEXT,
  "imageUrl" TEXT,
  "imageUrls" TEXT NOT NULL DEFAULT '[]' CHECK (json_valid("imageUrls")),
  "imageData" BLOB,
  "imageMimeType" TEXT,
  "normalizedImageData" BLOB,
  "normalizedMimeType" TEXT,
  "unitLabel" TEXT NOT NULL DEFAULT '1 pc',
  "isWholesale" INTEGER NOT NULL DEFAULT 0 CHECK ("isWholesale" IN (0, 1)),
  "wholesalePrice" TEXT,
  "wholesaleMinimumQuantity" INTEGER NOT NULL DEFAULT '1' CHECK ("wholesaleMinimumQuantity" BETWEEN -2147483648 AND 2147483647),
  "lowStockThreshold" INTEGER NOT NULL DEFAULT '10' CHECK ("lowStockThreshold" BETWEEN -2147483648 AND 2147483647),
  "isOrganic" INTEGER NOT NULL DEFAULT 0 CHECK ("isOrganic" IN (0, 1)),
  "isFeatured" INTEGER NOT NULL DEFAULT 0 CHECK ("isFeatured" IN (0, 1)),
  "isBestSeller" INTEGER NOT NULL DEFAULT 0 CHECK ("isBestSeller" IN (0, 1)),
  "isVendingDrink" INTEGER NOT NULL DEFAULT 0 CHECK ("isVendingDrink" IN (0, 1)),
  "vendingSection" TEXT,
  "isActive" INTEGER NOT NULL DEFAULT 1 CHECK ("isActive" IN (0, 1)),
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  UNIQUE ("sku"),
  UNIQUE ("barcode"),
  UNIQUE ("slug"),
  FOREIGN KEY ("categoryId") REFERENCES "Category" ("id") ON DELETE RESTRICT ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "Product_categoryId_idx" ON "Product" ("categoryId");

CREATE INDEX "Product_isActive_idx" ON "Product" ("isActive");

CREATE INDEX "Product_isFeatured_idx" ON "Product" ("isFeatured");

CREATE INDEX "Product_isBestSeller_idx" ON "Product" ("isBestSeller");

CREATE INDEX "Product_name_idx" ON "Product" ("name");

CREATE TABLE "WholesaleItem" (
  "id" TEXT NOT NULL,
  "sku" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "slug" TEXT NOT NULL,
  "categoryId" TEXT NOT NULL,
  "brand" TEXT,
  "price" TEXT NOT NULL,
  "stock" INTEGER NOT NULL DEFAULT '0' CHECK ("stock" BETWEEN -2147483648 AND 2147483647),
  "minimumQuantity" INTEGER NOT NULL DEFAULT '1' CHECK ("minimumQuantity" BETWEEN -2147483648 AND 2147483647),
  "description" TEXT,
  "origin" TEXT,
  "imageUrl" TEXT,
  "imageData" BLOB,
  "imageMimeType" TEXT,
  "normalizedImageData" BLOB,
  "normalizedMimeType" TEXT,
  "unitLabel" TEXT NOT NULL DEFAULT '1 pc',
  "rating" TEXT NOT NULL DEFAULT '0',
  "reviewCount" INTEGER NOT NULL DEFAULT '0' CHECK ("reviewCount" BETWEEN -2147483648 AND 2147483647),
  "isActive" INTEGER NOT NULL DEFAULT 1 CHECK ("isActive" IN (0, 1)),
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  UNIQUE ("sku"),
  UNIQUE ("slug"),
  FOREIGN KEY ("categoryId") REFERENCES "Category" ("id") ON DELETE RESTRICT ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "WholesaleItem_categoryId_idx" ON "WholesaleItem" ("categoryId");

CREATE INDEX "WholesaleItem_isActive_idx" ON "WholesaleItem" ("isActive");

CREATE INDEX "WholesaleItem_name_idx" ON "WholesaleItem" ("name");

CREATE TABLE "StoredImage" (
  "id" TEXT NOT NULL,
  "imageData" BLOB NOT NULL,
  "mimeType" TEXT NOT NULL,
  "normalizedImageData" BLOB,
  "normalizedMimeType" TEXT,
  "createdAt" TEXT NOT NULL,
  PRIMARY KEY ("id")
);

CREATE TABLE "Inventory" (
  "id" TEXT NOT NULL,
  "productId" TEXT NOT NULL,
  "totalStock" INTEGER NOT NULL DEFAULT '0' CHECK ("totalStock" BETWEEN -2147483648 AND 2147483647),
  "reservedStock" INTEGER NOT NULL DEFAULT '0' CHECK ("reservedStock" BETWEEN -2147483648 AND 2147483647),
  "version" INTEGER NOT NULL DEFAULT '0' CHECK ("version" BETWEEN -2147483648 AND 2147483647),
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  UNIQUE ("productId"),
  FOREIGN KEY ("productId") REFERENCES "Product" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "Inventory_totalStock_idx" ON "Inventory" ("totalStock");

CREATE TABLE "InventoryBatch" (
  "id" TEXT NOT NULL,
  "productId" TEXT NOT NULL,
  "lotNumber" TEXT,
  "manufacturedAt" TEXT,
  "expiresAt" TEXT,
  "noExpiry" INTEGER NOT NULL DEFAULT 0 CHECK ("noExpiry" IN (0, 1)),
  "datesVerified" INTEGER NOT NULL DEFAULT 0 CHECK ("datesVerified" IN (0, 1)),
  "receivedQuantity" INTEGER NOT NULL CHECK ("receivedQuantity" BETWEEN -2147483648 AND 2147483647),
  "remainingQuantity" INTEGER NOT NULL CHECK ("remainingQuantity" BETWEEN -2147483648 AND 2147483647),
  "purchasePrice" TEXT,
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  FOREIGN KEY ("productId") REFERENCES "Product" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "InventoryBatch_productId_expiresAt_idx" ON "InventoryBatch" ("productId", "expiresAt");

CREATE INDEX "InventoryBatch_expiresAt_idx" ON "InventoryBatch" ("expiresAt");

CREATE TABLE "SupplierPurchaseBill" (
  "id" TEXT NOT NULL,
  "supplierName" TEXT NOT NULL,
  "supplierPhone" TEXT,
  "invoiceNumber" TEXT NOT NULL,
  "invoiceDate" TEXT NOT NULL,
  "deliveryPerson" TEXT,
  "notes" TEXT,
  "photoData" BLOB,
  "photoMimeType" TEXT,
  "totalCost" TEXT NOT NULL,
  "status" TEXT NOT NULL DEFAULT 'RECEIVED' CHECK ("status" IN ('RECEIVED')),
  "createdById" TEXT,
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  UNIQUE ("supplierName", "invoiceNumber"),
  FOREIGN KEY ("createdById") REFERENCES "User" ("id") ON DELETE SET NULL ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "SupplierPurchaseBill_invoiceDate_idx" ON "SupplierPurchaseBill" ("invoiceDate");

CREATE INDEX "SupplierPurchaseBill_createdAt_idx" ON "SupplierPurchaseBill" ("createdAt");

CREATE INDEX "SupplierPurchaseBill_supplierName_idx" ON "SupplierPurchaseBill" ("supplierName");

CREATE TABLE "SupplierPurchaseBillItem" (
  "id" TEXT NOT NULL,
  "billId" TEXT NOT NULL,
  "productId" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "sku" TEXT NOT NULL,
  "unitLabel" TEXT NOT NULL,
  "quantity" TEXT NOT NULL,
  "unitCost" TEXT NOT NULL,
  "lineTotal" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  FOREIGN KEY ("billId") REFERENCES "SupplierPurchaseBill" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY ("productId") REFERENCES "Product" ("id") ON DELETE RESTRICT ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "SupplierPurchaseBillItem_billId_idx" ON "SupplierPurchaseBillItem" ("billId");

CREATE INDEX "SupplierPurchaseBillItem_productId_idx" ON "SupplierPurchaseBillItem" ("productId");

CREATE TABLE "OrderBatchAllocation" (
  "id" TEXT NOT NULL,
  "orderId" TEXT NOT NULL,
  "productId" TEXT NOT NULL,
  "batchId" TEXT NOT NULL,
  "quantity" INTEGER NOT NULL CHECK ("quantity" BETWEEN -2147483648 AND 2147483647),
  "createdAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  FOREIGN KEY ("orderId") REFERENCES "Order" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY ("productId") REFERENCES "Product" ("id") ON DELETE RESTRICT ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY ("batchId") REFERENCES "InventoryBatch" ("id") ON DELETE RESTRICT ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "OrderBatchAllocation_orderId_idx" ON "OrderBatchAllocation" ("orderId");

CREATE INDEX "OrderBatchAllocation_batchId_idx" ON "OrderBatchAllocation" ("batchId");

CREATE TABLE "ProductVariant" (
  "id" TEXT NOT NULL,
  "productId" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "sku" TEXT NOT NULL,
  "price" TEXT,
  "originalPrice" TEXT,
  "stock" INTEGER NOT NULL DEFAULT '0' CHECK ("stock" BETWEEN -2147483648 AND 2147483647),
  "isActive" INTEGER NOT NULL DEFAULT 1 CHECK ("isActive" IN (0, 1)),
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  UNIQUE ("sku"),
  FOREIGN KEY ("productId") REFERENCES "Product" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "ProductVariant_productId_idx" ON "ProductVariant" ("productId");

CREATE INDEX "ProductVariant_isActive_idx" ON "ProductVariant" ("isActive");

CREATE TABLE "InventoryTransaction" (
  "id" TEXT NOT NULL,
  "inventoryId" TEXT NOT NULL,
  "type" TEXT NOT NULL CHECK ("type" IN ('RESERVED', 'PURCHASED', 'RELEASED', 'RESTOCKED', 'ADJUSTED')),
  "quantity" INTEGER NOT NULL CHECK ("quantity" BETWEEN -2147483648 AND 2147483647),
  "balanceAfter" INTEGER NOT NULL CHECK ("balanceAfter" BETWEEN -2147483648 AND 2147483647),
  "referenceId" TEXT,
  "notes" TEXT,
  "performedById" TEXT,
  "createdAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  FOREIGN KEY ("inventoryId") REFERENCES "Inventory" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY ("performedById") REFERENCES "User" ("id") ON DELETE SET NULL ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "InventoryTransaction_inventoryId_idx" ON "InventoryTransaction" ("inventoryId");

CREATE INDEX "InventoryTransaction_type_idx" ON "InventoryTransaction" ("type");

CREATE INDEX "InventoryTransaction_referenceId_idx" ON "InventoryTransaction" ("referenceId");

CREATE INDEX "InventoryTransaction_performedById_idx" ON "InventoryTransaction" ("performedById");

CREATE INDEX "InventoryTransaction_createdAt_idx" ON "InventoryTransaction" ("createdAt");

CREATE TABLE "Order" (
  "id" TEXT NOT NULL,
  "orderNumber" TEXT NOT NULL,
  "invoiceNumber" TEXT,
  "userId" TEXT NOT NULL,
  "addressId" TEXT,
  "status" TEXT NOT NULL DEFAULT 'PLACED' CHECK ("status" IN ('PLACED', 'CONFIRMED', 'PROCESSING', 'OUT_FOR_DELIVERY', 'DELIVERED', 'CANCELLED')),
  "paymentMethod" TEXT NOT NULL CHECK ("paymentMethod" IN ('COD', 'ESEWA', 'KHALTI')),
  "paymentStatus" TEXT NOT NULL DEFAULT 'PENDING' CHECK ("paymentStatus" IN ('PENDING', 'COMPLETED', 'FAILED', 'REFUNDED', 'CANCELLED')),
  "subtotal" TEXT NOT NULL,
  "deliveryFee" TEXT NOT NULL DEFAULT '0',
  "discount" TEXT NOT NULL DEFAULT '0',
  "tip" TEXT NOT NULL DEFAULT '0',
  "total" TEXT NOT NULL,
  "couponCode" TEXT,
  "idempotencyKey" TEXT,
  "scheduledDeliveryAt" TEXT,
  "shippingName" TEXT NOT NULL,
  "shippingPhone" TEXT NOT NULL,
  "shippingAddress" TEXT NOT NULL,
  "shippingCity" TEXT NOT NULL,
  "shippingDistrict" TEXT,
  "shippingProvince" TEXT,
  "shippingPostalCode" TEXT,
  "notes" TEXT,
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  UNIQUE ("orderNumber"),
  UNIQUE ("invoiceNumber"),
  UNIQUE ("idempotencyKey"),
  FOREIGN KEY ("addressId") REFERENCES "Address" ("id") ON DELETE SET NULL ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY ("userId") REFERENCES "User" ("id") ON DELETE RESTRICT ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "Order_userId_idx" ON "Order" ("userId");

CREATE INDEX "Order_userId_createdAt_idx" ON "Order" ("userId", "createdAt");

CREATE INDEX "Order_userId_couponCode_status_idx" ON "Order" ("userId", "couponCode", "status");

CREATE INDEX "Order_status_idx" ON "Order" ("status");

CREATE INDEX "Order_paymentStatus_idx" ON "Order" ("paymentStatus");

CREATE INDEX "Order_createdAt_idx" ON "Order" ("createdAt");

CREATE TABLE "OrderItem" (
  "id" TEXT NOT NULL,
  "orderId" TEXT NOT NULL,
  "productId" TEXT,
  "wholesaleItemId" TEXT,
  "productName" TEXT NOT NULL,
  "sku" TEXT NOT NULL,
  "quantity" INTEGER NOT NULL CHECK ("quantity" BETWEEN -2147483648 AND 2147483647),
  "weightGrams" INTEGER CHECK ("weightGrams" BETWEEN -2147483648 AND 2147483647),
  "price" TEXT NOT NULL,
  "total" TEXT NOT NULL,
  "isWholesale" INTEGER NOT NULL DEFAULT 0 CHECK ("isWholesale" IN (0, 1)),
  "createdAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  FOREIGN KEY ("orderId") REFERENCES "Order" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY ("productId") REFERENCES "Product" ("id") ON DELETE SET NULL ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY ("wholesaleItemId") REFERENCES "WholesaleItem" ("id") ON DELETE SET NULL ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "OrderItem_orderId_idx" ON "OrderItem" ("orderId");

CREATE INDEX "OrderItem_productId_idx" ON "OrderItem" ("productId");

CREATE INDEX "OrderItem_wholesaleItemId_idx" ON "OrderItem" ("wholesaleItemId");

CREATE TABLE "Payment" (
  "id" TEXT NOT NULL,
  "orderId" TEXT NOT NULL,
  "method" TEXT NOT NULL CHECK ("method" IN ('COD', 'ESEWA', 'KHALTI')),
  "status" TEXT NOT NULL DEFAULT 'PENDING' CHECK ("status" IN ('PENDING', 'COMPLETED', 'FAILED', 'REFUNDED', 'CANCELLED')),
  "transactionId" TEXT,
  "amount" TEXT NOT NULL,
  "gatewayResponse" TEXT CHECK (json_valid("gatewayResponse")),
  "errorMessage" TEXT,
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  FOREIGN KEY ("orderId") REFERENCES "Order" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "Payment_orderId_idx" ON "Payment" ("orderId");

CREATE INDEX "Payment_transactionId_idx" ON "Payment" ("transactionId");

CREATE INDEX "Payment_status_idx" ON "Payment" ("status");

CREATE TABLE "PosShift" (
  "id" TEXT NOT NULL,
  "cashierId" TEXT NOT NULL,
  "status" TEXT NOT NULL DEFAULT 'OPEN' CHECK ("status" IN ('OPEN', 'CLOSED')),
  "openingCash" TEXT NOT NULL,
  "expectedClosingCash" TEXT,
  "actualClosingCash" TEXT,
  "openedAt" TEXT NOT NULL,
  "closedAt" TEXT,
  PRIMARY KEY ("id"),
  FOREIGN KEY ("cashierId") REFERENCES "User" ("id") ON DELETE RESTRICT ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "PosShift_cashierId_status_idx" ON "PosShift" ("cashierId", "status");

CREATE INDEX "PosShift_openedAt_idx" ON "PosShift" ("openedAt");

CREATE TABLE "InventoryRoom" (
  "id" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "number" TEXT NOT NULL,
  "active" INTEGER NOT NULL DEFAULT 1 CHECK ("active" IN (0, 1)),
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  UNIQUE ("number")
);

CREATE TABLE "InventoryRoomStock" (
  "roomId" TEXT NOT NULL,
  "productId" TEXT NOT NULL,
  "quantity" INTEGER NOT NULL DEFAULT '0' CHECK ("quantity" BETWEEN -2147483648 AND 2147483647),
  PRIMARY KEY ("roomId", "productId"),
  FOREIGN KEY ("roomId") REFERENCES "InventoryRoom" ("id") ON DELETE RESTRICT ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "InventoryRoomStock_productId_idx" ON "InventoryRoomStock" ("productId");

CREATE TABLE "InventoryRoomMovement" (
  "id" TEXT NOT NULL,
  "requestId" TEXT,
  "productId" TEXT NOT NULL,
  "fromRoomId" TEXT,
  "toRoomId" TEXT,
  "quantity" INTEGER NOT NULL CHECK ("quantity" BETWEEN -2147483648 AND 2147483647),
  "reason" TEXT NOT NULL,
  "referenceId" TEXT,
  "actorId" TEXT,
  "createdAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  UNIQUE ("requestId")
);

CREATE INDEX "InventoryRoomMovement_referenceId_idx" ON "InventoryRoomMovement" ("referenceId");

CREATE INDEX "InventoryRoomMovement_productId_createdAt_idx" ON "InventoryRoomMovement" ("productId", "createdAt");

CREATE TABLE "InventoryRoomCheckout" (
  "saleId" TEXT NOT NULL,
  "picks" TEXT NOT NULL CHECK (json_valid("picks")),
  PRIMARY KEY ("saleId")
);

CREATE TABLE "InventoryLocalStockReceipt" (
  "id" TEXT NOT NULL,
  "ownerId" TEXT NOT NULL,
  "items" TEXT NOT NULL CHECK (json_valid("items")),
  "roomPicks" TEXT NOT NULL CHECK (json_valid("roomPicks")),
  "createdAt" TEXT NOT NULL,
  PRIMARY KEY ("id")
);

CREATE TABLE "PosSale" (
  "id" TEXT NOT NULL,
  "receiptNumber" TEXT NOT NULL,
  "invoiceNumber" TEXT,
  "shiftId" TEXT NOT NULL,
  "customerName" TEXT,
  "customerPhone" TEXT,
  "status" TEXT NOT NULL DEFAULT 'COMPLETED' CHECK ("status" IN ('CHECKOUT', 'COMPLETED', 'PARTIALLY_REFUNDED', 'REFUNDED', 'CANCELLED')),
  "paymentMethod" TEXT NOT NULL CHECK ("paymentMethod" IN ('FONEPAY', 'CASH', 'DIGITAL', 'PENDING')),
  "paymentStatus" TEXT NOT NULL DEFAULT 'COMPLETED' CHECK ("paymentStatus" IN ('PENDING', 'COMPLETED', 'FAILED', 'REFUNDED', 'CANCELLED')),
  "paidAmount" TEXT NOT NULL DEFAULT '0',
  "subtotal" TEXT NOT NULL,
  "discount" TEXT NOT NULL DEFAULT '0',
  "vatRate" TEXT NOT NULL DEFAULT '0',
  "vatAmount" TEXT NOT NULL DEFAULT '0',
  "total" TEXT NOT NULL,
  "refundedAmount" TEXT NOT NULL DEFAULT '0',
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  UNIQUE ("receiptNumber"),
  UNIQUE ("invoiceNumber"),
  FOREIGN KEY ("shiftId") REFERENCES "PosShift" ("id") ON DELETE RESTRICT ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "PosSale_shiftId_createdAt_idx" ON "PosSale" ("shiftId", "createdAt");

CREATE INDEX "PosSale_createdAt_status_idx" ON "PosSale" ("createdAt", "status");

CREATE INDEX "PosSale_paymentStatus_idx" ON "PosSale" ("paymentStatus");

CREATE TABLE "PosFonepayRequest" (
  "id" TEXT NOT NULL,
  "saleId" TEXT NOT NULL,
  "reference" TEXT NOT NULL,
  "activeKey" TEXT,
  "requestedById" TEXT NOT NULL,
  "environment" TEXT NOT NULL,
  "merchantCode" TEXT NOT NULL,
  "merchantName" TEXT,
  "currency" TEXT NOT NULL DEFAULT 'NPR',
  "amount" TEXT NOT NULL,
  "billFingerprint" TEXT NOT NULL,
  "invoiceNumber" TEXT NOT NULL,
  "state" TEXT NOT NULL DEFAULT 'CREATING',
  "qrPayload" TEXT,
  "expiresAt" TEXT,
  "lastCheckedAt" TEXT,
  "providerTransactionId" TEXT,
  "verifiedAt" TEXT,
  "autoPrintClaimedAt" TEXT,
  "failureCode" TEXT,
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  UNIQUE ("environment", "merchantCode", "providerTransactionId"),
  UNIQUE ("reference"),
  UNIQUE ("activeKey"),
  FOREIGN KEY ("saleId") REFERENCES "PosSale" ("id") ON DELETE RESTRICT ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "PosFonepayRequest_saleId_createdAt_idx" ON "PosFonepayRequest" ("saleId", "createdAt");

CREATE INDEX "PosFonepayRequest_state_expiresAt_idx" ON "PosFonepayRequest" ("state", "expiresAt");

CREATE TABLE "PosPaymentCollection" (
  "id" TEXT NOT NULL,
  "saleId" TEXT NOT NULL,
  "recordedById" TEXT NOT NULL,
  "amount" TEXT NOT NULL,
  "method" TEXT NOT NULL CHECK ("method" IN ('FONEPAY', 'CASH', 'DIGITAL', 'PENDING')),
  "note" TEXT,
  "createdAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  FOREIGN KEY ("saleId") REFERENCES "PosSale" ("id") ON DELETE RESTRICT ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY ("recordedById") REFERENCES "User" ("id") ON DELETE RESTRICT ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "PosPaymentCollection_createdAt_idx" ON "PosPaymentCollection" ("createdAt");

CREATE INDEX "PosPaymentCollection_saleId_createdAt_idx" ON "PosPaymentCollection" ("saleId", "createdAt");

CREATE INDEX "PosPaymentCollection_recordedById_createdAt_idx" ON "PosPaymentCollection" ("recordedById", "createdAt");

CREATE TABLE "PosOfflineStreakPurchase" (
  "id" TEXT NOT NULL,
  "invoiceNumber" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "purchaseDate" TEXT NOT NULL,
  "createdAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  UNIQUE ("invoiceNumber"),
  FOREIGN KEY ("userId") REFERENCES "User" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "PosOfflineStreakPurchase_userId_purchaseDate_idx" ON "PosOfflineStreakPurchase" ("userId", "purchaseDate");

CREATE TABLE "PosSaleItem" (
  "id" TEXT NOT NULL,
  "saleId" TEXT NOT NULL,
  "productId" TEXT,
  "productName" TEXT NOT NULL,
  "sku" TEXT NOT NULL,
  "quantity" INTEGER NOT NULL CHECK ("quantity" BETWEEN -2147483648 AND 2147483647),
  "weightGrams" INTEGER CHECK ("weightGrams" BETWEEN -2147483648 AND 2147483647),
  "unitPrice" TEXT NOT NULL,
  "lineTotal" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  FOREIGN KEY ("saleId") REFERENCES "PosSale" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY ("productId") REFERENCES "Product" ("id") ON DELETE SET NULL ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "PosSaleItem_saleId_idx" ON "PosSaleItem" ("saleId");

CREATE INDEX "PosSaleItem_productId_idx" ON "PosSaleItem" ("productId");

CREATE TABLE "PosHeldSale" (
  "id" TEXT NOT NULL,
  "shiftId" TEXT NOT NULL,
  "customerName" TEXT,
  "customerPhone" TEXT,
  "items" TEXT NOT NULL CHECK (json_valid("items")),
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  FOREIGN KEY ("shiftId") REFERENCES "PosShift" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "PosHeldSale_shiftId_createdAt_idx" ON "PosHeldSale" ("shiftId", "createdAt");

CREATE TABLE "PosRefund" (
  "id" TEXT NOT NULL,
  "saleId" TEXT NOT NULL,
  "requestedById" TEXT NOT NULL,
  "resolvedById" TEXT,
  "amount" TEXT NOT NULL,
  "reason" TEXT NOT NULL,
  "status" TEXT NOT NULL DEFAULT 'REQUESTED' CHECK ("status" IN ('REQUESTED', 'APPROVED', 'REJECTED')),
  "restockStock" INTEGER NOT NULL DEFAULT 0 CHECK ("restockStock" IN (0, 1)),
  "requestedAt" TEXT NOT NULL,
  "resolvedAt" TEXT,
  PRIMARY KEY ("id"),
  FOREIGN KEY ("saleId") REFERENCES "PosSale" ("id") ON DELETE RESTRICT ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY ("requestedById") REFERENCES "User" ("id") ON DELETE RESTRICT ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY ("resolvedById") REFERENCES "User" ("id") ON DELETE RESTRICT ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "PosRefund_status_requestedAt_idx" ON "PosRefund" ("status", "requestedAt");

CREATE INDEX "PosRefund_saleId_idx" ON "PosRefund" ("saleId");

CREATE TABLE "PosCashMovement" (
  "id" TEXT NOT NULL,
  "shiftId" TEXT NOT NULL,
  "actorId" TEXT NOT NULL,
  "type" TEXT NOT NULL CHECK ("type" IN ('CASH_IN', 'CASH_OUT')),
  "amount" TEXT NOT NULL,
  "note" TEXT NOT NULL,
  "createdAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  FOREIGN KEY ("shiftId") REFERENCES "PosShift" ("id") ON DELETE RESTRICT ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY ("actorId") REFERENCES "User" ("id") ON DELETE RESTRICT ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "PosCashMovement_shiftId_createdAt_idx" ON "PosCashMovement" ("shiftId", "createdAt");

CREATE TABLE "PosExchange" (
  "id" TEXT NOT NULL,
  "idempotencyKey" TEXT NOT NULL,
  "saleId" TEXT NOT NULL,
  "cashierId" TEXT NOT NULL,
  "shiftId" TEXT NOT NULL,
  "resolvedById" TEXT,
  "returnedCredit" TEXT NOT NULL,
  "replacementTotal" TEXT NOT NULL,
  "difference" TEXT NOT NULL,
  "paymentMethod" TEXT CHECK ("paymentMethod" IN ('FONEPAY', 'CASH', 'DIGITAL', 'PENDING')),
  "refundPaymentMethod" TEXT CHECK ("refundPaymentMethod" IN ('FONEPAY', 'CASH', 'DIGITAL', 'PENDING')),
  "status" TEXT NOT NULL DEFAULT 'COMPLETED' CHECK ("status" IN ('COMPLETED', 'REFUND_REQUESTED', 'REFUND_APPROVED', 'REFUND_REJECTED')),
  "restockReturnedItems" INTEGER NOT NULL DEFAULT 1 CHECK ("restockReturnedItems" IN (0, 1)),
  "reason" TEXT,
  "requestedAt" TEXT NOT NULL,
  "resolvedAt" TEXT,
  PRIMARY KEY ("id"),
  UNIQUE ("idempotencyKey"),
  FOREIGN KEY ("saleId") REFERENCES "PosSale" ("id") ON DELETE RESTRICT ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY ("cashierId") REFERENCES "User" ("id") ON DELETE RESTRICT ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY ("shiftId") REFERENCES "PosShift" ("id") ON DELETE RESTRICT ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY ("resolvedById") REFERENCES "User" ("id") ON DELETE RESTRICT ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "PosExchange_saleId_requestedAt_idx" ON "PosExchange" ("saleId", "requestedAt");

CREATE INDEX "PosExchange_status_requestedAt_idx" ON "PosExchange" ("status", "requestedAt");

CREATE INDEX "PosExchange_cashierId_requestedAt_idx" ON "PosExchange" ("cashierId", "requestedAt");

CREATE INDEX "PosExchange_shiftId_idx" ON "PosExchange" ("shiftId");

CREATE TABLE "PosExchangeItem" (
  "id" TEXT NOT NULL,
  "exchangeId" TEXT NOT NULL,
  "saleItemId" TEXT,
  "productId" TEXT,
  "type" TEXT NOT NULL CHECK ("type" IN ('RETURN', 'REPLACEMENT')),
  "productName" TEXT NOT NULL,
  "sku" TEXT NOT NULL,
  "quantity" INTEGER NOT NULL CHECK ("quantity" BETWEEN -2147483648 AND 2147483647),
  "weightGrams" INTEGER CHECK ("weightGrams" BETWEEN -2147483648 AND 2147483647),
  "unitPrice" TEXT NOT NULL,
  "lineTotal" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  FOREIGN KEY ("exchangeId") REFERENCES "PosExchange" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY ("saleItemId") REFERENCES "PosSaleItem" ("id") ON DELETE SET NULL ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY ("productId") REFERENCES "Product" ("id") ON DELETE SET NULL ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "PosExchangeItem_exchangeId_idx" ON "PosExchangeItem" ("exchangeId");

CREATE INDEX "PosExchangeItem_saleItemId_idx" ON "PosExchangeItem" ("saleItemId");

CREATE INDEX "PosExchangeItem_productId_idx" ON "PosExchangeItem" ("productId");

CREATE TABLE "Cart" (
  "id" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  UNIQUE ("userId"),
  FOREIGN KEY ("userId") REFERENCES "User" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "Cart_userId_idx" ON "Cart" ("userId");

CREATE TABLE "CartItem" (
  "id" TEXT NOT NULL,
  "cartId" TEXT NOT NULL,
  "productId" TEXT,
  "wholesaleItemId" TEXT,
  "productVariantId" TEXT,
  "quantity" INTEGER NOT NULL DEFAULT '1' CHECK ("quantity" BETWEEN -2147483648 AND 2147483647),
  "weightGrams" INTEGER CHECK ("weightGrams" BETWEEN -2147483648 AND 2147483647),
  "unitPrice" TEXT NOT NULL,
  "isWholesale" INTEGER NOT NULL DEFAULT 0 CHECK ("isWholesale" IN (0, 1)),
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  FOREIGN KEY ("cartId") REFERENCES "Cart" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY ("productId") REFERENCES "Product" ("id") ON DELETE SET NULL ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY ("wholesaleItemId") REFERENCES "WholesaleItem" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY ("productVariantId") REFERENCES "ProductVariant" ("id") ON DELETE SET NULL ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "CartItem_cartId_idx" ON "CartItem" ("cartId");

CREATE INDEX "CartItem_productId_idx" ON "CartItem" ("productId");

CREATE INDEX "CartItem_wholesaleItemId_idx" ON "CartItem" ("wholesaleItemId");

CREATE TABLE "Wishlist" (
  "id" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  UNIQUE ("userId"),
  FOREIGN KEY ("userId") REFERENCES "User" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "Wishlist_userId_idx" ON "Wishlist" ("userId");

CREATE TABLE "WishlistItem" (
  "id" TEXT NOT NULL,
  "wishlistId" TEXT NOT NULL,
  "productId" TEXT NOT NULL,
  "productVariantId" TEXT,
  "createdAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  UNIQUE ("wishlistId", "productId", "productVariantId"),
  FOREIGN KEY ("productId") REFERENCES "Product" ("id") ON DELETE RESTRICT ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY ("productVariantId") REFERENCES "ProductVariant" ("id") ON DELETE SET NULL ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY ("wishlistId") REFERENCES "Wishlist" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "WishlistItem_wishlistId_idx" ON "WishlistItem" ("wishlistId");

CREATE TABLE "Review" (
  "id" TEXT NOT NULL,
  "productId" TEXT,
  "wholesaleItemId" TEXT,
  "userId" TEXT NOT NULL,
  "rating" INTEGER NOT NULL CHECK ("rating" BETWEEN -2147483648 AND 2147483647),
  "text" TEXT,
  "imageUrl" TEXT,
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  UNIQUE ("productId", "userId"),
  UNIQUE ("wholesaleItemId", "userId"),
  FOREIGN KEY ("productId") REFERENCES "Product" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY ("wholesaleItemId") REFERENCES "WholesaleItem" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY ("userId") REFERENCES "User" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "Review_productId_idx" ON "Review" ("productId");

CREATE INDEX "Review_wholesaleItemId_idx" ON "Review" ("wholesaleItemId");

CREATE INDEX "Review_userId_idx" ON "Review" ("userId");

CREATE TABLE "Notification" (
  "id" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "type" TEXT NOT NULL CHECK ("type" IN ('ORDER_PLACED', 'ORDER_CONFIRMED', 'ORDER_PROCESSING', 'ORDER_OUT_FOR_DELIVERY', 'ORDER_DELIVERED', 'ORDER_CANCELLED', 'DELIVERY_ASSIGNED', 'DELIVERY_UPDATED', 'PROMOTIONAL')),
  "title" TEXT NOT NULL,
  "body" TEXT NOT NULL,
  "isRead" INTEGER NOT NULL DEFAULT 0 CHECK ("isRead" IN (0, 1)),
  "metadata" TEXT CHECK (json_valid("metadata")),
  "createdAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  FOREIGN KEY ("userId") REFERENCES "User" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "Notification_userId_idx" ON "Notification" ("userId");

CREATE INDEX "Notification_isRead_idx" ON "Notification" ("isRead");

CREATE TABLE "DeviceToken" (
  "id" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "token" TEXT NOT NULL,
  "platform" TEXT NOT NULL,
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  UNIQUE ("token"),
  FOREIGN KEY ("userId") REFERENCES "User" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "DeviceToken_userId_idx" ON "DeviceToken" ("userId");

CREATE TABLE "Delivery" (
  "id" TEXT NOT NULL,
  "orderId" TEXT NOT NULL,
  "deliveryPersonId" TEXT,
  "status" TEXT NOT NULL DEFAULT 'PENDING' CHECK ("status" IN ('PENDING', 'ASSIGNED', 'ACCEPTED', 'DECLINED', 'PICKED_UP', 'OUT_FOR_DELIVERY', 'DELIVERED', 'FAILED', 'CANCELLED')),
  "assignedAt" TEXT,
  "pickedUpAt" TEXT,
  "deliveredAt" TEXT,
  "cashCollected" TEXT NOT NULL DEFAULT '0',
  "cashCollectedAt" TEXT,
  "cashHandedOver" TEXT NOT NULL DEFAULT '0',
  "cashHandedOverAt" TEXT,
  "latitude" REAL,
  "longitude" REAL,
  "locationUpdatedAt" TEXT,
  "customerLatitude" REAL,
  "customerLongitude" REAL,
  "customerLocationUpdatedAt" TEXT,
  "notes" TEXT,
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  UNIQUE ("orderId"),
  FOREIGN KEY ("deliveryPersonId") REFERENCES "User" ("id") ON DELETE SET NULL ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY ("orderId") REFERENCES "Order" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "Delivery_deliveryPersonId_idx" ON "Delivery" ("deliveryPersonId");

CREATE INDEX "Delivery_status_idx" ON "Delivery" ("status");

CREATE INDEX "Delivery_deliveryPersonId_status_assignedAt_idx" ON "Delivery" ("deliveryPersonId", "status", "assignedAt");

CREATE TABLE "DeliveryStatusHistory" (
  "id" TEXT NOT NULL,
  "deliveryId" TEXT NOT NULL,
  "changedById" TEXT NOT NULL,
  "status" TEXT NOT NULL CHECK ("status" IN ('PENDING', 'ASSIGNED', 'ACCEPTED', 'DECLINED', 'PICKED_UP', 'OUT_FOR_DELIVERY', 'DELIVERED', 'FAILED', 'CANCELLED')),
  "note" TEXT,
  "createdAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  FOREIGN KEY ("deliveryId") REFERENCES "Delivery" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY ("changedById") REFERENCES "User" ("id") ON DELETE RESTRICT ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "DeliveryStatusHistory_deliveryId_idx" ON "DeliveryStatusHistory" ("deliveryId");

CREATE INDEX "DeliveryStatusHistory_changedById_idx" ON "DeliveryStatusHistory" ("changedById");

CREATE INDEX "DeliveryStatusHistory_createdAt_idx" ON "DeliveryStatusHistory" ("createdAt");

CREATE TABLE "OrderStatusHistory" (
  "id" TEXT NOT NULL,
  "orderId" TEXT NOT NULL,
  "status" TEXT NOT NULL CHECK ("status" IN ('PLACED', 'CONFIRMED', 'PROCESSING', 'OUT_FOR_DELIVERY', 'DELIVERED', 'CANCELLED')),
  "note" TEXT,
  "createdAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  FOREIGN KEY ("orderId") REFERENCES "Order" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "OrderStatusHistory_orderId_idx" ON "OrderStatusHistory" ("orderId");

CREATE TABLE "Coupon" (
  "id" TEXT NOT NULL,
  "code" TEXT NOT NULL,
  "productId" TEXT,
  "assignedUserId" TEXT,
  "discountType" TEXT NOT NULL DEFAULT 'PERCENTAGE' CHECK ("discountType" IN ('PERCENTAGE', 'FIXED')),
  "discountPercent" TEXT,
  "discountAmount" TEXT,
  "minOrderAmount" TEXT NOT NULL DEFAULT '0',
  "maxDiscount" TEXT,
  "usageLimit" INTEGER CHECK ("usageLimit" BETWEEN -2147483648 AND 2147483647),
  "perUserLimit" INTEGER CHECK ("perUserLimit" BETWEEN -2147483648 AND 2147483647),
  "usedCount" INTEGER NOT NULL DEFAULT '0' CHECK ("usedCount" BETWEEN -2147483648 AND 2147483647),
  "isActive" INTEGER NOT NULL DEFAULT 1 CHECK ("isActive" IN (0, 1)),
  "isDeleted" INTEGER NOT NULL DEFAULT 0 CHECK ("isDeleted" IN (0, 1)),
  "isAnnounced" INTEGER NOT NULL DEFAULT 0 CHECK ("isAnnounced" IN (0, 1)),
  "isBannerFeatured" INTEGER NOT NULL DEFAULT 0 CHECK ("isBannerFeatured" IN (0, 1)),
  "expiresAt" TEXT,
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL,
  PRIMARY KEY ("id"),
  UNIQUE ("code"),
  FOREIGN KEY ("productId") REFERENCES "Product" ("id") ON DELETE RESTRICT ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  FOREIGN KEY ("assignedUserId") REFERENCES "User" ("id") ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX "Coupon_isActive_idx" ON "Coupon" ("isActive");

CREATE INDEX "Coupon_expiresAt_idx" ON "Coupon" ("expiresAt");

CREATE INDEX "Coupon_productId_idx" ON "Coupon" ("productId");

CREATE INDEX "Coupon_assignedUserId_idx" ON "Coupon" ("assignedUserId");

CREATE TABLE "PosCataloguePriceChange" (
  "requestId" TEXT NOT NULL,
  "cashierId" TEXT NOT NULL,
  "changes" TEXT NOT NULL CHECK (json_valid("changes")),
  "createdAt" TEXT NOT NULL,
  PRIMARY KEY ("requestId")
);

CREATE TABLE "StoreSetting" (
  "id" TEXT NOT NULL DEFAULT 'store',
  "isOrderingEnabled" INTEGER NOT NULL DEFAULT 1 CHECK ("isOrderingEnabled" IN (0, 1)),
  "weeklyHours" TEXT NOT NULL CHECK (json_valid("weeklyHours")),
  "customerMenuFeatures" TEXT NOT NULL DEFAULT '{}' CHECK (json_valid("customerMenuFeatures")),
  "createdAt" TEXT NOT NULL,
  "updatedAt" TEXT NOT NULL,
  PRIMARY KEY ("id")
);
