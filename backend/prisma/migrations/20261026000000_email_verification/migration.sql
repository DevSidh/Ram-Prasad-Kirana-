ALTER TABLE "User"
ADD COLUMN "emailVerified" BOOL NOT NULL DEFAULT true;

ALTER TABLE "User"
ADD COLUMN "phoneVerified" BOOL NOT NULL DEFAULT false;

CREATE TABLE "EmailVerificationOtp" (
    "email" STRING NOT NULL,
    "otpHash" STRING NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "attempts" INT4 NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "EmailVerificationOtp_pkey" PRIMARY KEY ("email")
);

CREATE INDEX "EmailVerificationOtp_expiresAt_idx"
ON "EmailVerificationOtp"("expiresAt");
