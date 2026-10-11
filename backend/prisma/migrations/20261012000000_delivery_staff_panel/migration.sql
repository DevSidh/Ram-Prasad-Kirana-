ALTER TYPE "DeliveryStatus" ADD VALUE IF NOT EXISTS 'ACCEPTED';
ALTER TYPE "DeliveryStatus" ADD VALUE IF NOT EXISTS 'DECLINED';
ALTER TYPE "DeliveryStatus" ADD VALUE IF NOT EXISTS 'CANCELLED';
ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'DELIVERY_ASSIGNED';
ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'DELIVERY_UPDATED';

ALTER TABLE "User"
ADD COLUMN IF NOT EXISTS "isAvailable" BOOL NOT NULL DEFAULT true;

ALTER TABLE "Delivery"
ADD COLUMN IF NOT EXISTS "cashCollected" DECIMAL(65,30) NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS "cashCollectedAt" TIMESTAMP(3);

CREATE TABLE IF NOT EXISTS "DeliveryStatusHistory" (
    "id" STRING NOT NULL,
    "deliveryId" STRING NOT NULL,
    "changedById" STRING NOT NULL,
    "status" "DeliveryStatus" NOT NULL,
    "note" STRING,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "DeliveryStatusHistory_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "DeliveryStatusHistory_deliveryId_idx"
ON "DeliveryStatusHistory"("deliveryId");
CREATE INDEX IF NOT EXISTS "DeliveryStatusHistory_changedById_idx"
ON "DeliveryStatusHistory"("changedById");
CREATE INDEX IF NOT EXISTS "DeliveryStatusHistory_createdAt_idx"
ON "DeliveryStatusHistory"("createdAt");

ALTER TABLE "DeliveryStatusHistory"
ADD CONSTRAINT IF NOT EXISTS "DeliveryStatusHistory_deliveryId_fkey"
FOREIGN KEY ("deliveryId") REFERENCES "Delivery"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "DeliveryStatusHistory"
ADD CONSTRAINT IF NOT EXISTS "DeliveryStatusHistory_changedById_fkey"
FOREIGN KEY ("changedById") REFERENCES "User"("id")
ON DELETE RESTRICT ON UPDATE CASCADE;
