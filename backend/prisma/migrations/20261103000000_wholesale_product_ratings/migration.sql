ALTER TABLE "Product" SET (schema_locked = false);
ALTER TABLE "WholesaleItem" SET (schema_locked = false);
ALTER TABLE "Review" SET (schema_locked = false);

ALTER TABLE "Review" ALTER COLUMN "productId" DROP NOT NULL;
ALTER TABLE "Review" ADD COLUMN "wholesaleItemId" STRING;

ALTER TABLE "WholesaleItem"
    ADD COLUMN "rating" DECIMAL(65, 30) NOT NULL DEFAULT 0;
ALTER TABLE "WholesaleItem"
    ADD COLUMN "reviewCount" INT4 NOT NULL DEFAULT 0;

CREATE UNIQUE INDEX "Review_wholesaleItemId_userId_key"
    ON "Review"("wholesaleItemId", "userId");
CREATE INDEX "Review_wholesaleItemId_idx"
    ON "Review"("wholesaleItemId");

ALTER TABLE "Review"
    ADD CONSTRAINT "Review_wholesaleItemId_fkey"
    FOREIGN KEY ("wholesaleItemId")
    REFERENCES "WholesaleItem"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Review"
    ADD CONSTRAINT "Review_one_subject_check"
    CHECK (
        ("productId" IS NOT NULL AND "wholesaleItemId" IS NULL)
        OR ("productId" IS NULL AND "wholesaleItemId" IS NOT NULL)
    );

ALTER TABLE "Product" SET (schema_locked = true);
ALTER TABLE "WholesaleItem" SET (schema_locked = true);
ALTER TABLE "Review" SET (schema_locked = true);
