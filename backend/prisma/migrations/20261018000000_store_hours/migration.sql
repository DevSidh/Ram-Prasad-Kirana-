CREATE TABLE "StoreSetting" (
    "id" STRING NOT NULL DEFAULT 'store',
    "isOrderingEnabled" BOOL NOT NULL DEFAULT true,
    "weeklyHours" JSONB NOT NULL,
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "StoreSetting_pkey" PRIMARY KEY ("id")
);

INSERT INTO "StoreSetting" ("id", "isOrderingEnabled", "weeklyHours")
VALUES (
    'store',
    true,
    '[{"day":1,"isOpen":true,"openTime":"00:00","closeTime":"23:59"},{"day":2,"isOpen":true,"openTime":"00:00","closeTime":"23:59"},{"day":3,"isOpen":true,"openTime":"00:00","closeTime":"23:59"},{"day":4,"isOpen":true,"openTime":"00:00","closeTime":"23:59"},{"day":5,"isOpen":true,"openTime":"00:00","closeTime":"23:59"},{"day":6,"isOpen":true,"openTime":"00:00","closeTime":"23:59"},{"day":7,"isOpen":true,"openTime":"00:00","closeTime":"23:59"}]'::JSONB
);
