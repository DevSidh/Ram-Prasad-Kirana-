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
| Windows local-store tests | Medium | Temporary test folders can remain locked during cleanup when the SQLite/local-store tests run together. | Not fixed; requires isolating/closing the desktop database per test. |
| Catalogue recovery test | Medium | Recovery assertion receives the updated snapshot rather than the previous snapshot after a merge. | Not fixed; needs a decision on whether merge recovery should preserve pre-merge data or the latest committed data. |
| Performance cache tests | Medium | Several cache invalidation tests fail under the full parallel suite because of the same file-lock/isolation behavior. | Not fixed; no production data was changed. |

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

1. Give each local-store test an explicitly closed SQLite/database instance before deleting its temporary directory.
2. Define and test the intended catalogue recovery policy for interrupted updates.
3. Rerun the complete suite serially and then in parallel after those changes.
