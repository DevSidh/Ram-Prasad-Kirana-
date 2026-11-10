# FastStore 3.3.4 (build 200030)

- Load unused admin pages only when first opened; retain billing sync and delivery alerts.
- Show cached dashboard data before scanning local invoices; stop blocking the dashboard after four seconds while live refresh continues.
- Dashboard product totals include retail, wholesale and drinks (drinks counted once).
- Manual invoice items with an optional name and required price/quantity, without inventory deductions.
- Automatic formatted Excel billing reports and a Windows product-price workbook with guarded two-way price synchronization.
- Keep automatic POS-named receipt PDFs and existing manual eSewa confirmation.

## Install

Windows: extract the entire ZIP into a new folder and run RamPrasadBilling.exe. Keep its DLLs and data folder together. Preserve C:\Ramprasad store and existing business records.

Android: install the APK over the existing app. Do not uninstall or clear app data.

## Validation and limits

Flutter analysis, backend TypeScript build, Windows release build and Android release build completed. Physical printing, live Excel-to-database edits and five-second startup on the billing computer/phone have not been measured in this release.

The backend must run the matching source changes for combined dashboard counts and online manual-item billing. Shared carton/packet stock is not included: its schema approval and remaining product clarifications are still pending. A visible cached screen does not guarantee fresh server data within five seconds.
