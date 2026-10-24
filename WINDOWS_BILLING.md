# Windows Store Admin & Billing

The Windows client reuses the Flutter app and its existing HTTPS API. It does
not connect directly to CockroachDB or contain database credentials.

## Build requirements

- Flutter stable with the Windows desktop target enabled.
- Visual Studio 2022 or newer with **Desktop development with C++**, the
  Windows SDK, and the C++ ATL component required by Windows secure storage.
- The Microsoft Visual C++ 2015-2022 Redistributable (x64) on PCs that do not
  already have the required runtime.

Run `flutter doctor -v` and resolve any Windows toolchain errors before building.

## Build and distribute

From the repository root in PowerShell:

```powershell
flutter pub get
flutter build windows --release
```

The distributable is the complete directory:

```text
build\windows\x64\runner\Release\
```

Zip and distribute that entire directory. It contains the executable, Flutter
runtime, plugin DLLs, and `data` assets; copying only the `.exe` is not enough.
Run `RamPrasadStore.exe` from the extracted directory.

The release client uses the configured HTTPS production API URL by default. To
use another HTTPS API endpoint for a release build, pass:

```powershell
flutter build windows --release --dart-define=API_BASE_URL=https://your-host.example/api/v1
```

Do not put API keys, database credentials, or staff/admin passwords in build
arguments or source files.

## Staff setup and shop peripherals

Administrators sign in with their configured admin username or email and get
the full admin panel, including top-level billing modules for POS, held bills,
invoice history, payments, cash register, customers, exchanges, reports,
cashier management, receipt settings, notifications, and profile/logout. The
admin workspace uses its own sage-and-lime theme; customer-facing screens retain
their existing theme. Billing staff sign in with their verified account email
and see POS modules only; administrator-only product, store-management, and
cashier-management tools remain unavailable. An administrator can open
**Billing → Cashier / Shift Management**, search for an existing active,
verified account, and grant or remove billing access after the
`BILLING_STAFF` backend role is approved, migrated, and deployed. Windows
sessions store their token through the Windows secure-storage plugin, which
uses encrypted storage protected by Windows Credential Manager.

USB/Bluetooth barcode scanners that act as a keyboard can enter codes in the
focused product field; scanner Enter submits the code. Camera barcode scanning,
Google Maps, and push notifications are not part of the Windows billing path.

Install the thermal printer in Windows first. The receipt print dialog uses the
installed Windows printer driver; choose **58 mm** or **80 mm** receipt paper in
**Receipt & Printer Settings** to set the PDF page width. POS exchanges are
recorded against the original bill and active shift; any refund difference must
be reviewed by an administrator before inventory is moved or a replacement is
issued. The POS records cash, digital, and pending payment methods; it does not
integrate a card/payment processor.

## Backend rollout boundary

This repository contains un-applied Prisma migrations for the `BILLING_STAFF`
role and POS exchange audit records. Windows staff access and the exchange
workflow require the backend release and migrations to be separately reviewed
and deployed. A running server that responds `Cannot GET
/api/v1/admin/billing/overview` is out of date; the app reports this clearly and
does not invent fallback billing data. This work does not apply migrations,
deploy the backend, or modify production data.
