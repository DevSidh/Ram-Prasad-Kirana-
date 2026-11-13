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
- Final Windows **3.3.3+29** was launched successfully. Its Expiry request was observed ending in the retry state instead of spinning indefinitely. The live expiry endpoint still did not return data during this check; the backend fixes have been pushed to the feature branch but not deployed to production. Do not treat live expiry loading as verified working.
- Final follow-up checks: expiry success/filter and timeout tests both passed; backend suite rerun passed after the SQL changes; the new libSQL engine regression passed separately; analysis remained clean.
- Both Windows and Android **3.3.3+29** release builds succeeded. Android APK metadata reports package `com.freshharvest.grocery_app`, version name `3.3.3`, version code `29`; Android build-tools signature verification reports a valid v2 signature and one signer. This is package verification, not a phone installation test.

### Scope limits

The automated suite covers admin/customer workflows with fixtures. This does not prove every production screen or network failure mode was manually exercised. Existing UI typography and layout were not broadly redesigned in this recheck. Physical printer centering, fresh-login credentials, Android native installation and live offline/slow-network scenarios remain unverified.

## Recheck — 2026-11-13

### Receipt and release follow-up

- **Receipt clipping / high:** the compact 58mm renderer used a layout wider than the tested printer area, causing the right side of labels such as `Amount` to be clipped. The 58mm layout now uses a conservative 28-column printable width and narrower item column; 80mm remains at 42 columns. Line totals, total, discount and balance use normalized money formatting so values smaller than half a paisa render as `0.00` rather than `-0.00`.
- **Validation:** `flutter analyze` passed with no issues. The focused receipt suite passed all 6 tests, including cold preparation and cache reuse measurements. The complete Flutter suite passed in this workspace. A Windows release build was invoked after the receipt change; the physical printer and a fresh executable timestamp still require verification on the billing computer.
- **Saved product validation:** the existing product and wholesale save paths now reject invalid numeric/category input before issuing a request and preserve the existing API contract. These changes were previously committed and covered by the admin API tests.

### Environment limits

- Physical 58mm/80mm printer output, DPI scaling, multi-monitor resize, profile-mode DevTools frame timings, live Turso latency, and Lighthouse scores were not measurable from this session.
- The public Vercel site is still serving its prior deployment because the Vercel CLI session is logged out. No claim is made that the live website is updated; deployment requires the project owner’s Vercel credentials.
