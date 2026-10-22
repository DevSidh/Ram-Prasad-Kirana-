CREATE TABLE IF NOT EXISTS "PendingRegistration" (
    "email" STRING NOT NULL,
    "name" STRING NOT NULL,
    "phone" STRING NOT NULL,
    "passwordHash" STRING NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PendingRegistration_pkey" PRIMARY KEY ("email")
);

ALTER TABLE "PendingRegistration" SET (schema_locked = false);

CREATE INDEX IF NOT EXISTS "PendingRegistration_expiresAt_idx"
ON "PendingRegistration"("expiresAt");

ALTER TABLE "PendingRegistration" SET (schema_locked = true);
