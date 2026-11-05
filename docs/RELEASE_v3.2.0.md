# FastStore 3.2.0

- Automatically archives the PDF sent to printing under
  `C:/Ramprasad store/bills/pdf/`, using the POS reference as its filename.
  No Save As dialog is needed for this copy. Reprints reuse the filename;
  cancelling physical printing leaves the saved PDF intact.

- Replaced the payment QR with the owner's new, unmodified eSewa Circle image.
  The menu, confirmation dialog, saved bill and invoice identify eSewa correctly.
- Fixed backend rejection of cashier-confirmed payments, retaining exact-amount
  validation, cashier identity, stock checks and duplicate bill protection.
  The updated backend exposes manual QR capability in its health response.

- Offline Customers is in the main menu below Expiry.
- New local customer profiles store name, address, phone and optional email.
  Clicking a customer opens their details and complete available bill history.
- Pending cash CSV preserves manual rows, extra columns and row order. New bills
  append below existing rows; known invoice rows update without duplicates.
  Save and close the original CSV in Excel before updates; keep its headers.
- Returns & Exchanges supports name/phone/bill search and a date filter.
  Deploy the matching backend for search across server exchange history.

- Improved existing offline customer selection and phone number recovery.
- Basket sign-in recovery preserves items when an access token expires.
- Update downloads show verification progress, support cancellation and verify
  checksums without blocking the main UI.
- Shared invoice and thermal receipt headers include PAN **300854653**.
- Static Fonepay checkout waits for the cashier to verify the exact incoming
  amount and transaction reference before saving a paid sale.
- Duplicate save/initial-print guards and reprinting reuse the same bill.
- Includes the latest dashboard filters, expiry search, menu and stock fixes.

## Deployment and installation

Extract the whole Windows ZIP and run `RamPrasadBilling.exe`. Keep its DLLs and
`data` folder together. Preserve `C:/Ramprasad store/`, which contains business
records. Closing the previous app before replacing application files is required.

Deploy the matching backend for online manual Fonepay checkout. No new database
migration is required for the manual verification audit fields.

The store owner's supplied bank/Fonepay QR is now bundled by default; see
[Static Fonepay setup](STATIC_FONEPAY_SETUP.md). The confirmation button becomes
available after the QR loads and the cashier checks the verification box.
No merchant transaction reference is required. Ticking the checkbox is the
cashier's confirmation of receipt. An internal confirmation ID deduplicates
retries; it is not a bank transaction reference. Other methods remain available.

Source validation before packaging: 284 Flutter tests, Flutter analysis, backend
tests and TypeScript build passed. Physical printer and real bank transactions
were not tested. The ZIP includes file hashes and a SHA-256 sidecar.
