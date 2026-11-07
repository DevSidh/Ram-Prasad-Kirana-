CREATE TABLE IF NOT EXISTS "PosCataloguePriceChange" (
    "requestId" STRING NOT NULL,
    "cashierId" STRING NOT NULL,
    "changes" JSONB NOT NULL,
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "PosCataloguePriceChange_pkey" PRIMARY KEY ("requestId")
);
