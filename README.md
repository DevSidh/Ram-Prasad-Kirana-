# Ram Prasad General Store

Ram Prasad General Store is a grocery shopping and delivery application for
Janakpur, Nepal. The repository contains a Flutter client for Android, iOS, and
web, plus a REST API built with Node.js, TypeScript, Express, Prisma, and
CockroachDB.

The Flutter app is the customer and staff interface. The backend is the
authoritative source for accounts, product availability, prices, coupons,
inventory, delivery rules, and orders. The app must be configured with the URL
of a running backend to load live data.

## Contents

- [Features](#features)
- [How the application works](#how-the-application-works)
- [Repository layout](#repository-layout)
- [Requirements](#requirements)
- [Run locally](#run-locally)
- [Backend configuration](#backend-configuration)
- [Maps and push notifications](#maps-and-push-notifications)
- [Database migrations](#database-migrations)
- [Build and publish Android](#build-and-publish-android)
- [Tests and quality checks](#tests-and-quality-checks)
- [Operational notes and current limitations](#operational-notes-and-current-limitations)
- [Troubleshooting](#troubleshooting)
- [Security](#security)

## Features

### Customer app

- Create accounts with a 10-digit phone number and verify the email during
  signup.
- Browse categories and live products; search, sort, and filter the catalog.
- View featured products, offers, product details, stock, and product images.
- Save products to a wishlist and keep account data synchronized after login.
- Add retail or wholesale items to the cart, review availability, and check out.
- Save delivery addresses, including a map pin and delivery instructions.
- View order history and status, cancel eligible orders, and follow delivery
  progress.
- Review in-app notifications. Opening the Notifications screen marks existing
  notifications as read; new notifications can show an unread indicator.
- Open Coupons from the Home gift button to see the current store offer and
  coupon codes included in account notifications.
- Save an order invoice as a PDF using the device's print/save interface.
- Choose the available light or dark appearance and supported app language.
- Browse vending drinks from the dedicated Vending destination. These are
  regular catalog items and use the existing cart and order flow.

### Store administration

The authenticated Admin area includes:

- Dashboard and order management.
- Delivery staff and customer management.
- Product and category editing, including vending products and wholesale items.
- Homepage showcase selection and product SKU tools.
- Coupon and promotion management.
- Store opening hours and order availability controls.
- Low-stock review and inventory restocking.
- Admin announcements/notifications for customers.

Product and order actions are sent to the backend; administrative changes are
not local-only UI state.

### Delivery staff

Delivery accounts enter a dedicated delivery panel. The backend limits delivery
endpoints to authenticated delivery staff. The panel supports assigned work and
delivery-status operations provided by the API.

## How the application works

```text
Flutter app
  ├─ Screens and reusable widgets
  ├─ Provider state (authentication, products, cart, orders, settings)
  └─ ApiService ── HTTPS/HTTP + bearer token ──┐
                                               v
                                    Express REST API
                                      ├─ Validation and auth
                                      ├─ Business rules/services
                                      └─ Prisma ORM
                                               |
                                               v
                                          CockroachDB
```

- `ApiService` sends API requests. Authenticated requests use the signed-in
  user's bearer token.
- Providers own client-side state and notify only the screens that depend on
  the changed state. Product catalog data can be cached on the device; the
  backend remains authoritative for checkout and inventory.
- The backend validates requests, enforces account roles, and performs
  transactional work such as order placement and inventory reservation.
- Prisma models and versioned migrations define the database schema. Apply
  required migrations before releasing backend code that depends on them. The
  backend's `npm start` runs `prisma migrate deploy` before starting the API.
  Keep the production `DATABASE_URL` available to both the build and start
  commands so pending migrations can be applied during deployment.
- Image URLs and image records are served through the API. Product thumbnails
  use cached network loading and size-aware decoding; transparent product
  uploads are normalized by backend image-processing code while original
  image data remains available.
- The main customer navigation preserves visited tabs and their state. Admin
  and delivery users are routed to role-specific shells after authentication.

## Repository layout

```text
.
├── android/                 Android app and Gradle configuration
├── ios/                     iOS Runner and platform configuration
├── web/                     Flutter web entry point and web configuration
├── assets/                  Images, icons, animations, and other app assets
├── lib/
│   ├── core/                App constants, themes, responsive and shared UI
│   ├── models/              Product, user, order, address, and other models
│   ├── navigation/          Customer navigation and role-based routing
│   ├── providers/           Client state and API-backed state management
│   ├── screens/             Customer, admin, authentication, and delivery UI
│   ├── services/            API, notifications, location, and invoice services
│   └── widgets/              Reusable product, image, motion, and UI widgets
├── test/
│   ├── unit/                Dart model, provider, and service tests
│   └── widget/              Flutter widget and interaction tests
├── backend/
│   ├── prisma/              CockroachDB schema, migrations, and seed code
│   ├── src/
│   │   ├── middleware/      Authentication and request middleware
│   │   ├── routes/          Account, admin, delivery, and auth route modules
│   │   ├── schemas/         Request validation schemas
│   │   └── services/        Business, image, email, inventory, and payment logic
│   └── tests/               Backend integration and service tests
└── scripts/                 Release/build helper scripts
```

## Requirements

- Flutter SDK and Dart compatible with the constraints in `pubspec.yaml`.
- Android Studio/Android SDK for Android builds; Xcode and CocoaPods for iOS.
- Node.js and npm for the backend.
- A CockroachDB database for backend development or deployment.
- Git for version control and release tags.

Check the Flutter version with `flutter --version` and the Node/npm versions
with `node --version` and `npm --version`.

## Run locally

### 1. Configure and start the backend

Create a private `backend/.env` file using `backend/.env.example` as a list of
the backend settings. At minimum, configure:

- `DATABASE_URL`: CockroachDB connection string.
- `AUTH_SECRET`: a private random secret of at least 32 characters.
- `PORT`: defaults to `4000`.
- `NODE_ENV`: use `development` for local development.

Set optional services only when using their features; see
[Backend configuration](#backend-configuration). Do not commit `.env` files.

From the repository root, open a terminal in `backend`, install dependencies,
generate the Prisma client, and start the API:

```powershell
Set-Location backend
npm install
npm run prisma:generate
npm run dev
```

The API listens on port `4000` by default. Check `http://localhost:4000/health`
to confirm the server and database are reachable.

### 2. Configure and start Flutter

In another terminal, from the repository root:

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:4000/api/v1
```

For Android emulators, use `10.0.2.2` to reach the host computer:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1
```

For a physical Android phone, use the development computer's reachable LAN
address and make sure the phone and computer are on the same network:

```powershell
flutter run -d <device-id> --dart-define=API_BASE_URL=http://192.168.1.20:4000/api/v1
```

Replace the example LAN address with the computer's actual address and allow
the backend port through the local firewall. Release builds require a deployed
HTTPS API URL; the app rejects localhost and other non-production release URLs.
Release builds default to the production Render API and also compile the local
development URL as `LOCAL_API_BASE_URL` (the Android emulator default is
`http://10.0.2.2:4000/api/v1`). Set `API_BASE_URL` to the production URL when
building a release; set `LOCAL_API_BASE_URL` to the computer's LAN URL when a
local development build needs to reach a physical phone.

### 3. Create an admin and starter categories

Set `ADMIN_NAME`, `ADMIN_USERNAME`, `ADMIN_EMAIL`, and `ADMIN_PASSWORD` in the
private backend environment. Then run:

```powershell
Push-Location backend
npm run admin:create
npm run categories:seed
Pop-Location
```

Admin creation does not promote or overwrite an existing account. The category
seed command adds missing starter categories without deleting existing ones.

## Backend configuration

The full variable list is in [backend/.env.example](./backend/.env.example).
Configure secrets in the host's secret manager for production, not in source
control.

| Setting | Purpose |
| --- | --- |
| `DATABASE_URL` | CockroachDB connection and TLS options. |
| `AUTH_SECRET` | JWT signing secret; use a unique value of at least 32 characters. |
| `JWT_EXPIRES_IN` | Token lifetime; defaults to `7d`. |
| `PORT` | HTTP listener port; defaults to `4000`. |
| `NODE_ENV` | Runtime environment; production applies stricter CORS behavior. |
| `CORS_ORIGINS` | Exact browser origins allowed in production, comma-separated. Needed for web, not native Android/iOS requests. |
| `ADMIN_NAME`, `ADMIN_USERNAME`, `ADMIN_EMAIL` | Admin account creation and configured admin login identity. |
| `GMAIL_OAUTH_CLIENT_ID`, `GMAIL_OAUTH_CLIENT_SECRET`, `GMAIL_REFRESH_TOKEN`, `GMAIL_USER`, `GMAIL_FROM` | Gmail API OAuth credentials and sender identity for HTTPS email delivery. |
| `GOOGLE_MAPS_ROUTES_API_KEY` | Backend-only Routes API key for road-distance delivery pricing and routes. |
| `GOOGLE_MAPS_PLACES_API_KEY` | Backend-only Places API key for authenticated location autocomplete and place details. |
| `DELIVERY_SERVICE_RADIUS_KM` | Delivery service radius; defaults to 10 km. |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Optional backend credential for Firebase push delivery. |

Do not copy development values into production. Use a TLS-enabled CockroachDB
connection, a unique authentication secret, the hosting provider's assigned
port, and exact browser origins. Keep API keys and service-account credentials
private.

### API areas

The API is versioned under `/api/v1`. Important areas include:

- Authentication and email verification: `/auth/register`, `/auth/login`, and
  `/auth/email-verification`.
- Catalog and images: `/categories`, `/products`, `/wholesale`, and image
  endpoints.
- Store status and offers: `/store/availability` and `/coupons/offer`.
- Customer account: `/account`, including saved cart, notifications, and
  profile-related operations.
- Orders: `/orders`, including authenticated order history, detail, and
  eligible cancellation.
- Role-protected administration: `/admin`.
- Role-protected delivery operations: `/delivery`.
- Public health check: `/health` and `/api/v1/health`.

Consult the route implementations in `backend/src` for request and response
schemas; this list is a navigation overview, not a substitute for API
specifications.

## Maps and push notifications

### Maps and delivery

Customers can enter delivery address details without a Maps key, but a saved
map pin is required to place an order. Android and iOS use native Google Maps
SDK configuration. Chrome uses a separate Maps JavaScript key. Restrict each
key to its platform and application/site.

- Android: add `googleMapsApiKey` to the ignored `android/local.properties`
  file (the build also accepts `MAPS_API_KEY`) and restrict the key to the app
  package and signing certificate.
- iOS: configure `GOOGLE_MAPS_API_KEY` in the Runner target's Xcode build
  settings, restricted to the app's bundle ID.
- Web: copy `web/maps-config.example.js` to `web/maps-config.js`, configure a
  restricted browser key, and limit it to the site's referrers.

Road routes and road-distance delivery pricing are calculated by the backend
using the Routes API key. Never place that key in the Flutter app. The default
service radius is 10 km and can be changed with `DELIVERY_SERVICE_RADIUS_KM`.
Location search uses the Places API through the backend, which keeps its key
out of the app. Enable Places API (New) and billing for that key and configure
`GOOGLE_MAPS_PLACES_API_KEY` in the backend host. Search is authenticated,
limited to Nepal, and biased toward the current map selection. Riders publish
their location while an order is out for delivery; customers see it on the
tracking map. A push alert is sent when the rider starts delivery. Configure
Firebase on both the app and backend for push delivery.

### Email

Registration verification and password resets use the Gmail API over HTTPS,
avoiding SMTP port restrictions. In Google Cloud, enable the Gmail API and
configure OAuth consent for the Gmail account that will send mail. Create an
OAuth client and authorize the `https://www.googleapis.com/auth/gmail.send`
scope for that account. Set `GMAIL_OAUTH_CLIENT_ID`,
`GMAIL_OAUTH_CLIENT_SECRET`, and `GMAIL_REFRESH_TOKEN` in the deployment host's
secret settings. Set `GMAIL_USER` to the authorized Gmail address and
`GMAIL_FROM` to that address, optionally with a display name. The authenticated
Google account must be permitted to send using the configured From address.

For a manual refresh-token setup, add
`https://developers.google.com/oauthplayground` as an authorized redirect URI
for the OAuth client, open the Google OAuth 2.0 Playground, select **Use your
own OAuth credentials**, and enter that client ID and secret. Authorize the
`https://www.googleapis.com/auth/gmail.send` scope as the sender account, then
exchange the authorization code and copy the refresh token into the deployment
secret settings. Never commit or share the refresh token or client secret.
OAuth consent apps left in Testing can issue refresh tokens that expire after
seven days; use the appropriate published/verified consent configuration for
ongoing production use. Gmail API calls and email codes are subject to Google's
quotas and policies. Verification/reset codes remain time-limited and
attempt-limited; logs include safe provider error codes, not credentials.

### Firebase push notifications

In-app notifications do not require Firebase. For push delivery, configure the
Firebase app for each target platform, including APNs for iOS, and pass the
client configuration at build/run time using Dart defines:

- Required client values: `FIREBASE_API_KEY`, `FIREBASE_APP_ID`,
  `FIREBASE_MESSAGING_SENDER_ID`, and `FIREBASE_PROJECT_ID`.
- Optional client values where applicable: `FIREBASE_AUTH_DOMAIN`,
  `FIREBASE_STORAGE_BUCKET`, `FIREBASE_IOS_BUNDLE_ID`, and
  `FIREBASE_WEB_VAPID_KEY`.
- Backend service-account JSON: `FIREBASE_SERVICE_ACCOUNT_JSON`, stored only
  in the backend secret manager.

Do not embed Firebase Admin credentials or private keys in the mobile client.

## Database migrations

The Prisma schema is `backend/prisma/schema.prisma`; migration SQL is in
`backend/prisma/migrations`. For a local development database, apply committed
migrations with:

```powershell
Push-Location backend
npm run prisma:migrate:deploy
Pop-Location
```

For production:

1. Confirm the target database and take/verify a backup.
2. Inspect migration status and review the pending SQL.
3. Apply migrations as a single release step, not concurrently from every API
   replica.
4. Deploy backend code that depends on the new schema only after the migration
   succeeds.
5. Verify health and the affected application flow.

The release helper checks migration status without changing the database by
default. Pass its `-ApplyMigrations` option only when you explicitly intend it
to deploy migrations against the configured database. Never run `prisma
migrate reset` or `prisma db push` against production. If a migration fails,
inspect both Prisma migration state and the actual database schema before
retrying; do not mark it rolled back or rerun SQL blindly.

The product-image normalization migration adds optional normalized-image
columns. Apply it before deploying backend code that reads or writes those
fields. Existing original image data is retained by the normalization design;
do not delete originals as a migration shortcut.

## Build and publish Android

### Local release build

Configure Android release signing first. Keep the upload keystore and
`android/key.properties` private and out of source control. The repository
script validates the HTTPS API URL, signing configuration, Prisma schema,
backend build/tests, Flutter analysis/tests, and migration status before
building.

From PowerShell:

```powershell
.\scripts\build-android-release.ps1 `
  -ApiBaseUrl "https://YOUR-DEPLOYED-API-HOST/api/v1" `
  -Artifact apk
```

For a Google Play App Bundle, use `-Artifact appbundle` (the default). Artifacts:

- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

For local builds, the version name and build number come from `version` in
`pubspec.yaml`. GitHub releases use the pushed tag for the version name and
retain the `+build` number from `pubspec.yaml` as the Android version code.
Increment both before a new distribution. Do not share an APK built with a
local or placeholder API URL.

### GitHub release

The Android release workflow is configured to build a signed APK when a
version tag is pushed. Set the repository variable `API_BASE_URL` to the
deployed HTTPS API base URL and configure these Actions secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `MAPS_API_KEY` (a restricted Android Maps key; required by the workflow)

Create a release tag on the intended commit and push it:

```powershell
git status
git tag -a v3.0.1 -m "Ram Prasad General Store v3.0.1"
git push origin v3.0.1
```

Use a unique tag that does not already exist. Pushing a tag triggers the
repository's configured release workflow; check the GitHub Actions run and
attach/verify the APK on the resulting GitHub Release. A GitHub tag/release
does not itself deploy the backend. Preserve the same signing identity for all
Android updates; losing the keystore can prevent future upgrades.

## Tests and quality checks

From the Flutter project root:

```powershell
flutter analyze
flutter test
```

From the backend folder:

```powershell
Push-Location backend
npm install
npm run prisma:generate
npm run build
npm test
Pop-Location
```

The Flutter tests cover providers, API services, widgets, navigation, and
important shopping flows. Backend tests cover API behavior and business rules.
Use a non-production test database and test credentials; do not run
development/test setup commands against production data.

For performance claims, measure a profile/release build on representative
physical devices with Flutter DevTools. Frame rate depends on device refresh
rate, OS policy, thermal state, and workload; do not claim a fixed 120 FPS
without measurements.

## Operational notes and current limitations

- Cash on Delivery is the currently supported checkout payment method.
  eSewa/Khalti/card payment verification is not implemented; do not mark an
  online payment successful based only on client input.
- Coupon codes shown in the Coupons screen are suggestions from the current
  store offer and customer notifications. Checkout validates eligibility on
  the backend. There is not currently a separate per-user coupon-wallet model.
- The invoice PDF uses NPR and Nepal Standard Time. On Android, **Download
  invoice PDF** opens the system print/save flow; the user chooses where to
  save it. A store PAN/VAT number is not shown unless configured in the
  application data.
- In-app notifications work independently of Firebase push. Push alerts require
  the client and backend Firebase setup described above.
- Product images uploaded from the admin workflow are validated and stored
  using the existing backend image-storage design. Image-processing failures
  should not replace the preserved source image.
- Product, store-hours, delivery, coupon, and inventory rules are enforced by
  the backend; the app should not be treated as the authority for those values.
- Store hours must be configured in the Admin area after the store-hours
  migration is applied. Closed/paused ordering is enforced by the API.
- Delivery service is limited by the configured radius. A map pin is required
  at checkout; typing an address alone is not sufficient.

## Troubleshooting

### The app says the backend is unavailable

1. Confirm the backend process is running and `/health` returns HTTP 200.
2. Confirm the Flutter `API_BASE_URL` points to the correct host and ends with
   `/api/v1`.
3. For Android emulator-to-host networking use `10.0.2.2`, not `localhost`.
4. For a physical phone, use the computer's LAN address and check Wi-Fi and
   firewall access.
5. For a release app, use the deployed HTTPS URL and rebuild; API URLs are
   compiled into the app.
6. Check backend logs and database connectivity if the health check fails.

### Map tiles do not load

Verify the platform-specific Maps key, enabled Maps APIs, billing, package/bundle
restrictions, and signing certificate restrictions. Manual address entry is
still available, but ordering requires a map pin.

### Email verification/reset codes do not arrive

Confirm `GMAIL_USER` matches the Google account that authorized the
`gmail.send` OAuth scope and that `GMAIL_FROM` is an allowed sender. Check the
backend logs for safe Gmail API error codes. A 401/403 indicates an OAuth,
authorization, or sender-permission problem; a network timeout indicates
HTTPS connectivity. Refresh tokens created while the OAuth consent screen is
in Testing may expire after seven days. Redeploy the backend after changing
code or environment variables.

### A migration fails

Stop before retrying. Confirm which database the backend is connected to,
inspect `prisma migrate status`, review the migration error, and compare the
database schema with the migration SQL. Take a backup before recovery. Some
CockroachDB deployments may have schema-lock policies; follow a verified,
environment-specific recovery procedure rather than applying generic SQL.

## Security

- Store production secrets in the backend hosting provider's secret manager.
- Never commit `.env`, keystores, signing passwords, Firebase Admin credentials,
  Gmail OAuth client secrets and refresh tokens, database URLs, or private API
  keys.
- Use HTTPS for deployed APIs and restrict Maps keys to the relevant platform.
- The backend hashes account passwords and protects account, admin, and
  delivery operations with authenticated role checks.
- Use least-privilege database and cloud credentials, and take verified
  backups before schema migrations.
- Do not put payment secrets or trusted payment decisions in the Flutter app.
