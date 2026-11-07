# FastStore 3.3.1: checkout, receipts and editable prices

## Install on the billing computer

1. Close FastStore. Keep the previous application folder as a rollback copy.
2. Extract the entire new ZIP into a new folder. Open `RamPrasadBilling.exe` there; keep every DLL and the `data` folder together.
3. Keep `C:\Ramprasad store` and the existing application support/preferences folders. Do not replace them with files from another computer.
4. In **Receipt & printer settings**, choose **58 mm**, then **Choose printer → Deli ES301**. The first print also offers a remembered printer selection.
5. Check the printer driver's 58 mm roll setting. Use actual size, with no fit-to-A4 scaling. The receipt uses a conservative 48 mm text area.
6. Check a real receipt on the physical printer: alignment, feed length, USB disconnection, cancellation, and an explicit reprint of the same saved bill.

## Changes

- Bill saving no longer waits for receipt generation, customer Excel exports or loyalty requests. “Bill saved” and printing status are separate.
- Removed the extra room-availability network fetch at Pay. Online checkout still validates stock/rooms inside the server transaction. Local checkout validates stock/rooms under the financial writer lock. Item source-room quantities must be complete before payment.
- Local financial JSON includes durable archive, customer export, pending-cash export, loyalty and price-update tasks in the same commit. A worker retries every 30 seconds and when the billing panel opens. Its pending/error state and retry button appear in printer settings.
- Server bills get a local post-processing journal after their response arrives. A crash before the response/journal can still be recovered through server bill history and explicit reprint; the client cannot atomically commit a local file with a remote database transaction.
- Receipt PDFs are fingerprinted by immutable receipt fields, language, layout revision, PAN and paper width. Concurrent calls share work; persistent SHA-256 checked bytes survive restarts and are reused for printing and archive copies. Missing/corrupt files are regenerated. Memory is bounded; disk receipt copies are retained for reprints.
- Windows direct printing uses the selected printer when supported, and falls back to the platform print UI otherwise. Concurrent clicks share one submission. No automatic print replay after restart: a spooler response does not prove physical output. Reprint is an explicit action using the original bill.
- Automatic PDFs remain named from the POS reference under `C:\Ramprasad store\bills\pdf`. Local bills also receive their existing invoice-named PDF copy. Archiving is independent of printer submission and retries after failure.
- Compact English receipts match the supplied monospace layout, with dashed rules, aligned prices, wrapped descriptions and PAN **300854653**. Quantity/rate, VAT, paid balance and payment state are preserved. The exact screenshot font could not be identified; bundled **Noto Sans Mono** is the closest chosen fixed-pitch font, under SIL OFL. Nepali uses bundled Noto Sans Devanagari and Flutter shaping. No receipt fonts download at checkout.
- Replaced the eSewa image with the supplied WhatsApp image, byte for byte. Cashier confirmation rules remain unchanged; no automatic bank verification is simulated.
- Administrators can edit unit price or product line total with the pencil beside the item. Quantity × new unit price recalculates all lines for that product, discount/VAT and payable balance. The catalogue change commits with an online bill, or stays locally visible and queued with a computer-only bill. Cancelling an unsaved bill does not change the catalogue. Rates use two decimal places; a line total that cannot be represented at that precision uses the displayed calculated total.
- Price changes are administrator-only. Billing staff retain existing billing permissions. Expected-price checks prevent stale offline changes from overwriting another administrator's price. Conflicts stay pending for review.

## Backend deployment required for catalogue changes

Deploy the backend source accompanying this version before using online price-edited checkout or synchronizing local price changes. The old backend rejects the new request fields/endpoint.

- Generate Prisma Client with the existing `prisma:generate` script.
- Apply the migration through the existing `prisma:migrate:deploy` deployment script: `20261202000000_pos_catalogue_price_changes` creates an idempotency/audit table. It does not change existing product tables or reset data.
- Build and restart using the existing deployment pipeline. No new secrets/environment variables are required.
- Endpoint `POST /admin/billing/catalogue-price-changes` is administrator-only and accepts a stable request UUID plus expected/new prices. Bill checkout applies price changes, stock consumption and the financial record in one transaction. Replays use the same request identity.
- These changes were tested with isolated transaction fixtures, not the production database. Production deployment and live migration were not performed as part of packaging.

## Measurements

Representative Flutter test fixtures on this development computer; milliseconds, not physical printer timings:

| Stage | Measured example |
| --- | ---: |
| Local stock validation | 82.8 ms |
| Local financial save including validation/durable metadata | 435.5 ms |
| English receipt, fresh generation plus persistent cache | 90.3 ms |
| Reuse the same prepared PDF | 0.73 ms |
| Shaped-text comparison renderer | 326.4 ms |
| Two archive copies | 11.2 ms |
| Mock printer submission | 0.3–3.0 ms |

These are test-mode samples under concurrent test load, not a release/hardware benchmark. The comparison renderer is the retained shaped-text path, not a separately measured pre-change executable. Results vary with storage, antivirus, backend latency, driver and printer. No claim of instant physical printing is made.

Runtime stage samples are written without customer/payment identifiers to `bills\diagnostics\checkout-timing.jsonl` (one rotated previous log). They distinguish stock validation, saving, PDF generation, archiving and submission. Online request timing includes server validation/network time.

## Validation and limits

- Flutter analysis passed with no issues; **470 Flutter tests passed**; complete isolated backend suite passed (including the new price/checkout tests); backend TypeScript build and Windows release build passed.
- Added regression coverage for concurrent PDF calls, persistent cache reuse/corruption recovery, remembered printer submission, duplicate clicks, printer failure/reprint, offline checkout before PDF/network work, restart retries, collected-balance export retries, editable prices, exact totals/stock, price conflicts, administrator permissions, rollback and idempotent replay.
- Rendered and inspected English 58 mm, long-description/large-amount 58/80 mm, and Nepali 58 mm PDFs. Checked English text bounds and footer extraction. Examples in `Receipt samples` are fixtures only, not business bills.
- Existing payment, Android invoice and room-inventory tests pass. Android device printing and a fresh Android release build were not performed for this Windows delivery.
- No production test sales, stock changes or migration deployment. Existing Windows package and business records are preserved.
- Physical Deli ES301 USB output, driver support for custom roll lengths, QR scanning/payment receipt, and real bank confirmation still require the billing computer. The Windows executable remains unsigned; no security settings are changed.

## Main modified source

- [Billing screen](../lib/screens/admin/admin_billing_screen.dart), [API](../lib/services/admin_api_service.dart), [sale snapshots](../lib/models/pos_models.dart).
- [Receipt cache](../lib/services/pos_receipt_service.dart), [compact layout](../lib/services/compact_receipt_pdf.dart), [Nepali rendering](../lib/services/readable_bill_pdf.dart), [printer](../lib/services/receipt_print_service.dart), [timings](../lib/services/pos_timing.dart).
- [Durable worker](../lib/services/billing_post_commit.dart), [financial store](../lib/services/local_billing_store.dart), [catalogue projection](../lib/services/offline_pos_store.dart), [exports](../lib/services/billing_excel_export_service.dart), [PDF archive](../lib/services/bill_pdf_archive_service.dart).
- [Backend checkout](../backend/src/routes/admin-billing.ts), [price changes](../backend/src/services/pos-price-changes.ts), [schema](../backend/prisma/schema.prisma), [migration](../backend/prisma/migrations/20261202000000_pos_catalogue_price_changes/migration.sql).
- Bundled font/license, QR image, Nepali translations, version **3.3.1+27**, and regression tests. No new Flutter dependencies.
