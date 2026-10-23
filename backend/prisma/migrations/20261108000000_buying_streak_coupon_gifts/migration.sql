ALTER TABLE "Coupon" SET (schema_locked = false);
ALTER TABLE "BuyingStreakRewardConfig" SET (schema_locked = false);
ALTER TABLE "BuyingStreakRewardProgress" SET (schema_locked = false);

ALTER TABLE "BuyingStreakRewardConfig"
ADD COLUMN "couponId" STRING;

ALTER TABLE "BuyingStreakRewardProgress"
ADD COLUMN "couponTemplateId" STRING,
ADD COLUMN "couponId" STRING;

CREATE UNIQUE INDEX "BuyingStreakRewardProgress_couponId_key"
ON "BuyingStreakRewardProgress"("couponId");

ALTER TABLE "BuyingStreakRewardConfig"
ADD CONSTRAINT "BuyingStreakRewardConfig_couponId_fkey"
FOREIGN KEY ("couponId") REFERENCES "Coupon"("id")
ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "BuyingStreakRewardProgress"
ADD CONSTRAINT "BuyingStreakRewardProgress_couponTemplateId_fkey"
FOREIGN KEY ("couponTemplateId") REFERENCES "Coupon"("id")
ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "BuyingStreakRewardProgress"
ADD CONSTRAINT "BuyingStreakRewardProgress_couponId_fkey"
FOREIGN KEY ("couponId") REFERENCES "Coupon"("id")
ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "Coupon" SET (schema_locked = true);
ALTER TABLE "BuyingStreakRewardConfig" SET (schema_locked = true);
ALTER TABLE "BuyingStreakRewardProgress" SET (schema_locked = true);
