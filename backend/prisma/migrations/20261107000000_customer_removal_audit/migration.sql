ALTER TABLE "User" SET (schema_locked = false);

CREATE TABLE "CustomerRemovalAudit" (
    "id" STRING NOT NULL,
    "customerId" STRING NOT NULL,
    "customerDisplayId" INT8 NOT NULL,
    "removedById" STRING NOT NULL,
    "removedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "CustomerRemovalAudit_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "CustomerRemovalAudit" SET (schema_locked = false);

CREATE INDEX "CustomerRemovalAudit_removedAt_idx"
ON "CustomerRemovalAudit"("removedAt");

CREATE INDEX "CustomerRemovalAudit_customerId_removedAt_idx"
ON "CustomerRemovalAudit"("customerId", "removedAt");

ALTER TABLE "CustomerRemovalAudit"
ADD CONSTRAINT "CustomerRemovalAudit_customerId_fkey"
FOREIGN KEY ("customerId") REFERENCES "User"("id")
ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "CustomerRemovalAudit"
ADD CONSTRAINT "CustomerRemovalAudit_removedById_fkey"
FOREIGN KEY ("removedById") REFERENCES "User"("id")
ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "User" SET (schema_locked = true);
ALTER TABLE "CustomerRemovalAudit" SET (schema_locked = true);
