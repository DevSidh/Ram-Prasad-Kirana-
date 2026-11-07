# FastStore migration tools — preparation only

**Not a production database replacement.** These tools export a consistent source
snapshot and build a lossless libSQL staging database. The backend runtime remains
CockroachDB/Prisma and cannot use this staging database yet. See the
[migration plan](../../docs/turso-migration-plan.md) for the outstanding runtime
and cutover gates. No Flutter changes are necessary for the preparation tools.

## Findings / source access

The source connection check on 2026-11-07 failed with SQLSTATE `53300` (connection
capacity rejection). No current source export or real-record verification was
possible. This check alone does not prove data is gone. Restore read access via
the CockroachDB console/support or obtain a current trusted export. Older
go-live backups may contain intentionally deleted demo records; do not restore
them automatically.

Express 4 / TypeScript / Prisma 5.22 use 54 models and 16 enums. They include
authentication, catalogue/images, room/batch inventory, suppliers, online orders,
POS sales/payments/refunds/exchanges, delivery, reviews, coupons, settings and
notifications. Financial Decimal fields are not uniformly fixed-scale. User
numbers use a BigInt sequence. Some inventory queries require row locks and
PostgreSQL functions. These must be converted and tested before runtime cutover.

## Install and generate (no database writes)

From the backend folder, regenerate the existing client. Then install the isolated
migration tool dependencies. The application dependency lockfile is unchanged.

```powershell
rtk npm run prisma:generate
cd database-migration
rtk npm ci --ignore-scripts
rtk npm run schema
rtk npm test
```

The generated [manifest](schema-manifest.json) and [SQL](staging-schema.sql) come
from the existing Prisma schema. Every model, scalar field, declared index,
unique key, foreign key and enum is included. Enum/boolean/JSON constraints are
enforced. Decimal strings, password hashes, binary images, UTC microseconds and
signed 64-bit values are retained without floating-point currency conversion.
Application defaults such as cuid, updatedAt and sequence allocation are NOT
implemented by the staging schema. No application should write to it.

## Read-only export

Keep the source URL in the private backend `.env`, as `COCKROACH_SOURCE_URL`, or
use the existing `DATABASE_URL`. TLS certificate verification is mandatory.
Never paste secrets into chat, commands, Git or issue reports.

```powershell
rtk npm run source:check
rtk npm run export -- --out="C:/FastStore-private-backups/current-export"
```

The destination must be new and its parent must exist. Use a private directory
outside Git and restrict its Windows ACL to the operator account. Encrypt the
backup at rest and keep an independent copy. The export includes all public
tables, their fields, source DDL, exact text values and per-file SHA256 hashes.
It runs in a single read-only snapshot transaction with bounded batches and
connection/query timeouts. A manifest is written only after successful commit.
Partial directories are not valid backups. Export never writes to source tables.

Unknown source tables are backed up but require an explicit import mapping.
Prisma migration history is backed up as data, not executed on Turso. Missing
models/columns/schema drift stop import. A known model explicitly recorded as
absent from the source schema is created empty in staging; its manifest records
that no source rows existed. No historical rows are fabricated.

## Validate and build a local staging file

Default import only validates the snapshot; it does not contact Turso:

```powershell
rtk npm run import -- --source="C:/FastStore-private-backups/current-export"
```

Set `TURSO_DATABASE_URL=file:C:/FastStore-private-backups/staging.db` and
`TURSO_MIGRATION_TARGET=staging` in the private backend environment. Then:

```powershell
rtk npm run import -- --source="C:/FastStore-private-backups/current-export" --apply-staging --local
```

Only empty targets are accepted. DDL and records are imported atomically with
deferred foreign keys to support cyclic relationships. All counts and canonical
record digests are checked before commit, including hashes and images. Any error
rolls back. Repeating the identical import verifies existing data without adding
duplicates. Another snapshot or any unrelated nonempty database is refused.

No automatic write retries occur: uncertain commit responses are resolved by
rerunning the same snapshot and verifying its import marker and all records.

## Turso Cloud staging and future deployment

Use a **libSQL-compatible** Turso database. Official ORM guidance currently uses
[`@libsql/client`](https://docs.turso.tech/sdk/ts/reference). The newer native
Turso engine has a different SDK/compatibility matrix.

Interactive remote transactions have short time limits. This tool therefore
builds the complete file locally instead of partially committing remote batches.
Use the official [SQLite import workflow](https://turso.tech/blog/migrating-data-from-mysql-to-turso)
to upload the verified file to a NEW staging database:

```powershell
rtk proxy turso db create faststore-migration-staging --from-file C:/FastStore-private-backups/staging.db
```

Obtain the database URL/token privately from Turso. Set `TURSO_DATABASE_URL` and
`TURSO_AUTH_TOKEN` on the backend environment, then run read-only verification:

```powershell
rtk npm run import -- --source="C:/FastStore-private-backups/current-export" --verify-remote
```

This has **not** been verified against a real Turso account. It verifies all rows
and consumes reads; run during migration, not on every backend startup. Check
actual file size and query volume against your current plan limits.

**Do not deploy the app against this schema.** The runtime adapter, exact scaled
currency operations, aggregate/sort semantics, sequence allocation, stock SQL,
startup scripts and Docker/CI still require conversion and API integration tests.
No production environment, server startup scripts or historical migrations have
been changed. Preserve the source cluster, uploads, business files and backups.

## Validation performed

Local integration tests exercise all 54 staging tables with synthetic records,
exact large Decimal and BigInt values, microsecond timestamps, blobs, enums,
foreign keys, checksum corruption, rollback, identical import retries and refusal
to overwrite existing data. These tests do not validate the application runtime
on Turso. Registration/login/cart/checkout/printing/live data and remote Turso
connectivity remain unverified.
