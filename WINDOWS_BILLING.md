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

Administrators sign in with their configured admin username or email. On
Windows, the admin navigation puts Dashboard, Orders, Delivery, and Billing
first for a solo operator handling online orders and in-store sales; catalog
and store setup screens remain available below them. The Windows POS dashboard
does not show the Billing staff management action. This is a Windows UI
simplification only: backend role checks and staff authorization are unchanged.
Other platforms retain the existing navigation and staff-management controls.
Billing staff sign in with their verified account email and see POS modules
only; administrator-only product and store-management tools remain unavailable.
The admin workspace uses its own sage-and-lime theme; customer-facing screens
retain their existing theme. Windows sessions store their token through the
Windows secure-storage plugin, which uses encrypted storage protected by
Windows Credential Manager.

Billing actions are listed individually in the Windows sidebar instead of
being hidden in a secondary billing menu. Cashier shift open/close and shift
history are not part of the operator workflow; POS transactions are assigned
to an internal register record so billing, cash movements, returns, and held
bills continue to work without shift prompts. Existing shift records remain
stored for historical transaction references.

To receive stock from an offline dealer invoice, open **Restock → Supplier
Bills**, enter the supplier and invoice details, add each received product with
its quantity and unit cost, attach a photo/scan of the bill, then choose
**Save bill & add stock**. On Android/iOS, use **Take bill photo** to capture
the invoice with the device camera, or choose an existing image. The bill and
photo are stored through the backend and are available to authorized admin
devices, including Windows. Supplier-bill images are limited to 5 MB. Product,
drinks, and wholesale catalogs support text search; POS product matches display
the catalog image when one is available.

USB/Bluetooth barcode scanners that act as a keyboard can enter codes in the
focused product field; scanner Enter submits the code. Camera barcode scanning,
Google Maps, and push notifications are not part of the Windows billing path.
On mobile, **Scan barcode** lets the operator switch between the device camera
and a USB/Bluetooth keyboard-wedge scanner. Windows operators use the focused
POS product field with an external scanner; proprietary scanner device
enumeration is not required for keyboard-wedge models.

Install the thermal printer in Windows first. The receipt print dialog uses the
installed Windows printer driver; choose **58 mm** or **80 mm** receipt paper in
**Receipt & Printer Settings** to set the PDF page width. POS exchanges are
recorded against the original bill and active shift; any refund difference must
be reviewed by an administrator before inventory is moved or a replacement is
issued. The POS records cash, digital, and pending payment methods; it does not
integrate a card/payment processor. **Pending Cash** lists customer balances
across all dates. Open a bill to review its products and collection history,
then record a partial or full amount received by cash or PhonePe/UPI. PhonePe/
UPI receipts must be verified manually; QR generation and automatic payment
verification are not enabled.

## Backend rollout boundary

The Render deployment logs supplied for commit `cfb29355c6fc55906e7d85edb0d7add50fb40603`
report that all migrations were successfully applied. Confirm the live Render
revision and use authenticated, read-only Billing requests to verify the
running release before enabling staff access or relying on exchange workflows.
The `prestart` script runs `prisma migrate deploy`, so a backend restart or
deployment can invoke migrations. Do not use an ordinary restart as a substitute
for a reviewed database recovery procedure.

Supplier bill history requires a backend release containing the
`/admin/inventory/purchase-bills` routes and supplier-bill migrations. A
`Cannot GET /api/v1/admin/inventory/purchase-bills` response means the running
API release does not contain that route (or the configured API base URL points
to a different service); deploy the backend before using supplier bills.

A running server that responds `Cannot GET /api/v1/admin/billing/overview` is
missing the Billing route or is not the expected service/revision; the app
reports this clearly and does not invent fallback billing data. An
unauthenticated request returning `401` is not proof that the Billing route
works for an Admin; verify it with an authorized Admin session without sharing
tokens or credentials.
