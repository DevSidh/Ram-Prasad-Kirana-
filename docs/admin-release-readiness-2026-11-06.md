# Windows admin panel release readiness — 6 November 2026

Scope: the actual Flutter Windows application (`lib/main.dart`), version **3.3.0+26**, connected to the existing production backend. This report does not certify a separate web deployment or an Android APK.

## Results

| Check | Observed result |
| --- | --- |
| Full Flutter regression suite | **463 tests passed** |
| Full backend regression suite, after clean install | **Passed**, exit code 0 |
| Flutter analysis | **No issues found** |
| Clean backend install, Prisma client generation, TypeScript build | **Passed** |
| Backend npm dependency audit | **0 vulnerabilities** after compatible lockfile remediation |
| Billing translation scan | **1,392 candidates, zero missing translations** |
| Windows release build | **Passed** |
| Live backend health | **HTTP 200**, status `ok` |
| Live admin rooms and overview without a bearer token | **HTTP 401** on both requests |
| Go-live cleanup, read-only database recheck | **0 online customers, 0 orders, 0 POS bills, 0 pending POS balances** |
| Preserved catalogue | **33 products, 14 wholesale items, 2 rooms** |

The live API requests were read-only and unauthenticated. Tests used fixture APIs and isolated storage; no live bill was created or stock changed. The existing room-cache hash also matched its pre-check backup after the test run.

## Fixes made during the final check

- Restored direct quantity entry for products without assigned room stock. Assigned products keep their source-room selection before checkout.
- Added a checkout guard against an empty/invalid quantity field silently charging the previous valid count.
- Updated regression expectations for the optional customer fields and the absence of a room dialog after Pay.
- Added regression coverage for room selection during item entry, cancellation, exact room quantities sent to checkout, anonymous pending balances, checkout idempotency, opening-stock splits and gram conversion.
- Added PDF checks for the actual 58 mm/80 mm page widths and content-dependent roll length.
- Initialized Flutter rendering services in receipt tests and supplied explicit in-memory room responses in the admin page/form audit. The audit catalogue disables local stock persistence.
- Corrected vulnerable backend transitive dependency resolutions without changing direct dependency version declarations. Repeated the clean install, build and full backend tests afterward.
- Retained the existing two-line input hints and removed a duplicate Nepali translation key. Refund navigation remains **Refunds / Refund Management**.

The fixture UI matrix covers desktop/mobile widths, English/Nepali, empty/failure/populated states and cancelled or invalid forms. The current Nepali desktop checkout screenshot was also inspected. This is not a claim that every live CRUD permutation was manually exercised.

## Distribution and remaining checks

- Use the complete checked Windows folder, including its `data` directory and DLLs. Copying the executable alone is insufficient.
- The package contains application files and guides, not customer records, bills, spreadsheets, credentials or the go-live backup.
- The executable has **no Authenticode signature**. No signing certificate was supplied; no replacement/self-signed certificate was invented.
- Physical 58 mm and 80 mm printer output, scanner/camera hardware, actual bank receipts and multi-computer stock races remain **unverified on the billing computer**. Run a controlled trial before taking real payments. The static QR flow requires cashier confirmation; it does not automatically detect money received.
- Authenticated end-to-end staging CRUD was not run because no separate staging database/account was supplied. Production was not used for destructive verification.
- No new GitHub release/tag, website publication or Render deployment was performed as part of this check. The dependency lockfile remediation must be included in the next backend deployment.

## Reproduce

```powershell
rtk powershell -NoProfile -File tool/run-admin-audit.ps1 -Check flutter
rtk powershell -NoProfile -File tool/run-admin-audit.ps1 -Check backend
rtk flutter analyze --no-pub
rtk node tool/billing_localization.cjs audit
```

Backend clean-install/build checks run from `backend`:

```powershell
rtk proxy npm ci --include=dev
rtk npm run prisma:generate
rtk npm run build
rtk proxy npm audit --omit=dev --audit-level=low
```

Do not run `npm start` or migration deployment merely to validate compilation: startup invokes migration recovery against the configured database.
