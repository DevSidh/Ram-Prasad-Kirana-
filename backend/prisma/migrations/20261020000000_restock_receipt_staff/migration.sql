ALTER TABLE "InventoryTransaction"
ADD COLUMN "performedById" STRING;

CREATE INDEX "InventoryTransaction_performedById_idx"
ON "InventoryTransaction" ("performedById");

ALTER TABLE "InventoryTransaction"
ADD CONSTRAINT "InventoryTransaction_performedById_fkey"
FOREIGN KEY ("performedById") REFERENCES "User" ("id")
ON DELETE SET NULL
ON UPDATE CASCADE;
