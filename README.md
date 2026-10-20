# Ram Prasad General Store — Grocery Shopping & Delivery App

A mobile application built using **Flutter + Dart** with Material 3 and a **Node.js + TypeScript + CockroachDB + Prisma ORM** backend.

---

## 📱 Mobile Architecture (`/lib`, `/android`, `/ios`)

The mobile application is built natively for **Android 8+** and **iOS 14+** using Flutter:

```
grocery_app/
│
├── lib/
│   ├── core/           # Constants, Material 3 Light/Dark Theme, Colors
│   ├── config/         # App environment configurations
│   ├── models/         # User, Product, Category, CartItem, Order, Address
│   ├── services/       # ApiService (HTTP client with JWT headers)
│   ├── repositories/   # Data repositories
│   ├── providers/      # AuthProvider, ProductProvider, CartProvider, OrderProvider
│   ├── screens/        # Splash, Onboarding, Auth, Home, Category, PDP, Cart, Checkout, Tracking, Orders, Profile
│   ├── widgets/        # ProductCard, CustomButton, EmptyState
│   ├── navigation/     # MainBottomNav and the existing customer destinations
│   └── main.dart       # App entry point with MultiProvider
│
├── android/            # Native Gradle, AndroidManifest.xml, Kotlin MainActivity
├── ios/                # Native Runner, Info.plist, AppDelegate.swift, Podfile
├── test/               # Flutter Unit & Widget tests
└── backend/            # Node.js + TypeScript + CockroachDB + Prisma REST API
```

---

## 🚀 How to Run the Flutter Mobile App

### Prerequisites
- Flutter SDK `>=3.16.0`
- Android Studio / Xcode

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Run on Connected Device / Emulator
```bash
flutter run
```

The API is a separate backend process; it does not run inside the Android app. Start it on the development computer with `npm.cmd --prefix backend run dev` on Windows (or `cd backend && npm run dev` elsewhere). It listens on `0.0.0.0` so devices on the local network can reach it. The web app and iOS simulator use `localhost`; the Android emulator uses `10.0.2.2` to reach the development computer. A physical phone must use the computer's reachable LAN IP or the deployed HTTPS API URL, for example `flutter run -d <device-id> --dart-define=API_BASE_URL=http://192.168.1.20:4000/api/v1`. Keep the phone and computer on the same network and allow the backend port through the computer firewall. Login errors now identify the API URL if the server cannot be reached.

Saving a delivery address does not require a Maps API key; customers can enter address details manually. Android and iOS use the native Google Maps SDK; Chrome uses the Maps JavaScript API and needs its own key. For Android, add `googleMapsApiKey=YOUR_RESTRICTED_KEY` to `android/local.properties` (the build also accepts `MAPS_API_KEY`) and restrict it to package `com.freshharvest.grocery_app` plus the signing certificate SHA-1. For iOS, set `GOOGLE_MAPS_API_KEY` in the Runner target's Xcode build settings and restrict it to the iOS bundle ID. For Chrome, copy `web/maps-config.example.js` to `web/maps-config.js`, set a separate key with Maps JavaScript API enabled, and restrict it to your site's HTTP referrers. The web picker is enabled by default; `--dart-define=GOOGLE_MAPS_CONFIGURED=false` can disable it explicitly. Never commit keys. Without a valid key enabled for the platform, the map tiles cannot load; manual address entry remains available.

Orders require a saved map pin within a 10 km straight-line radius of the store. Set `DELIVERY_SERVICE_RADIUS_KM` in the backend environment to override the 10 km default. Customer categories whose name or slug contains “rice,” “vegetable,” or “dairy” are hidden in full, including mixed categories such as “Fruits & Vegetables” and “Dairy & Eggs.”

New customer accounts must verify their email with the six-digit code sent through
the configured SMTP server before signing in. Existing accounts remain verified.
Phone numbers are not collected at registration; changes to a saved phone number
remain unavailable until SMS verification is configured for the deployment.
Configure the SMTP environment variables listed in `backend/.env.example` in the
backend host's secret manager. Email delivery requires a working mail provider;
the local `.env` file is not deployed with the app.

### 3. Build a Production Android APK or App Bundle

Release builds must embed the deployed backend's HTTPS API URL. Do not build
with bare `flutter build apk --release` or `flutter build appbundle --release`.
On Windows, use the release script after configuring Android signing:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-android-release.ps1 -ApiBaseUrl "https://YOUR-DEPLOYED-API-HOST/api/v1" -Artifact apk
```

Use `-Artifact appbundle` for a Google Play Store AAB. Flutter uses the
`version` in `pubspec.yaml` as the Android version name and build number. Name
shared APKs with the store name and version, for example
`Ram-Prasad-General-Store-v2.0.8.apk`. The APK is written to
`build/app/outputs/flutter-apk/app-release.apk`; the AAB is written to
`build/app/outputs/bundle/release/app-release.aab`.

### Publish a Signed Android APK on GitHub

Android installs an `.apk`; `.exe` files are for Windows. The GitHub Actions workflow at `.github/workflows/android-release.yml` builds a signed APK and attaches it to a GitHub Release when you push a version tag such as `v1.0.1`.

Before tagging a release:

1. Deploy the backend changes first. Confirm the public pages
   `https://YOUR-API-HOST/privacy-policy` and
   `https://YOUR-API-HOST/account-deletion` return HTTP 200, and that the
   deployed API includes `POST /api/v1/account/delete-account` and
   `/api/v1/auth/email-verification/{request,confirm}`. Apply the
   `20261026000000_email_verification` migration after a verified backup and
   configure SMTP on the backend before publishing. Do not publish the app
   until these endpoints and email delivery are live.
2. Add the repository variable `API_BASE_URL` with the deployed production HTTPS API URL.
3. Add these repository Actions secrets:
   - `ANDROID_KEYSTORE_BASE64`: your private Android release keystore encoded as one Base64 string.
   - `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD`: the credentials for that keystore.
   - `MAPS_API_KEY`: a restricted Android Maps key; restrict it to this app's package and release certificate SHA-1.
4. If you do not already have a release keystore, create one outside the repository in PowerShell. Keep the passwords private and back up the keystore:

```powershell
keytool -genkeypair -v -keystore "$HOME\upload-keystore.jks" -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
keytool -list -v -keystore "$HOME\upload-keystore.jks" -alias upload
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$HOME\upload-keystore.jks")) | Set-Clipboard
```

Use the displayed SHA-1 certificate fingerprint when restricting the Android Maps key. Paste the clipboard value into the `ANDROID_KEYSTORE_BASE64` secret, and enter the keystore and alias passwords into their respective secrets.
5. Push your code to the GitHub repository, then create and push a new version tag:

```bash
git tag v1.0.1
git push origin v1.0.1
```

The workflow creates a GitHub Release with `app-release.apk` attached. Keep the keystore and its passwords backed up securely; losing them prevents publishing future updates under the same Android signing identity. Never commit the keystore, encoded keystore, or signing credentials.

---

## 🖥️ Backend REST API & Database Setup (`/backend`)

The backend is built with **Node.js, TypeScript, Express, CockroachDB, and Prisma ORM**.

### 1. Setup Environment
Configure `backend/.env` with the CockroachDB connection string and a private `AUTH_SECRET` of at least 32 characters. For Flutter web deployments, also set `CORS_ORIGINS` to the exact HTTPS web-app origin(s), separated by commas. Production mode blocks browser origins that are not listed:
```bash
cd backend
npm install
```

Do not run `prisma migrate dev`, `prisma db push`, or a database reset as part of routine startup. Product sale prices use `price`, with `originalPrice` shown as the crossed-out former price. Admins can create percentage or fixed-amount coupons with a minimum retail subtotal, optional discount cap, redemption limit, and expiry; checkout revalidates each code in the order transaction. Coupon discounts exclude wholesale-priced items, including in mixed baskets. Product units are stored with the catalog record.

The post-login offer popup reads eligible, active percentage coupons with a
discount cap and fixed-amount coupons from `GET /api/v1/coupons/offer`. The
backend returns the saved coupon type, value, minimum order, and expiry; the app
does not invent offer values or calculate the discount locally.

Store administrators can configure recurring opening hours and immediately pause or resume online ordering from **Admin → Store hours**. Hours use Nepal Standard Time (`Asia/Kathmandu`); closed days and a paused store are enforced by the backend as well as shown in the customer app. The migration seeds an always-open schedule to preserve existing checkout behavior; configure the actual weekly hours in the admin panel after applying the `20261018000000_store_hours` Prisma migration and before relying on automatic closing.

Run `npm run prisma:migrate:deploy` from `backend` as part of each backend release before starting code that uses new Prisma fields or tables. This includes the store-hours migration, which is required for the public availability check and its customer banner to work.

For email one-time-code password resets, also configure `SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURE`, `SMTP_USER`, `SMTP_PASS`, and `SMTP_FROM` in the backend's local environment. Use an app password for the sending mailbox; do not commit it. The reset code expires after 10 minutes and is limited to five verification attempts.

New product images uploaded from the admin product editor or showcase are validated JPEG, PNG, or WebP files (up to 5 MB) and stored in the database so every device receives the same image. Profile photos are also stored in the database. New generic admin image uploads use database-backed image records rather than Render's ephemeral filesystem. Older image URLs and bundled fallback thumbnails remain supported when their referenced files still exist. Files previously written to Render's ephemeral filesystem cannot be restored after they disappear; re-upload those images through the admin panel.

Delivery addresses, cart contents, saved items, profile photos, order history, cancellations, and in-app notifications are tied to the signed-in account. Cart and saved-item changes sync to the backend so they are restored after signing out and back in, including on another device. Customers can crop a square profile photo in the app before uploading it as a PNG; uploaded images must be JPEG, PNG, or WebP and are limited to 5 MB. Checkout does not store payment credentials; only Cash on Delivery is currently available. The store confirms delivery timing after checkout; a specific delivery window is not booked.

Road-distance delivery pricing uses the Google Maps Routes API from the backend, never from the mobile app. Enable Routes API and billing in Google Cloud, then add `GOOGLE_MAPS_ROUTES_API_KEY` as a private backend/Render environment secret and restrict the key to Routes API. Never put this key in Flutter build definitions or source control. Customers must select a map pin for the delivery address. The tariff is Rs 20 for the first started kilometre and Rs 10 for each additional started kilometre (for example, 1 km = Rs 20, just over 1 km = Rs 30, and just over 2 km = Rs 40); the old free-delivery-by-subtotal rule no longer applies.

Customer and delivery-account email addresses are stored lowercase, and phone numbers are stored as digits only. Registration, profile updates, and delivery-account creation check existing values even when older phone records use punctuation; existing duplicate accounts are not automatically deleted or merged.

Push notifications require Firebase app settings at build time and platform setup (including Android/iOS app registration and APNs for iOS). Pass the client values with `--dart-define` at build/run time: `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_PROJECT_ID`, plus the applicable optional values `FIREBASE_AUTH_DOMAIN`, `FIREBASE_STORAGE_BUCKET`, `FIREBASE_IOS_BUNDLE_ID`, and `FIREBASE_WEB_VAPID_KEY`. Configure the server's Firebase service-account JSON only in the backend's private environment as `FIREBASE_SERVICE_ACCOUNT_JSON`; do not place service-account secrets in the Flutter app or commit them. In-app order and delivery-assignment notifications work without Firebase; configured delivery push alerts contain only order/delivery identifiers, while customer contact, location, and payment details remain available through the authenticated delivery API.

The profile-photo and device-token migrations have been deployed to the configured database after backup confirmation. The pending `20261016000000_product_shared_image_and_units` migration adds database-backed product images and the product unit label. Apply pending migrations as a release step after a verified database backup and before deploying the backend version that uses these fields. For another environment, follow the same backup-first process; CockroachDB clusters with schema-locked tables may need those locks temporarily disabled during migration, then restored. Do not run `prisma migrate dev` or reset the database in production.

### 2. Create the Store Admin Account

Set `ADMIN_NAME`, `ADMIN_USERNAME`, `ADMIN_EMAIL`, and `ADMIN_PASSWORD` in the local environment, then run:
```bash
npm run admin:create
```

The command hashes the password and creates an `ADMIN` user in the configured database. The API must also have matching `ADMIN_USERNAME` and `ADMIN_EMAIL` values at runtime; admin sign-in accepts either the configured username or email. Use a unique email; the command will fail rather than promote or overwrite an existing account. Keep the password in local environment configuration only, use a strong unique password, and never commit it.

### 3. Add the General-Store Starter Categories

```bash
npm run categories:seed
```

This safely creates the Dal & Pulses, Cooking Oil, Biscuits, Personal Care, Stationery, Household, and other general-store categories if they are missing. It does not delete or overwrite categories.

### 4. Run Backend Checks
```bash
npm test
```

### 5. Start Backend Server
```bash
npm run dev
```
Server runs on port `4000`.

### Container Deployment

The backend provides a Docker runtime image and a separate `migrate` build target. Configure `DATABASE_URL`, `AUTH_SECRET` (at least 32 random characters), `NODE_ENV=production`, and `PORT` in the hosting provider's secret/environment settings; never copy `.env` into the image. For admin sign-in, configure `ADMIN_USERNAME` and `ADMIN_EMAIL` for the admin account.

After the hosted database backup is confirmed and before deploying a new backend version, build and run the one-off migration image:

```powershell
docker build --target migrate -t ram-prasad-store-migrate:release ./backend
docker run --rm --env-file backend/.env ram-prasad-store-migrate:release
```

Only continue if Prisma reports that migrations completed or that there are no pending migrations. Then build and deploy the runtime image:

#### Recovering the failed delivery migration

The delivery migrations are retry-safe after partial application. For a CockroachDB cluster where any affected table has `schema_locked = true`, run each applicable statement separately in the SQL console before retrying; do not combine these statements in a transaction:

```sql
ALTER TABLE "User" SET (schema_locked = false);
ALTER TABLE "Delivery" SET (schema_locked = false);
ALTER TABLE "DeliveryStatusHistory" SET (schema_locked = false);
```

After confirming a database backup, mark the previously failed migration as rolled back so Prisma can retry its now-idempotent SQL, then deploy all pending migrations:

```powershell
Push-Location backend
npx prisma migrate resolve --rolled-back 20261012000000_delivery_staff_panel
npx prisma migrate deploy
Pop-Location
```

If `migrate resolve` reports that the migration is not in a failed state, do not force the resolution; inspect `npx prisma migrate status` and only deploy if the migration is pending. After all schema changes complete, restore the CockroachDB schema locks in separate statements:

```sql
ALTER TABLE "User" SET (schema_locked = true);
ALTER TABLE "Delivery" SET (schema_locked = true);
ALTER TABLE "DeliveryStatusHistory" SET (schema_locked = true);
```

#### Recovering a failed user token-version migration

If `20261014000000_user_token_version` fails because the `User` table is schema-locked, first check the migration status and confirm that the `tokenVersion` column was not added:

```sql
SELECT column_name
FROM information_schema.columns
WHERE table_name = 'User' AND column_name = 'tokenVersion';
```

If the column is absent and the migration is listed as failed, unlock only the affected table in the CockroachDB SQL console:

```sql
ALTER TABLE "User" SET (schema_locked = false);
```

Then mark that failed migration as rolled back and retry deployment:

```powershell
Push-Location backend
.\node_modules\.bin\prisma.cmd migrate resolve --rolled-back 20261014000000_user_token_version
.\node_modules\.bin\prisma.cmd migrate deploy
Pop-Location
```

After Prisma confirms that migrations completed or are up to date, restore the lock:

```sql
ALTER TABLE "User" SET (schema_locked = true);
```

If the column already exists, do not mark the migration rolled back or retry blindly; inspect the migration status and database state first. Keep a verified backup and do not run these recovery steps against a different database than the intended deployment target.

```powershell
docker build -t ram-prasad-store-api:release ./backend
```

Configure the host to run the image on the assigned `PORT` and use `/health` as its readiness check. The health endpoint verifies CockroachDB connectivity and returns HTTP 503 if the database is unavailable. Run migrations as a single release step, not concurrently in every app replica.

For production, set `NODE_ENV=production`, a CockroachDB TLS connection string, a unique `AUTH_SECRET` (at least 32 characters), and the assigned `PORT` in the hosting provider's secret/configuration manager. Set `CORS_ORIGINS` to the exact HTTPS origin(s) only when the Flutter web client needs browser access; native Android/iOS requests do not send browser origins. Configure SMTP credentials for password-reset and registration email verification. Keep `backend/.env` out of deployment artifacts and do not copy the local development values from `.env.example` into production.

### Android Release

Use a supported JDK for the Android Gradle Plugin (JDK 17 is recommended for this project), install Android SDK command-line tools, and accept the Android SDK licenses. Before the first Play Store upload, create and safely back up an upload keystore with `keytool`; never commit the keystore or its passwords. Place a `key.properties` file at `android/key.properties` with `storeFile`, `storePassword`, `keyAlias`, and `keyPassword`. The release Gradle configuration intentionally does not use Android's debug key.

After the backend is publicly deployed with HTTPS, build with its API URL:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-android-release.ps1 -ApiBaseUrl "https://YOUR-API-HOST/api/v1"
```

The script validates and generates Prisma Client, builds/tests the backend and Flutter app, verifies migration status without changing the database, and builds a signed Android App Bundle. The API URL must be the real deployed HTTPS URL; the release app rejects localhost and non-HTTPS URLs. Build an APK instead with `-Artifact apk`. Apply schema changes as a separate release step after a verified backup; pass `-ApplyMigrations` only when you explicitly intend this script to run `prisma migrate deploy` against the configured database.

### Admin Panel Status

The admin shell provides database-backed dashboard metrics, product/category management, homepage showcase controls, catalog-wide SKU tools, promotion management, store hours, restocking, and order management. Set each product's low-stock threshold in **Products**; **Restock** lists active items at or below that level, including out-of-stock items, and records received quantities in inventory history with the logged-in admin staff member and timestamp. Existing products retain the previous threshold of 10 after the `20261019000000_low_stock_threshold` migration. Apply `20261020000000_restock_receipt_staff` to link new receipt records to staff accounts; older receipts remain visible without staff attribution. Use **Vending drinks** to add or edit regular catalog products and select **Show in vending machine**; these drinks use the same product stock, cart, and checkout flow as other items. Apply the `20261025000000_product_vending_drink` migration before deploying this option. The customer Vending tab shows a responsive Drinks menu populated from live vending products, with category filters, stock and sold-out states, and a best-seller feature card. Selecting an available drink reveals quantity controls and adds the selected amount to the regular cart and checkout flow. The app starts loading its product catalog during the animated startup screen. Select active products in **Showcase** to include them in the customer's automatically rotating product carousel; each slide uses the product's saved name, category, image, and price. Edit an item's SKU in **SKUs** using the suggested `category-productname-quantity` pattern (for example, `pulses-masoor-dal-1kg`). Admins can assign delivery staff, update order status, and set or clear a future delivery date and time for open orders. Apply `20261022000000_order_delivery_schedule` before deploying that delivery-time feature. Customer tracking shows the road route from the store to the saved delivery address when the backend Routes API is configured; it does not claim to show live courier GPS. Customers can review and mark in-app order notifications as read; Firebase push delivery is enabled only after the app and server credentials are configured as described above. Online eSewa/Khalti payment verification is not implemented, so new online-payment orders are rejected until a gateway is integrated.

---

## 🔒 Security Notes

- Passwords are stored as bcrypt hashes. Admin APIs require a valid bearer token and verify the user's active status and `ADMIN` role against CockroachDB.
- Password resets increment the user's token version, immediately revoking previously issued access tokens. Apply the `20261014000000_user_token_version` migration before deploying this backend version.
- Inventory reservation uses a conditional atomic database update; admin stock edits are transactional and recorded in inventory history.
- Apply the `20261019000000_low_stock_threshold` and `20261020000000_restock_receipt_staff` migrations before deploying the restock queue and staff-linked receipt history.
- Keep database and authentication secrets on the backend and out of Flutter source.
- Checkout currently supports Cash on Delivery only. The API rejects eSewa, Khalti, and card orders until a real server-side payment integration is deployed; do not treat a client-provided payment result as successful.
