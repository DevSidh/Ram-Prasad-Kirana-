# Windows Admin Panel Audit Report

Date: 2026-11-08

## Verified

- Static analysis completed with **no issues**.
- Admin page audit and invoice responsiveness suites completed successfully: **142 tests passed**.
- Covered dashboard, billing, products, wholesale, drinks, categories, coupons, customers, delivery, orders, expiry, room inventory, search, room allocation, offline checkout, and duplicate checkout protection.
- Existing release build remains available at `build/windows/x64/runner/Release/RamPrasadBilling.exe`.

## Issues found during the complete suite

| Area | Severity | Finding | Status |
|---|---|---|---|
| Windows local-store tests | Medium | Temporary test folders remained locked during cleanup when SQLite/local-store tests ran together. | Fixed in test cleanup with explicit database close and retrying deletion; serial local-store tests now pass. |
| Catalogue recovery test | Medium | A corrupted primary catalogue could be masked by a newer SQLite row. | Fixed by treating the JSON recovery snapshot as authoritative when the primary file is malformed; recovery test passes. |
| Performance refresh test | Low | Refresh retry behavior needed an explicit in-flight scheduling path and corrected retry-count assertion. | Fixed; the refresh correctness suite now passes. |

## Security/configuration review

- Turso credentials are read server-side from `TURSO_DATABASE_URL` and `TURSO_AUTH_TOKEN`; they were not found in Flutter source or shipped assets.
- No destructive schema change or production data operation was performed.
- Package upgrades are available, but major upgrades were not applied because they require compatibility testing.

## Not verified in this environment

- Physical Deli ES301 printer output at 58/80 mm.
- Network-offline and slow-network behavior on the billing computer.
- Profile-mode DevTools timings with 5,000+ products.
- Live Turso latency and production login against the deployed service.

## Required next fixes

No automated test failures remain. Physical printer, live Turso latency, offline network, and 5,000-product profile checks still require the billing computer.

## Recheck — 2026-11-10

### Newly found and corrected

- **Startup / high:** `AuthProvider.loadSavedSession` awaited a profile API request for legacy sessions missing a profile ID. Session restoration now returns after reading local credentials; the profile refresh runs separately, checks the original token, and ignores results after disposal. A delayed-response regression verifies startup does not await the server.
- **Room picking / medium:** an old Unassigned pick could consume the initial allocation even though that location was hidden. Initial picks now use the same visible-location filter as the controls.
- **Android customer creation / high:** the offline customer writer used a Windows drive path and the reader returned an empty list on every non-Windows platform. Android now reads/writes the same customer JSON under its application support directory. Windows retains its existing directory. A temporary-directory roundtrip verifies persistence and updating an existing phone without duplication.
- **Android updates / medium:** returning from unknown-app installation permission settings required an extra manual retry. The update screen now observes resume, rechecks permission, and resumes installation only when permission was granted. Installer signature validation is retained. This native flow still needs a real-device test.

### Validation evidence

- Complete Flutter test suite before follow-up changes: **465 passed**.
- Complete backend `npm test` (including pretest) and `npm run build`: passed. Expected negative-case logging includes rejected corrupt images and simulated email failures; these are test fixtures.
- Windows release built and launched with the existing restored account. Read-only smoke checks confirmed dashboard totals, local invoice history and the new invoice grid with **52 products**. No sale, payment, refund, stock adjustment or customer was created in the live app.
- No connected Android device was returned by `flutter devices`; phone installation, upgrade permissions, printer output and full manual coverage cannot be claimed.
- Widget-test timing logs are not physical-device/profile-mode performance measurements. No sub-100ms runtime guarantee is made.
- After the startup/customer/room/update fixes, the full Flutter suite passed **467 tests**; static analysis remained clean.
- Additional Windows release read-only smoke checks opened Refunds, Reports, Pending Cash and Cash Register successfully. Expiry remained on a full-screen network spinner; its request and category load now time out after eight seconds with retry feedback.
- Further inspection found Cockroach-specific `~*`, `POSITION` and `CONCAT_WS` in stock/expiry queries. These are now SQLite-compatible, parameterized expressions. An actual in-memory libSQL engine test verifies unit classification agrees with the existing application kg/g rule and nullable search is supported. No schema change is required. Deploy the updated backend to apply this server-side fix.

### Scope limits

The automated suite covers admin/customer workflows with fixtures. This does not prove every production screen or network failure mode was manually exercised. Existing UI typography and layout were not broadly redesigned in this recheck. Physical printer centering, fresh-login credentials, Android native installation and live offline/slow-network scenarios remain unverified.
