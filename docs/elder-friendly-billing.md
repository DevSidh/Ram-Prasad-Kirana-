# FastStore 3.3: English and Nepali billing

## For the cashier

- Use **English | नेपाली** at the top of the admin or billing screen. The sign-in page also has the switch. The choice is saved on this computer/device.
- Menus, forms, buttons, standard notifications and error messages use the selected language. Customer-entered names, contact details, product codes, and product descriptions remain unchanged when no translation is available.
- Text and controls are larger. Both light and dark appearances remain available. The bundled Noto Sans Devanagari font works without an internet font download.
- Products have larger names, prices and stock quantities. Search remains above the catalog. Smaller screens stack the product actions below the details.
- Large product cards are the default on Windows too. **Table view** remains available as an alternative.

## Add stock without a supplier invoice

1. Open **Products** and choose **Add stock** beside the product, or open **Restock** and choose the product there.
2. Enter the received quantity. Loose-weight products use kilograms in stock management; the barcode/POS still uses grams internally.
3. Enter the package manufacture/expiry information, or confirm that the product has no expiry. Batch/lot number and notes are optional.
4. Choose **Add to stock**. No supplier, purchase invoice, invoice number, or bill photo is needed for this workflow.

**Supplier bills (optional)** remains available for actual purchase invoices. Its existing accounting fields are preserved.

## Understand the stock summary

- **Total products** counts all unique products in the selected catalog, including paused entries.
- **Active products** counts the entries available for sale. Available-stock totals cover these active entries.
- Kilograms, pieces, and each pack size are separate totals. Quantities with unlike units are never added into a misleading single number.
- A `1 L` or `250 ml` item is a count of sealed packs in this database. The summary shows those pack counts separately and also shows their combined capacity as **Liters in sealed packs**. It does not imply the store sells loose liquid.
- Wholesale items are counted separately. A wholesale `25 kg` sack is a counted pack; it is not interpreted as 25 grams.
- The server already subtracts reserved online orders. Existing computer-only bill deductions are then applied once by the local stock projection.
- Successful sales, returns, exchanges, stock adjustments, and local bill changes signal a refresh. Visible totals also refresh every 30 seconds; catalog rows refresh periodically and when reopened. A failed refresh keeps the last values and displays a warning.

## Printed bills and PDF copies

- The existing bill/POS numbers, PAN `300854653`, saved amounts, customer data, payment records and automatic PDF storage locations are preserved.
- Nepali bills support A4, 58 mm and 80 mm paper. Flutter shapes the Nepali text into high-resolution lossless image rows before embedding it in the PDF; this preserves conjuncts and vowel placement and allows A4 pagination. Text in these shaped PDFs is not selectable/searchable.
- English bills retain their existing layout with larger A4 text. English bills containing Nepali customer/product text also use the shaped renderer so names remain readable.
- Reprinting uses the same saved bill. Language selection changes presentation; it does not recalculate or overwrite the financial record.

## Implementation and maintenance

- UI catalog: `assets/translations/billing_ne.json` (UTF-8, literal keys and numbered dynamic placeholders).
- Translation runtime: `lib/core/billing_strings.dart`; UI adapters: `lib/widgets/billing_localized_widgets.dart`.
- Language preference: existing `AppLanguageProvider` and `app_language` preference key.
- Stock grouping: `lib/models/stock_summary.dart`; refresh signal: `lib/services/inventory_changes.dart`.
- Shaped printing: `lib/services/readable_bill_pdf.dart`.
- Font license: `assets/fonts/OFL-NotoSansDevanagari.txt`.
- Run `rtk node tool/billing_localization.cjs` after adding UI copy to audit the billing/admin and sign-in catalog. Translate new keys and preserve placeholder numbers. Never translate API field names, payment references, CSV schema headers or saved business records.
- No new Dart packages, database schema changes, data-clearing operations or production-record migrations are required.

## Verification

Automated checks cover English/Nepali stock entry on narrow and desktop layouts in light and dark themes, persisted language choice, exact names/POS identifiers, stock units and all-page counts, refresh notifications, failed-refresh behavior, and printed Nepali A4/58/80 mm samples. Existing backend billing, stock allocation, returns, exchange and payment-idempotency tests are also run. Physical printer output still depends on the billing computer's selected driver and paper size.

Verified on 6 November 2026: Flutter analysis passed with no issues, all 304 Flutter tests passed, and the complete backend test command passed. A4/58/80 mm Nepali PDF samples and the Nepali checkout/stock-entry layouts were rendered and visually inspected. Checks also cover a wholesale sack's pack quantity and keeping the data/API locale unchanged while localizing visible dates. The Windows release executable reports `3.3.0+26`.
