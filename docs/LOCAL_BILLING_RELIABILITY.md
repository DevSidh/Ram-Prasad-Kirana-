# Local billing, synchronization and recovery

## Checkout modes

- **Normal cash checkout:** the existing server sale is attempted first. If the connection fails or times out, the Windows administrator checkout saves a durable cash-bill snapshot and queues that same request ID. Reconnection retries it automatically while billing is open, approximately every 45 seconds. The server validates current stock, prices, tax/discount totals and authentication again.
- **Save on this computer only:** the bill and offline-customer details remain on the computer. This selection never creates a sales upload. Historical local-only bills are also not retroactively uploaded.
- **Electronic payments:** the disconnected uploader accepts no electronic payment. The existing manually verified personal-bank-QR flow remains separate. The supplied QR is static and does not provide a payment-provider callback or amount-locked dynamic QR.

Financial JSON snapshots live under `C:/Ramprasad store/bills/`; derived PDFs use the same reference. CSV customer and pending-cash ledgers stay in their existing subfolders. New local invoice references contain the full request UUID and year, so separate counters do not reuse a device-local sequence. Online sequential references are preserved.

A malformed primary record can be read from its previous committed recovery copy. This is flagged on the status card and further balance edits are blocked until its payment history is reviewed; a recovery copy is not presented as proof that the latest collection was preserved. Concurrent local balance changes are rejected instead of overwriting a more recent collection. A PDF regeneration failure does not roll back an already saved payment.

If a server accepted a sale before its response was lost, the retry returns that existing sale instead of deducting stock or recording payment again. The local reference is retained in its original file; acknowledgement fields map it to the server invoice/receipt. Where the original online request had already received a sequential invoice number, both references remain available in the local snapshot. The archived JSON is not rewritten to pretend the local provisional reference was the original server invoice.

## Connection and conflicts

Expand the connection/local-records card in Windows billing to see:

- Connection result and last successful server check.
- Pending uploads and account-scoped conflicts.
- Computer-only bill count.
- Retry actions and local backup/restore actions.

Only the signed-in administrator that created a queued record uploads it. Changed prices, missing products, insufficient central stock, revoked permissions or an old backend produce an explicit conflict/error. The original local invoice is kept. Resolve the underlying condition (for example receive actual missing stock or deploy the compatible backend), review the record, then use **Retry reviewed conflicts**. Retrying never changes the historical amount or bypasses negative-stock checks. There is no force-upload or automatic financial conflict override.

The queued cash sale imports into its own closed import shift. Its expected cash is recorded, but an actual counted closing amount is not fabricated. An online acknowledgement is not evidence of a physical register count.

## Inventory and reporting boundaries

The local catalogue is an estimate based on cached server stock minus unacknowledged and deliberate local-only consumption. It is not central availability. A catalogue refresh merges raw server snapshots and does not apply the same local deduction twice. Queued deductions are removed only after the server result and refreshed affected product snapshots are acknowledged.

Online orders can consume central inventory while a counter is disconnected. A local sale may therefore conflict at reconnect. No perfectly synchronized stock is promised during an outage. Old local files without explicit local-stock metadata are preserved but are not retroactively deducted; reconcile their inventory manually.

Computer-only consumption does not automatically alter central inventory. It continues to affect the local estimate. There is not yet a dedicated local-only/central stock-reconciliation workflow. Separate wholesale-only catalogue IDs that have no corresponding POS product record cannot be imported as regular product sales and remain visible conflicts if queued.

When the server is unavailable, dashboard/report pages identify local figures as local records only. Offline pending-cash export writes `pending_cash_local.csv` so it cannot overwrite an existing server-inclusive `pending_cash.csv` with incomplete data. Online returns, exchanges, supplier receipts, provider payments, catalogue uploads and administration still require connectivity.

## Payment retries and refunds

The client persists a payment-attempt UUID before sending a balance collection. A lost response retains that UUID. Retrying the same amount, method and note reuses it; changing an unconfirmed payment requires reviewing the ledger first. The server replays the same payment rather than increasing the collected amount twice, including after the bill has become fully paid. Another actor, bill or payload cannot reuse that payment ID.

Refund amounts cannot exceed actual money received after earlier/pending refunds. Returning all physical items still requires the existing full-refund/restock workflow. General credit notes and fully returning a partially paid credit sale require additional ledger work and are not implemented here.

## Local backup and isolated restore

- A changed local-records set is backed up automatically during billing's periodic checks to `C:/Ramprasad store/backups/local-YYYY-MM-DD.fsbak`. This daily file is refreshed after later detected bill/ledger changes. Backup failure is shown on the status card.
- **Export local backup** makes a manual snapshot and allows saving another copy using the existing file picker.
- **Verify / restore a copy** validates the archive format, relative paths and SHA-256 checksums, then writes a new `C:/Ramprasad store/restored-<timestamp>/` directory. It never merges into or overwrites the active bills folder. Review the restored files before any supervised live recovery.
- The backup covers billing-folder JSON/PDF/customer/pending-cash files. It does not export server databases, credentials, externally stored catalogue queues, or provider settings. It is an unencrypted local archive, not a protected cloud backup. Keep access restricted at the operating-system/storage level. Cloud backup, encryption, retention policy and live recovery remain unverified setup/work.
- Backup/restore limits: 128 MB source data and at most 10,000 files; the decoder also bounds restored archive size. Large histories require a separate archival strategy. No existing backup files are deleted automatically.

## Deployment

1. Deploy the backend billing and history route changes first using the existing deployment pipeline. No Prisma migration or data reset is needed for this pass.
2. Close the old desktop app, extract the complete new Windows package into a new folder, and run its billing executable. Retain DLLs and the data folder together.
3. Connect once to load the current catalogue. A computer without cached products cannot invent an offline catalogue.
4. Use only test accounts/data on a staging system for a real network-loss/device/printer trial. The supplied automated checks use isolated files and mock backend transactions, not the production database or real charges.
