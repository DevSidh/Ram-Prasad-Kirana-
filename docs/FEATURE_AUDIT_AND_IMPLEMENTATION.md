# FastStore feature audit and implementation checklist

Date: 2026-11-03. Scope: existing Flutter Android/Windows app and Express/Prisma backend. No production database, real payments, notifications, or business records are used for verification.

## Preservation and evidence

The existing routes, record identifiers, schemas, navigation, local-only bill option, catalogue, customer data, banners, authentication and integrations are retained. Schema definitions alone do not establish a working feature. The classifications below follow the screen → API → transaction/persistence path; checks and remaining gaps are recorded separately.

| Area | Classification and traced evidence | Missing or incomplete behavior |
|---|---|---|
| Billing | Partial. `admin_billing_screen.dart` → `admin-billing.ts` → `PosSale`, collections, inventory transactions. Barcode/camera pairing, F2/F8, weight quantities, discount/VAT, holds, A4/thermal PDFs, balances, refunds and exchanges exist. | POS item discounts/coupons/quotations/rounding policy, full quantity-aware return credit notes, online order conversion and digital sharing need separate work. |
| Offline | Partial. `OfflinePosStore` caches products and catalogue uploads; Windows bills and customer CSV are local. Network fallback writes a local bill. | Existing local sequence can collide across PCs; writes and local stock need recovery protection; a timed-out server sale can also produce a local duplicate; no bill outbox/status/conflict UI. |
| Product/pricing | Partial. Product/category/brand/SKU/barcode/image, separate wholesale catalogue, weight units, variants in schema, admin CRUD. | Variant stock is not fully wired into POS. No general packaging conversions, minimum-price policy, validated bulk import/export, bundle engine, scheduled prices or label printer workflow. |
| Inventory | Partial. `InventoryService` reserves/commits/releases stock transactionally; batches, dates, expiry reports, adjustments and actor movements exist. | Dedicated damaged/returned quarantine stock, transfer dispatch/receipt, branch warehouse scope, serial tracking, stocktake reconciliation and configurable negative stock are absent. |
| Suppliers | Partial. Supplier bill screen → purchase-bill route → transaction creates received bill, batch and stock movement; duplicate supplier/invoice validation. | No purchase-order/partial-receipt lifecycle, supplier payment ledger/credit notes, terms/due dates or landed-cost allocation. Recording a received bill must remain distinct from a future purchase order. |
| Online | Partial. Flutter catalogue/cart/checkout → server-side `priceOrderItems` → transaction/order reservations; coupons, addresses, cancellation and history. | Pickup, safety buffers while counters disconnect, unified local-only/online customer ledger and externally verified wallet checkout remain incomplete. |
| Delivery | Partial. Zones/distance pricing, slots, assignments, transitions, tracking, driver profiles, cash collected and admin handover routes exist. | Explicit picking/packing records, OTP/signature/photo proof, failed/rescheduled delivery inspection flow and courier provider integration are absent. |
| Payments/credit | Partial. POS cash/digital/manual verification/pending balances/collections, refunds, cash movements and shifts exist; provider services fail when unconfigured. | Duplicate collection retry protection, general split payments, credit limits/due dates, provider fees and settlement reconciliation need work. Personal bank QR is static, not a provider-confirmed dynamic QR. |
| Customers | Partial. Profiles/addresses, histories, local bill-customer selection, buying streak/coupon gifts and notifications. | Memberships, gift cards, general store-credit redemption/reversal, per-customer pricing and a shared cross-channel balance ledger are absent. |
| Staff/counters | Partial. Auth middleware reloads active users/roles; billing staff scope enforced by backend; shifts and cash close/movements exist. | Fine-grained approvals, branch/counter configuration and comprehensive audit history need work. |
| Reports | Partial. Dashboard, POS day overview, sales/pending/refund date+search, CSV ledgers, expiry and delivery cash reports trace to recorded transactions. | Snapshot historical cost/profit, supplier dues, cash-flow/net-profit reporting and consistent branch/category/channel exports are incomplete. Do not label current-price calculations historical profit. |
| Security/backups | Partial/external. Token revocation, secure login storage, role checks and app updater verification exist. | Local records need validated backup/restore and durable writes. Provider cloud backup/PITR and printer hardware require external verification; no tax/legal compliance claim. |
| Grocery extension | Partial. Grams, weight entry and inventory batch expiry are present. | Scale device protocols and encoded-weight barcode configuration are absent. Restaurant/clothing/electronics modules are not added to grocery navigation. |

## Implementation checklist

- [x] Trace existing routes, screens, schema, financial workflows and relevant test harnesses.
- [x] Run baseline backend and relevant Flutter checks; distinguish failures from verified behavior.
- [x] Harden retried payment collections without double crediting a balance.
- [x] Add durable local bill persistence and UUID-based local invoice references across counters.
- [x] Add reconnect cash-bill synchronization with visible conflicts, preserving deliberate computer-only bills.
- [x] Keep local stock estimates separate from authoritative central availability; do not persist projected deductions back into raw catalogue snapshots.
- [x] Add local backup/isolated restore into existing billing navigation; filesystem tests verify exact restored bytes, hashes and traversal rejection.
- [x] Extend the existing receipt-history workflow to all recorded product-inventory movement types, searchable actors/references/reasons and CSV export of the current page.
- [x] Limit refund requests and approvals to actual received funds, including earlier and pending refund reservations. Disallow sub-cent zero-value refunds.
- [x] Run business-critical regression tests and update this handover with actual results.

## Changes implemented in this pass

1. [Local bill store](../lib/services/local_billing_store.dart): file flush + replacement, prior-commit recovery copy, process/file writer locks, replay detection, immutable UUID references, outbox metadata and conservative local stock deductions. The JSON record is committed before a derived PDF is generated, so a PDF failure cannot erase a sale.
2. [Billing integration](../lib/screens/admin/admin_billing_screen.dart): normal administrator cash checkout interrupted by network/timeout queues the same request reference; explicit computer-only checkout remains local. Reuse locally saved customer details without pretending a local customer ID is a server user. Percentage-discount VAT display now uses the same discounted taxable base as checkout. Pending-cash export works without server access by writing a separate local ledger, preserving the existing combined export.
3. [Reconnect service](../lib/services/local_billing_sync.dart) and [status panel](../lib/widgets/local_billing_status_panel.dart): pending count, account-scoped uploads, last successful server check, durable conflicts and explicit retry. Stock snapshots must refresh before a queued deduction is removed. A lost acknowledgement reuses the original request key after restart. An explicit computer-only bill is never uploaded.
4. [Backend billing](../backend/src/routes/admin-billing.ts): authenticated administrator-only import of cash bills; current product prices, totals and stock are validated. Changes cause a conflict, never a historical price rewrite. Imported receipts use separate closed import shifts without claiming a physical cash count or altering the current open till. Both first insert and unique-conflict replay paths check the offline snapshot. Replayed payment collections use a stable primary ID and reject mismatched amounts/methods/actors.
5. Refund requests reserve only actual received funds; approval rechecks this limit transactionally. Existing full-restock, exchange and cancellation guards remain. General credit notes and partially paid full-return settlements remain open work.
6. [Receipt history](../lib/screens/admin/admin_restock_screen.dart) reuses the existing route/model and defaults to restock receipts. Added movement-type/product/SKU/reference/staff/reason search, store-day filtering, visible references and current-page CSV export. This covers existing `InventoryTransaction` records, not a new wholesale/warehouse movement ledger.
7. [Category fetching](../lib/services/admin_api_service.dart) returns valid server data even when its cache write fails or is delayed. Phone normalization retains a canonical ten-digit `97`/`98` number while allowing the existing optional `+977` input format, restoring its regression test.

### Database and configuration

- No new database tables, destructive changes, data backfills, resets or production migrations in this pass. Existing Prisma models and references are reused.
- No dependency upgrades or new packages. Added backend reliability tests to the existing npm pretest command.
- Added a reusable Windows release build task to the existing VS Code task configuration. The task runner did not start a build in this session; the verified release was built with Flutter directly.
- New local JSON keys (`recordVersion`, `ownerId`, `syncState`, `uploadPayload`, acknowledgement mappings) are backward compatible. Historical files without these keys are read as local-only and are never silently queued.
- Backend deployment must precede use of the new queued-sale client. An older server rejects the extra fields visibly; the local original stays saved.

### Remaining work (not implemented or not verified)

The missing capabilities in the audit table remain open. In particular: purchase orders/partial supplier receipts/supplier payment ledger and credits; general POS variants/packaging conversions/coupons/quotations/credit notes; branch and warehouse transfers/quarantine/serials; gift cards/store credit/membership accounting; proof of delivery and failed-delivery inspection; historical-cost profit reporting; cloud or encrypted backups and live recovery; scale/cash-drawer/label-printer drivers and merchant payment integrations. No placeholder UI or simulated success has been added for these features.

Offline support in this pass is scoped to signed-in Windows administrators and cash/credit bills. Staff/mobile disconnected checkout, queued electronic payments, auto-importing local-only wholesale SKU snapshots, automatic price-conflict overrides and editing queued bill balances are not supported. Pending bills must synchronize before additional local collection. Old local-only files remain local. See [operating instructions](./LOCAL_BILLING_RELIABILITY.md).

## Final verification results

| Check | Actual result |
|---|---|
| `npm test --prefix backend` | Passed, including all existing scripts and the two new backend reliability/history scripts. The suite uses its existing isolated mocks. Expected invalid-upload/email-provider error fixtures do not represent real charges or messages. |
| `npm run build --prefix backend` | Passed (`tsc`). |
| Focused Flutter tests across 17 files | **78 passed, 0 failed** in the final run. Includes billing persistence/sync, catalogue concurrency/recovery, payment/invoice services, cart persistence, checkout, authentication, stock-history UI, orders, customer management, delivery board and expiry filters. |
| New local storage cases | Restart/replay, distinct references, conflicting writes, stale collection rejection, previous-commit recovery with a visible review flag, queued-balance protection, exact backup restoration, integrity/traversal rejection, catalogue deduction/recovery/concurrent merges. |
| New reconnect cases | Lost server acknowledgement followed by the same request ID, account and local-only upload restrictions, visible stock/price conflicts and explicit retry. HTTP responses and stock refresh are mocked; all files use temporary test directories. |
| New backend cases | One sale/stock commit on replay, immutable prices, closed imported cash shifts, role restrictions, payment key replay/mismatch, refund limits based on actual received funds, stock movement filters, actors, references and kg conversion. |
| Dart editor diagnostics | No errors in changed Dart files after formatting. |
| Windows release | Passed: `flutter build windows --release`, producing `RamPrasadBilling.exe`. Complete runtime ZIP packaged with one billing executable, DLLs and Flutter data. |
| Staging/live DB, provider settlement, actual printers/scanners/scales, Android installation, real network-loss test | **Not performed.** These require a staging/device/provider setup; unit and mocked transaction checks do not establish those integrations are verified. |

An initial backend phone-normalization failure was repaired. The first broad Flutter run found a new dropdown overflow and outdated test provider/preferences setup, plus a category-cache dependency failure; these were corrected and the final affected suite passed. No test disables permissions or changes production records to obtain a pass.

## Modified/new source files in this pass

- `backend/src/routes/admin-billing.ts`, `backend/src/routes/admin.ts`, `backend/src/routes/email-verification.ts`, `backend/package.json`.
- `lib/services/local_billing_store.dart`, `lib/services/local_billing_sync.dart`, `lib/services/offline_pos_store.dart`, `lib/services/admin_api_service.dart`, `lib/services/billing_excel_export_service.dart`.
- `lib/screens/admin/admin_billing_screen.dart`, `lib/screens/admin/admin_restock_screen.dart`, `lib/models/admin_models.dart`, `lib/widgets/local_billing_status_panel.dart`.
- `.vscode/tasks.json` (one appended release build task).
- `backend/tests/admin-billing-reliability.test.ts`, `backend/tests/admin-stock-history.test.ts`, `test/unit/local_billing_store_test.dart`, `test/unit/local_billing_sync_test.dart`, `test/widget/admin_stock_history_test.dart`; fixture corrections in `test/widget/admin_orders_test.dart` and `test/widget/admin_delivery_board_test.dart`.
- This checklist and [local billing operating guide](./LOCAL_BILLING_RELIABILITY.md).

## Deployment and verification limits

Never run a reset, destructive migration, production restore or real payment for this task. Existing local-only invoices/customer records remain local unless a bill is explicitly queued for server synchronization. Cached stock cannot guarantee global availability during an outage. Wallet/merchant QR, messaging, cloud backups, map APIs and hardware require real provider/device setup; credentials must not be fabricated. The rows above with missing capabilities are open work, not completed features.
