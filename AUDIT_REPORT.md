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
