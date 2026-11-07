# CockroachDB → Turso migration plan

## Status: preparation, NOT a production cutover

The running Express/TypeScript backend uses Prisma 5.22 with the CockroachDB
provider. Flutter accesses REST endpoints, not the database. The current schema
contains 54 business models. Historical CockroachDB migrations and the current
runtime are deliberately preserved until a replacement runtime passes integration
tests. Do not point `DATABASE_URL` at Turso: the existing Prisma engine cannot use
a libSQL connection.

## Required gates

1. Inventory the Prisma models, relationships, defaults, unique constraints,
   indexes, raw SQL and deployment entry points. Generate a schema manifest from
   the actual schema; fail on unsupported declarations rather than omit them.
2. Obtain a consistent, current source export. Use a read-only transaction. Never
   restore old go-live cleanup backups without approval: they can contain demo
   customers and transactions intentionally deleted from the store.
3. Create a private Turso **libSQL-compatible** database and configure credentials
   only on the backend. The official Turso documentation currently recommends
   `@libsql/client` for Prisma/ORM integration. The newer native Turso engine has a
   different SDK and compatibility matrix.
4. Stage all source fields losslessly with IDs and relationships unchanged.
   Currency must not pass through SQLite REAL or JavaScript Number. The staging
   schema stores canonical decimal strings as TEXT; this is a lossless migration
   format, **not a finished application storage contract**. Before runtime cutover,
   define audited integer scales for currency, quantities, rates and ratings;
   reject values which cannot be represented exactly. Existing API decimals must
   retain their original meanings.
5. Replace the runtime client with a maintained Prisma/libSQL adapter and verify
   nested relations, decimal conversion, aggregates, sorting and filters. Replace
   `FOR UPDATE`, `NOW()`, PostgreSQL casts and sequence defaults. Provide atomic
   user-number allocation and serializable stock writes; retry only rollback-safe
   transactions, never an ambiguously committed payment.
6. Update server startup, admin creation, seeding, health checks, Docker and CI.
   Disable Cockroach recovery scripts only when the Turso runtime is selected.
   Do not execute either provider's migration chain against the wrong database.
7. Validate every API workflow on isolated data: authentication, CRUD, cart,
   checkout/cancellation, inventory rooms/batches, POS/refunds/exchanges,
   payment idempotency, delivery, reports and notifications. Test foreign keys,
   rollback, concurrent stock depletion and decimal round trips.
8. Freeze source writes, make a final export, import and compare every record,
   hash, count and foreign key. Deploy only after successful validation and an
   explicit operator cutover. Keep the original database and encrypted backups.

## Database consumers

- `backend/src/server.ts`: authentication, public catalogue, carts and orders,
  API composition and health checks.
- `backend/src/routes/`: administration, POS billing, inventory rooms, suppliers,
  account, reviews, delivery, password reset and email verification.
- `backend/src/services/`: stock/batches, rooms, transaction retry, identities,
  coupons/streak rewards, POS price changes and related business services.
- Admin/seed commands and recovery/deployment scripts create additional clients.
- Cockroach native types include unconstrained Decimal, fixed-scale Decimal,
  BigInt sequences, JSON, Bytes and timezone-aware timestamps.
- Existing financial data and password hashes must be exported without conversion
  through floating point or plaintext password regeneration.

## Documentation consulted

- https://docs.turso.tech/sdk/ts/reference
- https://docs.prisma.io/docs/orm/core-concepts/supported-databases/sqlite
- https://docs.prisma.io/docs/orm/v6/overview/databases/turso

Free-plan suitability must be measured from actual source storage and query usage;
it cannot be guaranteed before a current export and load tests are available.
