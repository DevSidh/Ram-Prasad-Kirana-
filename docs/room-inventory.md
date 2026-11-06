# Room inventory

## Using it

1. Open **Inventory** from the main admin menu.
2. Choose **Manage rooms → Add room**. Enter a name and a unique number (for example, `Main store`, `01`). Room numbers are trimmed and normalized to uppercase.
3. Existing stock starts in **Unassigned**. Find a product and choose **Place / move stock** to move an existing quantity into a room. This does not add or remove aggregate stock. Use the existing Restock workflow to receive additional stock.
4. Filter by a room or search by product name, SKU or barcode. The summary groups quantities by their units; loose retail goods are counted in grams and wholesale packs remain whole packs. Product cards show the physical quantity in each room.
5. Create a bill normally. Before payment/save, **Where should we take the products from?** lists each product, the required quantity, and the available rooms. Confirm the suggested quantities or split them across rooms. Cancelling does not commit a sale or move stock.
6. The existing sale transaction checks the selections and deducts the aggregate, unexpired batch stock, and chosen room stock together. If another till has sold those units, the transaction fails without a partial stock deduction. Cashier payment/printing protections remain in place.

Room availability is bounded by the product's overall available stock; reservations are not assigned to individual rooms. The final checkout still applies the existing expiry and reservation rules. Room placement does not identify the expiry batch of individual units.

## Stock lifecycle

- Retail products, drinks, and separate wholesale items have independent room counts using their existing catalog keys.
- New receipts and stock increases add to **Unassigned**. Returns/cancellations that restore stock also return it to **Unassigned**, allowing the operator to inspect and place the returned goods.
- POS sales deduct from the selected rooms. Existing clients and online orders without a room selection consume Unassigned first, then named rooms in a stable ID order. This is a bookkeeping allocation: delivery staff should check Inventory before physically picking an online order.
- Reducing aggregate stock through the existing adjustment workflow uses the same automatic allocation rule.
- Transfers are administrator-only and idempotent. Billing staff can inspect room stock and select rooms for a sale, but cannot create rooms or transfer stock.
- A room containing stock cannot be deactivated. Rooms can be renamed; their stable IDs and movement records remain intact. There is no destructive room-delete action.
- Inactive products remain visible in Inventory so their physical stock can be moved out of a room.

## Computer-only and offline billing

Windows keeps a recoverable room snapshot at `C:/Ramprasad store/bills/inventory/rooms.json` (or beneath an injected billing-store root). The snapshot includes a safe product catalog, room names, and stock counts, not authentication credentials. Computer-only bills record their room selections in their existing JSON invoice records.

New room-tracked **computer-only** invoices remain local. The existing sync worker shares **only product quantities, source room IDs, and a unique stock reference** with the server. It does not send bill prices, customer details, payment details or an invoice document. This updates shared aggregate/batch/room stock without creating a server invoice. Older computer-only invoices without room selections are not automatically backfilled into the server.

The worker retries pending stock updates every 45 seconds and on the existing sync action. A unique stock receipt prevents a retry from deducting stock twice. Local stock deductions stop being projected only after server acknowledgement and fresh catalog/room snapshots. An uncertain refresh preserves the reference for a safe retry. The local status panel shows stock updates awaiting sync and reports conflicts.

Bills already queued for normal server synchronization carry their room selection through the existing bill upload, instead of submitting a second stock-only request.

While offline, counts are estimates. Two disconnected tills can sell the same last units; the server cannot reserve stock for an offline device. Such conflicts retain the local financial record and require review through the existing sync conflict controls. Conflicting estimates are kept non-negative and flagged before further billing of that product. No source room is fabricated to resolve a conflict.

Offline-created catalog items must synchronize successfully before their stock-only requests can resolve to a server product. SKU matching is used only for local placeholder IDs; an unresolved catalog conflict stops stock synchronization. Creating/renaming rooms and transferring shared stock require a connection. Android/web use the live room API and do not write to the Windows billing directory.

## Backend setup and rollout

The backend must be deployed **before** distributing this Flutter client. Existing servers do not have the new `/admin/billing/rooms` endpoints.

The [Prisma schema](../backend/prisma/schema.prisma) and [migration](../backend/prisma/migrations/20261201000000_inventory_rooms/migration.sql) add five tables: rooms, room stock, room movements, checkout picks, and idempotent local stock receipts. The migration creates new tables; it does not alter existing changefeed-locked product or sale tables and does not modify historical invoices.

1. Back up the database using your existing operational process.
2. Validate the migration against a separate staging CockroachDB database.
3. Generate the Prisma client and deploy the backend normally. Its existing `prestart` already runs `prisma migrate deploy`.
4. Confirm the authenticated room API works, create a staging room, place stock, and complete a staging bill.
5. Build/distribute the updated Flutter application. No additional packages or environment variables are required.

Do not run a development migration/reset against production. This implementation did not execute the migration against the production database or publish a release.

## Validation

Isolated regression coverage includes exact/split picks, duplicate room selections, reservation bounds, base units, cancelled selection, room transfers and replay protection, aggregate rollback on a room failure, automatic online-order allocation, admin-only room writes, stock-only local receipts, retained local customer data, acknowledgement timing, and interrupted synchronization retries. Inventory search/filter/create/transfer and the picker are exercised at mobile and desktop widths in English and Nepali.

The existing backend suite and Flutter suite were also run. A real staging database migration, concurrent multi-computer operation, physical picking, and printer hardware still require staging/device validation; fixture tests do not prove those external systems.

Final local checks on 2026-11-06:

- Flutter full suite: **459 passed**.
- Flutter analysis: **no issues**.
- Backend full suite, including room inventory regression checks: **passed**.
- TypeScript backend build: **passed**.
- Windows Flutter release build: **passed**, producing `build/windows/x64/runner/Release/RamPrasadBilling.exe` and its companion files.
- Translation inventory: **1,392 candidates, zero missing translations**.

The Windows executable requires its complete Release directory (DLLs and data), not the executable by itself. No GitHub release, website deployment, production migration or new ZIP was published as part of this change.

The separate wholesale catalog follows the application's existing checkout capabilities. Room tracking does not convert wholesale-only records into retail Product rows or change existing sale-item foreign keys.

## Opening stock locations

New retail products, drink-menu products and wholesale items now include **Starting stock by room**. For positive starting stock, select an active room by its name/number and enter the quantity. Use **Add another room** to split the same product across rooms. The sum must equal starting stock; loose retail weights use kilograms (up to three decimals), while sealed/wholesale goods use whole stock units. **Add room** creates a room without leaving the product form. Zero-stock products need no allocation until stock is received.

The backend writes opening stock and all room allocations in one transaction. Duplicate rooms, inactive/missing rooms and mismatched totals are rejected. Existing clients that do not send allocations retain Unassigned opening stock. No additional migration is needed. Deploy the updated backend before using the updated product forms.

Room names and numbers remain editable at **Inventory → Manage rooms → Edit room**. The stable room ID preserves stock placements and bill references when a room is renamed or renumbered. For existing products, use **Inventory → Place / move stock** to distribute stock across rooms without creating duplicate products or increasing total stock.

Queued offline products retain opening-room allocations. Cached room stock includes those placements while awaiting upload, and the same allocations are sent when the product synchronizes. Creating or renumbering rooms requires a server connection; cached active rooms can be selected while offline, with their current status revalidated during upload.

## Recovering the Render P3018 / CockroachDB 57000 room migration failure

CockroachDB can lock a newly created table before the next index or foreign-key DDL runs. If `20261201000000_inventory_rooms` failed with this schema-lock error, the deploy command now runs a targeted recovery through [deploy-migrations.mjs](../backend/scripts/deploy-migrations.mjs).

Recovery checks the recorded failure and the existing column types, nullability, defaults, primary keys, validated quantity/FK constraints, and index keys. It completes only missing tables/indexes with idempotent DDL, keeps the parent room table unlocked while adding the room-stock foreign key, and restores schema locks even after an error. Only after verification and relocking does it call Prisma `migrate resolve --applied`. It never drops room tables, deletes room/stock records, edits Prisma's history directly, or changes the original migration file/checksum.

Push the backend changes and use **Render → Manual Deploy → Deploy latest commit**. The existing start command remains `npm start`; its prestart reaches the updated `prisma:migrate:deploy` script. Successful recovery logs `Recovered 20261201000000_inventory_rooms; room data preserved and schema locks restored.` and then continues normal migrations/startup. If the room migration first hits this lock during deployment, the wrapper performs the same recovery and retries deploy once. Unrelated migration failures are not automatically marked applied.

For an operator running from the backend directory, the dedicated repair command is `node scripts/recover-failed-room-migration.mjs`; the normal deploy command is `npm run prisma:migrate:deploy`. These commands change the configured database schema and should only be run against the intended database. Do not reset the production database or mark this migration applied without completing its schema first.

The recovery was checked against isolated fixtures for all ten partial SQL states, repeat runs, incompatible definitions, interruption/retry and relock failures. Syntax checks and the backend build passed. No live database repair was executed from this workspace.

A read-only schema inspection also confirmed the reported partial state: `InventoryRoom` has the expected columns/defaults and primary key, but its unique room-number index is missing. The complete backend test suite passed with the recovery regression checks included.

References: [CockroachDB schema locking](https://www.cockroachlabs.com/docs/v26.2/changefeed-best-practices#lock-the-schema-on-changefeed-watched-tables), [Prisma migration hotfix reconciliation](https://www.prisma.io/docs/orm/prisma-migrate/workflows/patching-and-hotfixing).
