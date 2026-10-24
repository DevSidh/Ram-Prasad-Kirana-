# Production Migration Audit and Release Runbook

This is a read-only review of the local Prisma migrations and the configured
production migration metadata. It does not authorize or perform a migration,
schema/data change, restore, cloud-resource creation, or deployment.

## Verified scope and current state

- Prisma schema: `backend/prisma/schema.prisma`; datasource provider is
  CockroachDB and reads `DATABASE_URL`.
- Prisma CLI/client used locally: 5.22.0 (the backend manifest allows
  `^5.10.2`).
- Migration lock provider: CockroachDB.
- The backend `prestart` script runs `npm run prisma:migrate:deploy` before
  `npm start`.
- The configured target was checked without printing credentials and matched
  the previously confirmed production database.
- On 2026-10-24, `npx prisma migrate status` found 35 migrations and reported
  these three as not applied:
  `20261110000000_admin_pos_billing`,
  `20261111000000_billing_staff_role`, and
  `20261112000000_pos_exchanges`.
- A separate read-only query selected only
  `migration_name`, `started_at`, `finished_at`, and `rolled_back_at` from
  `_prisma_migrations`; it did not select migration logs. There were 65
  attempt rows across 32 recorded migration names: 32 names had at least one
  finished, non-rolled-back attempt; 33 earlier attempts were marked rolled
  back; none had an unfinished, non-rolled-back attempt; there were no
  database-only migration names. The three pending names had no history rows.
  Thus the rolled-back rows are prior attempts, not a substitute for the
  successful records. Their logs and causes were not inspected.
- A read-only public health request returned `status: ok` and
  `database: connected`. This does not verify schema correctness, migration
  compatibility, or application workflows.
- The project owner supplied CockroachDB Cloud restore-history details:
  restore job `1221432207468920956`, selected backup 2026-10-24 05:30:00 UTC,
  start 06:04:41 UTC, completion 06:07:23 UTC, and reported status
  `succeeded`. The owner reported destination name
  `ram-prasad-storeCluster` and destination page ID
  `ce59dda7-4cfd-4cd4-b34f-8e92ee7a0d27`; the source cluster ID was not
  supplied. These are owner-provided values, not independently verified
  against CockroachDB's restore-job record.
- A read-only `crdb_internal.cluster_id()` query against the configured
  production database was denied by CockroachDB because access to
  `crdb_internal` and `system` is restricted. The documented hint was to
  enable `allow_unsafe_internals`, which was not done. The CockroachDB Cloud
  page opened to the reported destination ID required login, so the restore
  job/source ID could not be independently inspected here.
- The owner-provided recovery reconciliation report states that actual
  queries, comparison totals, and discrepancy results were not provided.
  Orders, payments/refunds, and inventory movements across the recovery
  cutoff therefore remain unverified.
- The repository is on `main` at `7d7dbed51f23a55383ad27f1d7ece9ca9236b097`,
  with relevant local changes uncommitted. Render's deployed revision was not
  verified; this commit is not identified as the release candidate.
- **Date anomaly:** the local migration sequence includes names dated after
  2026-10-24, and production metadata has successful records through
  `20261109000000_coupon_announcement_state`. The names may have been
  intentionally pre-dated, but intent and timeline were not established.
  Do not rename or reorder these migrations. Confirm the convention and
  production deployment history with the release owner before approval.

`migrate status` and history metadata do not prove that the live schema matches
the Prisma schema or that data is correct after the reported restore. No live
schema-drift comparison or transaction reconciliation was performed.

## Migration-by-migration review

Execution order is lexicographic timestamp order. All migrations through
`20261109000000_coupon_announcement_state` have a successful production
history record; the final three are pending. “Additive” does not mean
zero-risk: CockroachDB schema changes, unique indexes, foreign keys, defaults,
and backfills still need staging validation. There are no companion down
migrations; a database restore or forward correction would require a separate
recovery decision.

| # | Migration | Scope, dependencies, and risk |
|---:|---|---|
| 1 | `20261007231846_init` | Initial core schema, enums, tables, indexes, and relations. Baseline dependency for all later migrations. High-impact baseline; do not replay or reconstruct from this file against an existing database. |
| 2 | `20261009000000_password_reset_otp` | Creates OTP storage and expiry index. Additive; depends on the baseline only. New table/index build; OTP data is operationally sensitive. |
| 3 | `20261009000001_address_instructions` | Adds optional `Address.instructions`. Additive nullable column; depends on `Address`. |
| 4 | `20261010000000_user_avatar` | Adds optional `User.avatarUrl`. Additive nullable column; depends on `User`. |
| 5 | `20261011000000_device_push_tokens` | Adds token table, unique token index, user index, and cascading `User` foreign key. Additive; uniqueness and cascade semantics need to match token lifecycle. |
| 6 | `20261012000000_delivery_staff_panel` | Adds delivery/notification enum values, user availability and delivery cash fields with defaults, status-history table/indexes and foreign keys. Additive; defaults mark existing users available and existing cash as zero, which may not represent historical facts. Depends on delivery and notification enums/tables. |
| 7 | `20261013000000_delivery_cash_handover` | Adds handover amount/time with zero default. Additive; existing deliveries appear to have no handover amount. Depends on `Delivery`. |
| 8 | `20261014000000_user_token_version` | Adds `User.tokenVersion` with zero default. Additive; existing sessions receive the default version. Depends on `User`. |
| 9 | `20261015000000_user_avatar_image_data` | Adds optional avatar bytes and MIME type. Additive nullable columns; increases possible row/storage size. Depends on `User`. |
| 10 | `20261016000000_product_shared_image_and_units` | Adds product image bytes/MIME type and required unit label with default. Additive; default unit assignment for existing products must be correct. Depends on `Product`. |
| 11 | `20261017000000_wholesale_catalog` | Adds wholesale flag, price, and minimum quantity to `Product`, with defaults for flags/quantity. Additive; old rows are assigned non-wholesale and a minimum of one. |
| 12 | `20261018000000_store_hours` | Creates `StoreSetting` and inserts the singleton `store` row. Data-seeding migration; a conflicting/pre-existing singleton or partial prior execution requires inspection. |
| 13 | `20261019000000_low_stock_threshold` | Adds product threshold with default 10. Additive; default may not suit every existing product. |
| 14 | `20261020000000_restock_receipt_staff` | Adds optional inventory-transaction actor, index, and `User` foreign key with `SET NULL`. Additive; existing history remains unattributed. |
| 15 | `20261021000000_persistent_cart_and_images` | Adds cart wholesale flag and creates stored-image table. Additive; review image-storage growth and compatibility with existing image URLs/data. |
| 16 | `20261022000000_order_delivery_schedule` | Adds optional scheduled-delivery timestamp. Additive nullable column; depends on `Order`. |
| 17 | `20261023000000_live_delivery_location` | Adds optional delivery coordinates/update time and query indexes. Additive; index builds and location-data privacy/retention need consideration. |
| 18 | `20261023123000_barcode_inventory_batches` | Adds barcode and a unique index, batch/allocation tables, indexes/FKs, then backfills one legacy batch per positive inventory row. Backfill marks dates unverified/no-expiry false and copies current stock into received and remaining quantities; validate barcode uniqueness and stock/batch reconciliation. High data-integrity risk. |
| 19 | `20261024000000_separate_wholesale_catalog` | Creates `WholesaleItem`, copies eligible wholesale products, makes cart/order product links nullable, adds wholesale links/flags, rewrites cart references and wholesale order flags, then resets legacy product wholesale fields. High-risk data transformation. Verify all legacy product/cart/order mappings: the SQL sets `OrderItem.isWholesale` but does not populate `OrderItem.wholesaleItemId`; ensure intended historical association/display behavior is acceptable. Constraint changes and updates are not automatically reversible. |
| 20 | `20261025000000_product_vending_drink` | Adds `Product.isVendingDrink` with false default. Additive; existing products become non-vending. |
| 21 | `20261026000000_email_verification` | Adds email/phone verification flags and OTP table/index. Existing emails default verified while phone defaults unverified; verify that these defaults match the account-verification policy. |
| 22 | `20261030000000_normalized_product_images` | Adds optional normalized image bytes/MIME fields to product, wholesale, and stored images. Additive nullable fields; increases potential storage usage. |
| 23 | `20261031000000_coupon_per_user_limit` | Adds optional coupon limit and an order lookup index. Additive; index build cost depends on order size. |
| 24 | `20261101000000_pending_registration_verification` | Creates pending-registration table/index with `IF NOT EXISTS`; temporarily toggles schema lock. Additive and partially idempotent, but a pre-existing table with different structure would not be repaired by `IF NOT EXISTS`. |
| 25 | `20261102000000_user_ids_buying_streak` | Creates user-number sequence, backfills every user using creation time/id order, makes the number required/unique, seeds streak purchase-days from non-cancelled orders using a fixed +05:45 day boundary, and adds reward tables plus `Coupon.isDeleted`. High-risk data transformation: validate sequence, uniqueness, user-number semantics, date boundary, and exact order inclusion. A rerun/partial application could duplicate or alter identifiers. |
| 26 | `20261103000000_wholesale_product_ratings` | Allows nullable review product, adds wholesale review relation/rating fields/indexes and a check requiring exactly one review subject. Potential existing-row/check/unique/FK conflicts; data must satisfy the new exactly-one-subject rule. |
| 27 | `20261104000000_customer_menu_and_drink_sections` | Adds optional vending section and store feature JSON with empty-object default; toggles schema lock. Additive; validate JSON consumers and existing locked-table handling. |
| 28 | `20261105000000_weight_quantities_and_customer_live_location` | Adds weight/location fields and rewrites inventory, batch, transaction quantities/balances based on parsed product unit labels. **Very high risk:** a conversion error, unexpected unit label, or second application can materially change inventory/history. Validate sample calculations and totals by unit before any execution; preserve pre-migration values/recovery point. |
| 29 | `20261106000000_customer_product_coupons_and_product_gallery` | Adds image URL JSON and optional coupon product/user links with indexes/FKs; toggles schema lock. Additive, but FK validity, delete cascade behavior for assigned users, and large-table index cost require review. |
| 30 | `20261107000000_customer_removal_audit` | Creates removal-audit table/indexes with restrictive customer/actor foreign keys. Additive; `RESTRICT` can block user deletion and is coupled to account-removal behavior. |
| 31 | `20261108000000_buying_streak_coupon_gifts` | Adds coupon references to reward configuration/progress, unique coupon index and `SET NULL` FKs; toggles schema lock. Additive; existing duplicate/non-null coupon references or FK mismatches can block creation. |
| 32 | `20261109000000_coupon_announcement_state` | Adds announcement flag, backfills it for eligible public coupons, and rewrites codes for deleted coupons to `REMOVED-<id>`. Data-transforming; changes coupon-code values and announcement state. Review historical order/reporting semantics and uniqueness before/after. |
| 33 | `20261110000000_admin_pos_billing` | **Pending.** Creates POS shift/sale/item/held-sale/refund/cash-movement enums, tables, indexes, and FKs to user/product/POS rows. Additive and no data backfill; depends on existing `PaymentStatus`, `User`, and `Product`. Restrictive FKs preserve financial history but affect future deletes. Cockroach DDL/index behavior must be tested against a separate database. |
| 34 | `20261111000000_billing_staff_role` | **Pending.** Adds `BILLING_STAFF` to `UserRole`. Additive enum change; app/Prisma/client compatibility matters. Do not grant the role until compatible backend code is deployed and verified. |
| 35 | `20261112000000_pos_exchanges` | **Pending.** Creates exchange enums, exchange/item tables, idempotency uniqueness, indexes and FKs to sale/user/shift/item/product. Depends on migrations 33 and 34 plus pre-existing tables. Additive; verify Cockroach enum/DDL support, constraints, idempotency behavior, and intended `SET NULL`/`RESTRICT` semantics. |

### Cross-cutting migration risks

- Static review found no direct `DROP TABLE`, `TRUNCATE`, or `DELETE FROM`.
  That does not make the sequence lossless: migrations 19, 25, 28, and 32
  rewrite existing values; migration 19 also drops/replaces a constraint and
  resets legacy wholesale fields.
- Many files toggle CockroachDB `schema_locked`; an interrupted migration may
  leave a table in an unexpected operational state. Inspect actual DDL and
  metadata before considering any retry.
- Unique indexes, check constraints, and foreign keys can fail on inconsistent
  existing data or schema drift. Do not infer production schema correctness
  from a successful migration record.
- SQL is authored for CockroachDB, but exact cluster-version compatibility,
  schema-change duration, lock/contention, and index-build impact have not
  been tested against a clone of the production database.
- There are no migration down scripts. Reverting application binaries does
  not reverse DDL or data transformations.

## Recovery evidence and open risks

- Owner-provided restore evidence says job `1221432207468920956` succeeded,
  using the 2026-10-24 05:30 UTC backup, with restore start at 06:04:41 UTC
  and completion at 06:07:23 UTC. The destination display name and page ID
  were supplied, but the source cluster ID is absent and neither ID was
  verified against the restore-job details. The configured database's cluster
  ID could not be queried through supported SQL because CockroachDB restricts
  access to its internal schema. Do not enable unsafe internals to work around
  that restriction.
- The supplied recovery-cutoff report explicitly says reconciliation results
  were not provided. Orders/payments/refunds/exchanges, inventory movements
  and stock totals, customer records, and activity around the backup/PITR
  cutoff have not been reconciled from authoritative records. The reported
  spot checks do not establish complete recovery.
- Do not restore again speculatively. Obtain the provider restore-job metadata
  (source/destination cluster IDs, backup/PITR timestamp, completion status),
  preserve it, identify the transaction cutoff, and reconcile affected records
  read-only. Escalate uncertainty or discrepancies to CockroachDB support.
- Block production migration/deployment until restore provenance and required
  business-data reconciliation are accepted by the owner or an explicit,
  documented risk decision is approved.

## Local SQL rehearsal results

- A disposable CockroachDB CCL v26.3.0 single-node server was started on
  loopback only. No Docker CLI or existing separate staging database was
  available.
- The exact SQL files for the three pending billing migrations were executed
  in dependency order against an isolated synthetic schema containing the
  prerequisite `User`, `Product`, `UserRole`, and `PaymentStatus` objects.
  All three SQL files completed successfully on that fixture. This was a
  limited SQL compatibility probe: it did not use Prisma's migration runner,
  production schema/data, representative application data, or the production
  CockroachDB version. It does not satisfy a staging rehearsal.
- A separate attempt to run the complete 35-migration Prisma sequence against
  an empty disposable CockroachDB v26.3.0 database stopped at
  `20261009000000_password_reset_otp`. After creating `PasswordResetOtp`, its
  `CREATE INDEX` failed because CockroachDB reported the table schema-locked
  and required `ALTER TABLE ... SET (schema_locked = false)`. No workaround,
  migration resolve, or SQL edit was attempted. This finding blocks claiming
  that the entire migration chain has been rehearsed on this CockroachDB
  version. The disposable local server and its specific temporary store/logs
  were stopped and removed.

## Local release candidate status (2026-10-24)

- The reviewed local application and migration changes are committed on
  `release/pos-billing-20261024` as implementation candidate
  `9f41143dc76cb69b44e10e36401079e5a8dd5312`. This commit is local only; it
  has not been pushed or deployed, and Render's deployed revision remains
  unverified.
- The candidate includes the three billing migrations, backend routes/schema
  and tests, Flutter admin/POS screens and services, Windows runner sources,
  and release documentation. It does not include environment files,
  `android/app/google-services.json`, generated release binaries, or profiler
  output.
- Local-only generated/configuration files remain outside the commit. Do not
  treat the worktree as clean or copy those files into the release without
  separately reviewing their contents and handling secrets safely.

## Proposed controlled rollout (not executed)

1. **Resolve release identity.** Review the complete local diff and tests,
   then verify the local candidate above is the intended release commit.
   It has not been pushed; `main`'s current SHA is not a substitute for the
   billing work. Verify the intended Render service and its actual deployed
   revision before approving any deployment.
2. **Resolve recovery readiness.** Verify restore job identifiers and
   completion evidence in CockroachDB Cloud; reconcile the transaction window
   around the backup/PITR cutoff as above. Confirm an accepted recovery point.
3. **Reconfirm production state.** From a securely configured, authorized
   environment, repeat `npx prisma migrate status` and read only migration
   names/lifecycle fields from `_prisma_migrations` (never `logs`). Inspect
   failed/open/rolled-back records and compare read-only Cockroach schema
   metadata with the intended Prisma schema. Investigate any drift before
   proceeding.
4. **Review and rehearse.** Review all pending SQL in order and verify current
   data preconditions for any uniqueness, FK, check-constraint, and rewrite
   operations. Test the exact release commit and migration sequence against a
   separate non-production database. Prefer an already available test
   environment. Creating a separate CockroachDB cluster/database can incur
   usage or storage charges; do not create one until the owner approves the
   resource and its cost. Use only synthetic/test data and test credentials.
5. **Plan compatibility and window.** Schedule a controlled window with the
   backend/database owner. Ensure no uncoordinated release or restart runs
   migrations concurrently. Do not grant billing roles before the backend
   understands the new enum. The POS tables are additive, but data rewrite
   migrations in the overall sequence make a compatibility and restore plan
   mandatory.
6. **Choose one migration executor.** Render Shell is unavailable on the
   reported free plan and no verified Render pre-deploy command is configured.
   The local backend's `prestart` automatically executes
   `prisma migrate deploy`; inspect Render's service instance count, start
   command, and deploy behavior with the service owner. If approved, use one
   securely configured one-off process on an authorized operator machine or
   a hosting-supported single-run job. Inject secrets through a secure
   environment mechanism; do not print, paste, commit, or put them in Flutter
   or Windows artifacts.
7. **Execute only after explicit approval.** The intended command is
   `npm run prisma:migrate:deploy` from `backend`, against the independently
   re-confirmed production target, using the reviewed release commit and one
   executor. It is a database-writing command and has not been run here. Do
   not combine it with `migrate dev`, `db push`, reset, resolve, or manual
   history edits.
8. **Verify before application rollout.** Preserve credential-free output.
   Repeat `npx prisma migrate status`; confirm the exact expected migrations
   are finished, with no unexplained pending, open, or failed attempt. Read
   schema metadata and validate core API health. On error, stop; inspect the
   actual schema and migration records read-only, preserve diagnostics, and
   get owner/provider review. Do not blindly retry partially applied SQL.
9. **Deploy matching backend revision.** Only after migration verification,
   deploy the reviewed commit to the verified Render service. Account for
   `prestart`: it will still invoke `migrate deploy`; confirm migration is
   already complete and coordinate instance startup so no process overlaps
   the controlled migration. Confirm deployed commit in Render; health alone
   is not proof of revision.
10. **Run authorized workflow checks.** Use approved accounts and test data:
    admin and cashier role boundaries, shift open/close and cash variance,
    barcode/product search, checkout/receipt/stock, held/resumed/discarded
    bills, pending/cash/digital payment recording, refund decisions,
    exchanges/refund differences, retries/idempotency, inventory adjustments,
    and customer/order workflows. Do not create real production transactions
    without separate explicit approval and a cleanup/accounting procedure.
    Verify physical printer output separately on shop hardware.

## Release artifact and verification record

At the last local build, before any production changes:

- Windows executable:
  `build\windows\x64\runner\Release\RamPrasadStore.exe`
- Windows release bundle:
  `build\RamPrasadStore-Windows-x64-release.zip`
- Android release APK:
  `build\app\outputs\flutter-apk\app-release.apk`

The Windows ZIP contains the complete release directory (runner, Flutter
runtime, plugins, and data), not just the `.exe`. The app's release API URL
defaults to the HTTPS production endpoint in `lib/core/constants.dart`; a
release build can override it with `API_BASE_URL`. Do not embed database
credentials or privileged tokens in either client.

The most recent local checks for the pagination/shift-history changes passed:
Flutter analysis and full tests; backend TypeScript build and full configured
tests; Prisma validation/client generation; Windows release build; Android
release build; and `git diff --check`. These are local compile/unit-test/build
results, not live authenticated workflow, restore, printer, or production
schema-drift verification.
