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
- The configured backend target was inspected without printing credentials:
  database `ram_prasad_store`, schema `public`, CockroachDB cluster name
  `ram-prasad-store`, in AWS ap-south-1. The current Cloud console identifies
  the cluster page as `ram-prasad-store` with page ID
  `ce59dda7-4cfd-4cd4-b34f-8e92ee7a0d27`. The configured host/region and
  console cluster name align; no supported SQL query independently mapped
  the configured endpoint to that UUID.
- Read-only production metadata on 2026-10-24 reports CockroachDB CCL
  v26.2.7, `create_table_with_schema_locked=on`,
  `sql.defaults.create_table_with_schema_locked=true`, and
  `sql.schema.auto_unlock.enabled=true`. `SHOW CREATE TABLE` reports both
  `PasswordResetOtp` and `Product` currently `schema_locked=true`. These are
  current values; they do not establish what settings were in force when
  historical migrations were applied.
- A read-only `prisma migrate status` recheck on 2026-10-24 found 35
  migrations and reported these three as not applied:
  `20261110000000_admin_pos_billing`,
  `20261111000000_billing_staff_role`, and
  `20261112000000_pos_exchanges`.
- A separate read-only query on the configured target selected only
  `migration_name`, `started_at`, `finished_at`, and `rolled_back_at` from
  `_prisma_migrations`; it did not select migration logs. There were 65
  attempt rows: 32 distinct names have a successful, non-rolled-back attempt;
  33 attempts are marked rolled back; none are unfinished; and there are no
  database-only migration names. The three pending names have no history
  rows. Rolled-back attempts are historical attempts, not evidence of a
  currently failed migration; their logs and causes were not inspected.
- A prior read-only public health request returned `status: ok` and
  `database: connected`. This does not verify schema correctness, migration
  compatibility, or application workflows.
- CockroachDB Cloud's current Restore Jobs page independently shows job
  `1221432207468920956`, source display name `ram-prasad-store`, destination
  display name `ram-prasad-store`, backup time 2026-10-24 05:30:00 UTC,
  status `succeeded`, start 06:04:41 UTC, and end 06:07:23 UTC. The job row
  does not show either cluster UUID. The destination display name matches
  the currently open cluster page, whose ID is
  `ce59dda7-4cfd-4cd4-b34f-8e92ee7a0d27`, but the restore record does not
  itself establish that UUID mapping. The source cluster UUID remains
  unavailable.
- The CockroachDB Cloud cluster list for the accessible account shows only
  one cluster, `ram-prasad-store`; no separate staging cluster is available
  in that account view. No separate staging database was verified.
- A read-only `crdb_internal.cluster_id()` query against the configured
  production database was denied by CockroachDB because access to
  `crdb_internal` and `system` is restricted. The documented hint was to
  enable `allow_unsafe_internals`, which was not done. The active console page
  currently loads for the destination display name; an earlier navigation
  logged a `cluster not found` event. The restore-job row verifies names and
  status, but not source/destination UUIDs.
- The owner-provided recovery reconciliation report states that actual
  queries, comparison totals, and discrepancy results were not provided.
  Orders, payments/refunds, and inventory movements across the recovery
  cutoff therefore remain unverified.
- The implementation candidate is commit
  `9f41143dc76cb69b44e10e36401079e5a8dd5312` on local branch
  `release/pos-billing-20261024`; it has not been pushed or deployed. The
  current local branch HEAD is
  `ca1023f53480b1f0c30ea4857c1d450f25646cdd`. Local generated/configuration
  files remain untracked or modified and excluded from the candidate.
  Render's deployed revision remains unverified.
- Owner-supplied Render information says the configured start command is
  `npm start`, auto-deploy is set to `On Commit`, the latest supplied log says
  `No pending migrations to apply`, and `WEB_CONCURRENCY=1` is present. The
  repository independently confirms `npm start` invokes `node dist/server.js`
  and its `prestart` runs `prisma migrate deploy`. The deployed SHA and live
  Render instance count remain unavailable; `WEB_CONCURRENCY=1` is not an
  instance-count measurement. The supplied log statement conflicts with this
  session's read-only Prisma status, which reports three pending migrations;
  log service, time, and deployed revision were not provided, so it cannot
  resolve the discrepancy.
- **Date anomaly:** 16 of the 35 local migration directory timestamps are
  later than 2026-10-24 (20261025 through 20261112). Git records show several
  future-dated migrations were introduced before their directory timestamps:
  for example, `20261109000000_coupon_announcement_state` entered Git on
  2026-10-23, while the three billing migrations are in the 2026-10-24
  candidate but named November 10-12. Production history has successful
  records through the November 9 name, also later than the stated current
  date. This proves the filename timestamps were used ahead of wall-clock
  dates in this repository, but does not explain the release convention or
  reported production chronology. Do not rename/reorder migrations. Obtain
  written release-owner confirmation of the intended dates and sequence.

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

- CockroachDB Cloud's Restore Jobs page confirms the restore job's source and
  destination display names are both `ram-prasad-store`, its selected backup
  was 2026-10-24 05:30 UTC, and it succeeded between 06:04:41 and 06:07:23
  UTC. The page does not expose either cluster UUID. The open destination
  cluster page shows UUID `ce59dda7-4cfd-4cd4-b34f-8e92ee7a0d27`, but its
  relationship to the restore job and configured endpoint is not proven by
  the restore row. Source UUID is unavailable. A supported SQL lookup of the
  configured cluster ID was denied; do not enable unsafe internals.
- The supplied recovery-cutoff report has no interval, aggregate counts or
  amounts, discrepancy result, reconciliation completion status, or verifier.
  Orders/statuses/totals, payments/refunds, exchanges, inventory movements,
  returns, adjustments, and resulting stock are not reconciled against
  authoritative records. Spot checks do not establish completeness.
- Do not restore again speculatively. Obtain authoritative restore-job
  identifiers and perform only read-only reconciliation; escalate uncertainty
  or discrepancies to CockroachDB support.
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
  `CREATE INDEX` failed with CockroachDB SQLSTATE `57000` / Prisma `P3018`:
  `this schema change is disallowed because table "PasswordResetOtp" is locked
  and this operation cannot automatically unlock the table`. CockroachDB
  advised `ALTER TABLE PasswordResetOtp SET (schema_locked = false)`. On that
  disposable node, both `create_table_with_schema_locked` and
  `sql.defaults.create_table_with_schema_locked` were `on`/`true`, and
  `sql.schema.auto_unlock.enabled` was `true`. The table definition after the
  failure had `WITH (schema_locked = true)`.
- A controlled A/B probe changed only
  `sql.defaults.create_table_with_schema_locked` to `false` on the disposable
  local node (not in the project or Cloud), then reran the exact baseline and
  OTP migrations through Prisma against a fresh local database. Both
  migrations succeeded. Thus default table locking is a reproducible trigger
  for this failure in Prisma's v26.3.0 run; enabling automatic unlock alone
  did not prevent it. The original migration file was not changed.
- A fresh 35-migration local Prisma run with that same local-only default
  applied migrations 1-18, then failed at
  `20261024000000_separate_wholesale_catalog` with SQLSTATE `57000` because
  `"Product"` was locked and could not be automatically unlocked. The
  preceding `20261023123000_barcode_inventory_batches` explicitly sets
  `"Product"` to `schema_locked=true`; the wholesale migration changes FKs
  referring to Product without first unlocking it. This reproduced the
  second lock failure independently of the create-table default.
- In a separate fresh local database, Prisma applied migrations 1-18 with
  the local default disabled. A test-only `ALTER TABLE "Product" SET
  (schema_locked=false)` was then run between migration batches, without
  editing any migration SQL or history. Migrations 19-21 applied. The next
  batch failed at `20261030000000_normalized_product_images`: it adds columns
  to `"WholesaleItem"`, which the wholesale migration intentionally leaves
  `schema_locked=true`, without unlocking that table. CockroachDB again
  returned SQLSTATE `57000` and the locked-table error. Thus at least three
  independent lock conditions are established across a fresh full chain:
  OTP table creation default (migration 2), Product left locked before
  wholesale FK changes (migration 19), and WholesaleItem left locked before
  normalized-image DDL (migration 22). The exact full chain has not passed;
  further lock issues may be found after those are addressed. The test-only
  default/unlocks were made only on disposable local nodes. No migration
  history was manually edited or resolved, and no repository migration SQL
  was changed.
- Smallest source-level corrections to test with owner approval are:
  (a) use a migration-runner-specific
  `create_table_with_schema_locked=false` session/role default for the
  non-production run, verified with the actual Prisma connection role.
  CockroachDB documents per-role/per-database session defaults; note `root`
  is exempt from role defaults, so a root-based probe must instead explicitly
  set the connection/session option. (b) in a reviewed
  version of the wholesale migration, explicitly unlock Product before its
  FK changes and restore the intended lock afterward; and (c) unlock
  WholesaleItem before normalized-image DDL and restore the lock afterward.
  These historical migration changes are not authorized here. A cluster
  default change alone cannot clear tables explicitly locked by migrations.
- Production is currently v26.2.7 with the same reported lock defaults and
  auto-unlock `true`; `PasswordResetOtp` and `Product` are currently locked.
  The historical reason earlier production attempts succeeded despite these
  current settings is not established; the deployed migration bytes and
  settings at their execution times were not verified. Do not infer that the
  local v26.3.0 result is production behavior.
- CockroachDB Cloud's accessible cluster list shows one cluster and no
  separate verified staging database/cluster. The local rehearsal is
  disposable and non-representative, not a substitute for staging. Do not
  create Cloud infrastructure without the owner's cost approval.
- No owner-provided restore UUIDs, complete recovery reconciliation, staging
  database identifier, exact Render deployed SHA/instance count, or release
  owner date-sequence decision has been supplied in response to the blocker
  request. The production gate remains blocked.

## Local release candidate status (2026-10-24)

- The reviewed local application and migration changes are committed on
  `release/pos-billing-20261024` as implementation candidate
  `9f41143dc76cb69b44e10e36401079e5a8dd5312`. This commit is local only; it
  has not been pushed or deployed, and Render's deployed revision remains
  unverified. A documentation-only follow-up is the current local HEAD,
  `ca1023f53480b1f0c30ea4857c1d450f25646cdd`.
- The candidate includes the three billing migrations, backend routes/schema
  and tests, Flutter admin/POS screens and services, Windows runner sources,
  and release documentation. It does not include environment files,
  `android/app/google-services.json`, generated release binaries, or profiler
  output.
- Local-only generated/configuration files remain outside the commit. Do not
  treat the worktree as clean or copy those files into the release without
  separately reviewing their contents and handling secrets safely.
- Focused checks re-run on 2026-10-24: Prisma validation, TypeScript build,
  billing route/staff/exchange and staff-auth tests, Flutter analysis, and
  Flutter admin API/receipt/responsive-layout tests all passed. Read-only
  `prisma migrate status` again reported the same three pending migrations;
  the lifecycle metadata query found no unfinished attempts or
  database-only migration names. Windows and Android release artifacts were
  not rebuilt in this verification pass.

## Full-chain staging plan (not executed)

No separate staging database/cluster was verifiable in the accessible
CockroachDB Cloud account; its cluster list showed only `ram-prasad-store`.
Do not create a Cloud resource without explicit owner approval. If approved,
the requested disposable rehearsal environment should be:

- A separate CockroachDB Cloud Standard cluster in AWS ap-south-1 (Mumbai),
  single region, minimum 2 vCPU, usage-based storage, no optional CDC or
  replication add-ons, and a strict spend cap/auto-shutdown plan.
- Use synthetic records only. For migration/data-transform coverage, create a
  fresh database and isolated scratch copy of the migration directory. First
  expose only the baseline `20261007231846_init` folder, run
  `npx prisma migrate deploy --schema <scratch>\schema.prisma`, insert a
  reviewed synthetic legacy fixture, then add the remaining unchanged
  migration directories and run the same command again. Confirm the scratch
  SQL files match the candidate byte-for-byte before execution. This seeds
  representative pre-migration data while still applying every migration
  through Prisma. No production data or credentials may be used.
- Before and after, run `npx prisma validate --schema <scratch>\schema.prisma`
  and `npx prisma migrate status --schema <scratch>\schema.prisma` using only
  the staging endpoint supplied through a protected environment mechanism.
  After success, verify expected table/enum names, every Prisma-declared
  index/FK, and synthetic row assertions for every data rewrite. Run focused
  backend tests against the staged schema. If any migration fails, stop and
  retain sanitized output; do not use `migrate resolve`, edit `_prisma_migrations`,
  or rerun after a partial failure without owner-reviewed recovery.
- Use the same CockroachDB version as the intended target/release. The current
  production metadata says v26.2.7; local v26.3.0 is useful diagnostic
  evidence, not a substitute for testing on the intended target version.
- Record version plus `create_table_with_schema_locked`,
  `sql.defaults.create_table_with_schema_locked`, and
  `sql.schema.auto_unlock.enabled`. Test the appropriate role/session
  configuration without changing production. The source migration sequence
  contains explicit `schema_locked=true` settings; a default-only change will
  not unlock those tables.
- Verify the final Prisma schema, migration status, expected tables/enums,
  all declared foreign keys and indexes, and row-level assertions for
  synthetic wholesale conversion, inventory quantity conversion, user/streak
  backfill, coupon rewrites, and POS/exchange schema. Run backend build and
  relevant tests against the isolated target. On any failure, stop and retain
  sanitized diagnostics; do not resolve or edit migration history.

The CockroachDB public pricing page currently lists Standard at USD $0.092
per vCPU-hour for AWS us-east-1 (regional rates vary), and identifies usage
storage, backups, and egress as separate cost factors. A two-vCPU, two-hour
run would therefore be about USD $0.37 compute at that example rate, before
storage, backups, egress, region adjustment, and any time needed for a
representative test. This is an illustration, not a quote; request the
ap-south-1 estimate in the account's billing calculator and set a hard spend
limit before resource approval. Reference: [CockroachDB pricing](https://www.cockroachlabs.com/pricing/).

## External owner evidence still required

- The owner response supplied report templates/“Unavailable” fields, not
  restore source/destination UUIDs or completed reconciliation results.
- It supplied Render configuration observations (`npm start`, auto-deploy
  `On Commit`, `WEB_CONCURRENCY=1`, and a log line saying “No pending
  migrations to apply”) but not the deployed SHA, actual instance count, or
  enough log context to reconcile the line with the read-only status showing
  three pending migrations.
- No release-owner decision confirming the future-dated migration sequence
  was supplied.
- Consequently the source UUID, exact restore target mapping, reconciliation,
  staging target, live Render revision/topology, and date convention remain
  unresolved; production remains blocked.

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
   The repository's `prestart` automatically executes `prisma migrate deploy`
   on each `npm start`; the owner-reported `WEB_CONCURRENCY=1` does not
   establish one Render instance. A possible controlled approach is one
   authorized, securely configured one-off migration run, followed by a
   reviewed server-only start path that does not launch migrations from every
   service start. This requires a tested code/configuration change and owner
   approval; it is not currently configured or verified. Do not rely on both
   a one-off runner and automatic multi-instance `prestart` without an
   explicit plan.
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

## Local full-chain rehearsal addendum (2026-10-24)

This addendum records subsequent **local-only** work. It does not update or
replace any production evidence above.

- A fresh repository-state check confirms branch
  `release/pos-billing-20261024`, HEAD
  `ca1023f53480b1f0c30ea4857c1d450f25646cdd`, 36 migration directories,
  and no duplicate 14-digit timestamp prefixes. The 36th directory is
  `20261113000000_align_scalar_types`. The prefix is future-dated relative
  to this report; repository evidence does not establish the release owner's
  convention or approval. Do not rename or reorder it.
- Confirmed again before changes: branch
  `release/pos-billing-20261024`, HEAD
  `ca1023f53480b1f0c30ea4857c1d450f25646cdd`. Existing unrelated generated,
  configuration, Firebase, profiler, and release-archive worktree entries
  were preserved and not included in the implementation.
- Used a disposable CockroachDB CCL v26.3.0 node bound only to loopback
  (`127.0.0.1:45125`), cluster ID
  `0fc55e0b-e962-4d25-978a-57d648429810`, with temporary storage under
  `C:\Users\Siddhant\AppData\Local\Temp\ram-prasad-private-rehearsal-20261024`.
  The configured CockroachDB Cloud endpoint was not used. Lock-on defaults
  were active: `sql.defaults.create_table_with_schema_locked=true` and
  `sql.schema.auto_unlock.enabled=true`.
- Added explicit unlock/DDL/re-lock windows to the reproduced lock-sensitive
  migration SQL, including the three original failures and additional
  failures exposed by the chain. Updated the Prisma scalar native metadata
  and added `20261113000000_align_scalar_types` to keep existing application
  `Int` fields as INT4. This migration checks all four INT8-to-INT4 columns
  for range violations before altering application tables; an overflow is
  rejected before those changes. The corrections are local and uncommitted.
- On a clean disposable database `full_chain_test7`, Prisma applied all
  36/36 migrations in order. `prisma migrate status` reported up to date;
  schema validation and client generation passed. Synthetic checks confirmed
  wholesale conversion and cart/order references, coupon rewrites, and
  inventory totals (10,000 on-hand/received and 2,000 reserved). POS exchange
  constraints and indexes were present and validated. Guarded scalar values
  were preserved through conversion.
- The earlier read-only production snapshot covered the then-local 35
  migration directories and showed three billing migrations pending. This
  addendum adds a 36th directory locally; no production history check was
  performed for it, and no current production pending count should be inferred
  from the older snapshot.
- The first final `prisma migrate diff` output contained only
  `CREATE TYPE "crdb_internal_region" AS ENUM ('aws-ap-south-1')`. Inspection
  found that this enum was declared in the Prisma schema, was not referenced
  by any model, migration, or application code, and was not listed by
  `SHOW TYPES` on the local test database; `SHOW CREATE DATABASE` showed no
  locality clause and `SHOW REGIONS` returned no regions. Removed this
  unused schema declaration rather than applying generated SQL. After removal,
  Prisma validation/client generation passed and `prisma migrate diff` against
  `full_chain_test7` reported an empty migration.
- Drift inventory from the final fresh-database comparison and corresponding
  schema/migration corrections:

  | Item | Rehearsal SQL vs prior Prisma declaration | Disposition / risk |
  |---|---|---|
  | `Product.lowStockThreshold`, `CartItem.weightGrams`, `OrderItem.weightGrams`, `Coupon.perUserLimit` | SQL INT8 / Prisma `Int` (INT4 contract) | Migration 36 checks the signed INT4 range, then narrows these four columns to INT4. Synthetic lower/upper INT4 values were preserved; values one below/above the range were rejected before application-column changes. No production values were inspected, so existing-database ranges remain unknown. |
  | `Product.wholesalePrice`, `WholesaleItem.price` | SQL unbounded `DECIMAL` / prior Prisma default decimal metadata | Added `@db.Decimal` metadata; no numeric rewrite or rounding. |
  | `WholesaleItem.createdAt`, `WholesaleItem.updatedAt`, `StoredImage.createdAt`, `Order.scheduledDeliveryAt`, `Delivery.locationUpdatedAt`, `StoreSetting.createdAt`, `StoreSetting.updatedAt` | SQL `TIMESTAMPTZ` / prior Prisma default `TIMESTAMP(3)` metadata | Set Prisma `@db.Timestamptz(6)` to match migration SQL and retain timezone-aware UTC instants; no data rewrite. |
  | `User.userNumber` default | SQL sequence / prior `dbgenerated(nextval(...))` Prisma default | Changed Prisma metadata to `sequence()`; retained `BigInt` because display IDs are sequence-backed and potentially long-lived. No column narrowing. |
  | `PosExchange.shiftId` index | Index exists in migration SQL but was absent from Prisma model | Added `@@index([shiftId])`; no SQL index change. |
  | `crdb_internal_region` | Unreferenced Prisma enum absent from test DB and migration history | Removed unused declaration; final rehearsal diff was empty. |

  Application validation bounds `lowStockThreshold` to 100,000 and weight
  quantities to 100,000 or 1,000,000 depending on endpoint. Coupon
  `perUserLimit` now rejects values above 2,147,483,647, matching the Prisma
  `Int`/INT4 contract; exactly that maximum remains accepted. Negative values
  are not valid business inputs for those counters/quantities, although the
  SQL guard accepts any value within signed INT4 range for conversion safety.
  Existing Cloud data ranges and timezone behavior have not been rechecked.
- A separate loopback-only range test on CockroachDB CCL v26.3.0 verified
  both INT4 endpoints for all four columns, exact value preservation after
  conversion, and rejection at -2,147,483,649 and 2,147,483,648 for each
  column (eight rejection cases). After every rejection, SQL metadata still
  reported the application columns as INT8. This supplements the full-chain
  rehearsal but does not inspect Cloud data. The isolated test node was
  `127.0.0.1:45127`, cluster ID
  `0277cec3-072e-4418-99d7-3a8b3df204e2`; it was stopped and its temporary
  store removed after the test.
- Added `backend/tests/migration-schema-locks.test.ts` and wired it into the
  backend test script. It checks unlock/DDL/re-lock ordering and the scalar
  range-guard ordering; it is a source-level regression test, not a substitute
  for the CockroachDB integration rehearsal.
- The associated admin coupon validation now caps `perUserLimit` at the
  signed INT4 maximum; `backend/tests/admin-coupon-draft.test.ts` covers the
  maximum and rejects the next value before persistence. `npm test` passed
  after this change: all 46 configured backend test scripts plus the
  `pretest` transaction-retry script completed successfully. `npm run build`,
  `npx prisma validate`, and `npx prisma generate` also passed. Expected
  negative-path email-provider/image errors were logged by passing tests.
- Latest backend verification after the coupon `Int`-range validation change:
  `npm run build`, `npm test` (46 configured test scripts plus the
  transaction-retry pretest), Prisma validation/client generation, and the
  focused schema-lock test all passed. Flutter analysis and all 194 Flutter
  tests passed earlier in this task; no Flutter source or shared client
  contract changed afterward. Windows release rebuilt successfully at
  `build\windows\x64\runner\Release\RamPrasadStore.exe`, and Android release
  rebuilt successfully at `build\app\outputs\flutter-apk\app-release.apk`
  before the final backend-only validation change. Flutter emitted
  dependency-version deprecation warnings for Android Gradle 8.14.3, Android
  Gradle Plugin 8.11.1, and Kotlin 2.2.20.

This rehearsal establishes fresh-database behavior only on v26.3.0. It does
not establish compatibility with the reported Cloud v26.2.7 target, validate
the configured existing database, reconcile post-restore transactions, or
resolve restore UUIDs, Render topology, and migration-date ownership. Several
historical migration files with potentially successful existing-database
checksums were changed locally; applying those changed files to an existing
database may cause checksum validation failure. Do not use these local
migration changes against the configured Cloud database. Production remains
blocked pending version-compatible staging, checksum/release review, and the
external evidence listed above.

### Current release gates

| Gate | Status | Evidence required to close |
|---|---|---|
| CockroachDB v26.2.7 compatibility | BLOCKED | Run the complete chain and conversion boundaries against a verified isolated v26.2.7 target, or obtain authoritative compatibility evidence for every used DDL feature. |
| Current Cloud migration status | NOT CHECKED | Reconfirm the exact authorized Cloud target and read-only successful/failed/unapplied migration metadata against all 36 current directories. The previous report is stale because it covered 35 directories. |
| Historical migration checksum integrity | BLOCKED | Compare current migration checksums with the target's read-only `_prisma_migrations.checksum` values without selecting logs; review each changed historical file before considering an existing database. |
| Restore source/destination UUID verification | BLOCKED | Obtain the restore job's authoritative source and destination cluster UUIDs and confirm the destination database identity from the account owner or CockroachDB support. |
| Recovery-cutoff business-data reconciliation | BLOCKED | Obtain an authorized aggregate reconciliation of order/payment/refund/exchange/inventory records over the documented UTC recovery interval; exclude customer-identifying data. |
| Render deployed SHA and instance count | BLOCKED | Obtain current service detail showing the deployed commit SHA and actual instance count. |
| Guaranteed single migration executor | BLOCKED | Verify a deployment process that proves only one executor can run migrations and prevents overlapping startup `prestart` execution. |
| Release-owner approval of future-dated sequence | BLOCKED | Obtain written confirmation that `20261113000000_align_scalar_types` and the November-dated migration order are intentional. |
| Final schema-drift resolution | BLOCKED for Cloud; VERIFIED for the fresh v26.3.0 rehearsal | Confirm the intended target's read-only schema comparison; the local 36-migration database diff was empty after corrections. |

The current worktree is not a release commit. Branch and HEAD remain
`release/pos-billing-20261024` and
`ca1023f53480b1f0c30ea4857c1d450f25646cdd`, respectively. Migration SQL,
Prisma schema, backend validation/tests, and the audit remain modified or
untracked locally; no files were staged or committed. Existing local
configuration, Firebase, generated release archives, APK files, and profiler
data were preserved and remain outside the release changes.
