CREATE SEQUENCE "user_display_id_seq" START 1;

ALTER TABLE "User" SET (schema_locked = false);

ALTER TABLE "User" ADD COLUMN "userNumber" INT8;

WITH numbered_users AS (
    SELECT
        "id",
        ROW_NUMBER() OVER (ORDER BY "createdAt", "id") AS "userNumber"
    FROM "User"
)
UPDATE "User" AS users
SET "userNumber" = numbered_users."userNumber"
FROM numbered_users
WHERE users."id" = numbered_users."id";

SELECT setval(
    'user_display_id_seq',
    COALESCE((SELECT MAX("userNumber") FROM "User"), 1),
    EXISTS(SELECT 1 FROM "User")
);

ALTER TABLE "User"
    ALTER COLUMN "userNumber" SET DEFAULT nextval('user_display_id_seq');
ALTER TABLE "User" ALTER COLUMN "userNumber" SET NOT NULL;
CREATE UNIQUE INDEX "User_userNumber_key" ON "User"("userNumber");

CREATE TABLE "BuyingStreakPurchaseDay" (
    "id" STRING NOT NULL,
    "userId" STRING NOT NULL,
    "dayKey" STRING NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "BuyingStreakPurchaseDay_pkey" PRIMARY KEY ("id")
);
ALTER TABLE "BuyingStreakPurchaseDay" SET (schema_locked = false);

CREATE TABLE "BuyingStreakRewardConfig" (
    "id" STRING NOT NULL,
    "day" INT4 NOT NULL,
    "title" STRING NOT NULL,
    "description" STRING NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "BuyingStreakRewardConfig_pkey" PRIMARY KEY ("id")
);
ALTER TABLE "BuyingStreakRewardConfig" SET (schema_locked = false);

CREATE TABLE "BuyingStreakRewardProgress" (
    "id" STRING NOT NULL,
    "userId" STRING NOT NULL,
    "day" INT4 NOT NULL,
    "title" STRING NOT NULL,
    "description" STRING NOT NULL,
    "unlockedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "claimedAt" TIMESTAMP(3),
    CONSTRAINT "BuyingStreakRewardProgress_pkey" PRIMARY KEY ("id")
);
ALTER TABLE "BuyingStreakRewardProgress" SET (schema_locked = false);

CREATE UNIQUE INDEX "BuyingStreakPurchaseDay_userId_dayKey_key"
    ON "BuyingStreakPurchaseDay"("userId", "dayKey");
CREATE UNIQUE INDEX "BuyingStreakRewardConfig_day_key"
    ON "BuyingStreakRewardConfig"("day");
CREATE UNIQUE INDEX "BuyingStreakRewardProgress_userId_day_key"
    ON "BuyingStreakRewardProgress"("userId", "day");
CREATE INDEX "BuyingStreakRewardProgress_userId_claimedAt_idx"
    ON "BuyingStreakRewardProgress"("userId", "claimedAt");

ALTER TABLE "BuyingStreakPurchaseDay"
    ADD CONSTRAINT "BuyingStreakPurchaseDay_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "BuyingStreakRewardProgress"
    ADD CONSTRAINT "BuyingStreakRewardProgress_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

WITH purchase_days AS (
    SELECT
        "userId",
        (("createdAt" + INTERVAL '5 hours 45 minutes')::DATE)::STRING AS "dayKey",
        MIN("createdAt") AS "createdAt"
    FROM "Order"
    WHERE "status" <> 'CANCELLED'
    GROUP BY "userId", (("createdAt" + INTERVAL '5 hours 45 minutes')::DATE)::STRING
),
numbered_days AS (
    SELECT
        'legacy-' || ROW_NUMBER() OVER (ORDER BY "userId", "dayKey") AS "id",
        "userId",
        "dayKey",
        "createdAt"
    FROM purchase_days
)
INSERT INTO "BuyingStreakPurchaseDay" ("id", "userId", "dayKey", "createdAt")
SELECT "id", "userId", "dayKey", "createdAt"
FROM numbered_days;

ALTER TABLE "Coupon" SET (schema_locked = false);
ALTER TABLE "Coupon"
    ADD COLUMN "isDeleted" BOOL NOT NULL DEFAULT false;

ALTER TABLE "User" SET (schema_locked = true);
ALTER TABLE "Coupon" SET (schema_locked = true);
ALTER TABLE "BuyingStreakPurchaseDay" SET (schema_locked = true);
ALTER TABLE "BuyingStreakRewardConfig" SET (schema_locked = true);
ALTER TABLE "BuyingStreakRewardProgress" SET (schema_locked = true);
