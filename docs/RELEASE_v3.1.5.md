# FastStore 3.1.5 — Android and Windows

## Downloads

- Android: install `Ram-Prasad-General-Store-3.1.5.apk` as an update to the existing app.
- Windows: extract the complete `FastStore-Windows-3.1.5-20261104.zip` and open `RamPrasadBilling.exe`. Keep all DLLs and the data folder together. Preserve the existing `C:/Ramprasad store/` business records.

## Changes

- Improved local bill durability, retry safety, inventory display and billing responsiveness.
- Local-only customers can be selected from saved bill records, customer JSON and CSV exports. Their name and phone fill the invoice details without requiring an online account.
- Replaced the old UPI/static personal QR checkout with a Fonepay checkout interface, pending references and server verification/finalization guards.
- Added clear handling when an older backend lacks the Fonepay configuration endpoint.
- Added saved-payment recovery, duplicate-safe collections/finalization and a single automatic print claim. Failed printing can be retried from the existing invoice without collecting another payment.

## Fonepay availability

**Live Fonepay payments are not activated in this release.** The official account-issued API specification, merchant adapter, credentials and UAT approval are still required. Cash and pending-cash billing remain available. Test fixtures cannot settle real bills. No guessed API endpoints or signing scheme are used.

Deploy the matching backend and review/apply the two Fonepay migrations before using the new backend routes. Publishing this release does not itself certify merchant access or confirm that Render's deployment/migrations succeeded. See `docs/FONEPAY_SETUP.md` in the source/package.

## Validation

The payment implementation passed the existing Flutter and backend suites; the subsequent local-customer and missing-endpoint fixes were compile checked. Windows Release builds and test PDF layout rendering succeeded. Official Fonepay UAT and physical printer certification were not performed.

This update is optional. Keep existing accounts, sessions and local store records when updating; do not uninstall or delete the store data folder.
