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
