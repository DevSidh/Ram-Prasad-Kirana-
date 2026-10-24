CREATE TABLE "PasswordResetOtp" (
    "email" STRING NOT NULL,
    "otpHash" STRING NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "attempts" INT4 NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PasswordResetOtp_pkey" PRIMARY KEY ("email")
);

ALTER TABLE "PasswordResetOtp" SET (schema_locked = false);

CREATE INDEX "PasswordResetOtp_expiresAt_idx" ON "PasswordResetOtp"("expiresAt");

ALTER TABLE "PasswordResetOtp" SET (schema_locked = true);
