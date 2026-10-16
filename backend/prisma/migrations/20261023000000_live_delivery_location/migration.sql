ALTER TABLE "Delivery"
ADD COLUMN "latitude" FLOAT8,
ADD COLUMN "longitude" FLOAT8,
ADD COLUMN "locationUpdatedAt" TIMESTAMPTZ;

CREATE INDEX "Delivery_deliveryPersonId_status_assignedAt_idx"
ON "Delivery" ("deliveryPersonId", "status", "assignedAt");

CREATE INDEX "Order_userId_createdAt_idx"
ON "Order" ("userId", "createdAt");
