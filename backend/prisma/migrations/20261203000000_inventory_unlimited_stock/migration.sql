-- Turso/libSQL: this additive migration preserves all existing inventory.
ALTER TABLE "Inventory" ADD COLUMN "isUnlimited" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "WholesaleItem" ADD COLUMN "isUnlimited" BOOLEAN NOT NULL DEFAULT false;
