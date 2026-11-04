-- Pending checkout is not a completed sale and consumes no stock until finalized.
ALTER TYPE "PosSaleStatus" ADD VALUE IF NOT EXISTS 'CHECKOUT';
ALTER TYPE "PosPaymentMethod" ADD VALUE IF NOT EXISTS 'FONEPAY';
ALTER TABLE "PosFonepayRequest" SET (schema_locked = false);
ALTER TABLE "PosFonepayRequest" ADD COLUMN IF NOT EXISTS "verifiedAt" TIMESTAMP(3);
ALTER TABLE "PosFonepayRequest" ADD COLUMN IF NOT EXISTS "autoPrintClaimedAt" TIMESTAMP(3);
ALTER TABLE "PosFonepayRequest" DROP CONSTRAINT IF EXISTS "PosFonepayRequest_state_check";
ALTER TABLE "PosFonepayRequest" ADD CONSTRAINT "PosFonepayRequest_state_check" CHECK ("state" IN ('CREATING','READY','PENDING','UNKNOWN','VERIFIED','PAID','TEST_VERIFIED','FAILED','EXPIRED','CANCELLED','STALE','REVIEW'));
ALTER TABLE "PosFonepayRequest" SET (schema_locked = true);
