CREATE TABLE "InventoryRoom" (
  "id" STRING NOT NULL, "name" STRING NOT NULL, "number" STRING NOT NULL,
  "active" BOOL NOT NULL DEFAULT true,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "InventoryRoom_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "InventoryRoom_number_key" ON "InventoryRoom"("number");
CREATE TABLE "InventoryRoomStock" (
  "roomId" STRING NOT NULL, "productId" STRING NOT NULL,
  "quantity" INT4 NOT NULL DEFAULT 0 CHECK ("quantity" >= 0),
  CONSTRAINT "InventoryRoomStock_pkey" PRIMARY KEY ("roomId", "productId"),
  CONSTRAINT "InventoryRoomStock_roomId_fkey" FOREIGN KEY ("roomId") REFERENCES "InventoryRoom"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "InventoryRoomStock_productId_idx" ON "InventoryRoomStock"("productId");
CREATE TABLE "InventoryRoomMovement" (
  "id" STRING NOT NULL, "requestId" STRING, "productId" STRING NOT NULL,
  "fromRoomId" STRING, "toRoomId" STRING,
  "quantity" INT4 NOT NULL CHECK ("quantity" > 0),
  "reason" STRING NOT NULL, "referenceId" STRING, "actorId" STRING,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "InventoryRoomMovement_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "InventoryRoomMovement_requestId_key" ON "InventoryRoomMovement"("requestId");
CREATE INDEX "InventoryRoomMovement_referenceId_idx" ON "InventoryRoomMovement"("referenceId");
CREATE INDEX "InventoryRoomMovement_productId_createdAt_idx" ON "InventoryRoomMovement"("productId", "createdAt");
CREATE TABLE "InventoryRoomCheckout" (
  "saleId" STRING NOT NULL, "picks" JSONB NOT NULL,
  CONSTRAINT "InventoryRoomCheckout_pkey" PRIMARY KEY ("saleId")
);
CREATE TABLE "InventoryLocalStockReceipt" (
  "id" STRING NOT NULL, "ownerId" STRING NOT NULL, "items" JSONB NOT NULL,
  "roomPicks" JSONB NOT NULL, "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "InventoryLocalStockReceipt_pkey" PRIMARY KEY ("id")
);
