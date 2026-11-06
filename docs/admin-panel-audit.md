# Admin panel audit — 6 November 2026

## Scope and safety

Read the project instructions, README, local-billing reliability notes, admin navigation, API services, authorization middleware, route declarations, and existing tests. The application is Flutter; administrative operations use the Express/Prisma backend. The root React prototype is not the live admin application.

Used in-memory HTTP/Prisma fixtures and injected catalog storage. Did not deploy, publish, migrate, reset the database, or intentionally modify real customer, order, inventory, payment, or billing files. The native preview replaces preferences with an in-memory test store and blocks API mutations and uploads. Existing uncommitted work and old release-file deletions were preserved.

## Fixes

| Problem | Root cause / change |
| --- | --- |
| Customer edits could save and then report HTTP 500 | The response included the database BigInt `userNumber`. Return the formatted profile ID and public fields, excluding the raw sequence. |
| Old customer/delivery logins revived after reactivation | Deactivation now increments `tokenVersion`; reactivation does not restore revoked tokens. |
| Expired admin sessions had ineffective Retry loops | A current-token HTTP 401 raises a shared sign-in signal. The shell offers Sign in again. Responses for an older token cannot invalidate a newer login. Existing local bills remain in place. |
| Search, pagination and refresh showed stale results | Added request-generation guards to customers, orders, delivery board/staff, supplier bills, SKU editor, categories, coupons, restock, showcase and streak loads. Stale successes and failures cannot replace newer results. |
| Catalog error recovery could call setState after disposal | Recheck mounted/request generation after reading cached categories on Products and Wholesale. Catalog storage can now be injected into both pages and their API adapter. |
| Failed settings load could overwrite settings with defaults | Customer-menu controls remain disabled until a successful load. Saving and retrying cannot run simultaneously. |
| Damaged local records could block even a working live dashboard | Handle local totals and snapshot read failures independently; continue fetching the server and show a storage warning. |
| Narrow and Nepali layouts overflowed | Bound dropdowns; wrap promotion-banner controls; stack SKU editor controls and banner retry actions; make billing staff content scrollable; move the narrow settings Save action into the page; constrain supplier-header action and delivery Add staff action. |
| Pausing a featured coupon crashed Promotions | The banner dropdown retained an ID absent from its allowed items. Restrict candidates to active store-wide/unassigned coupons, select only an eligible featured ID, and reset field state when that selection changes. Existing inactive featured records also load safely. |
| Wholesale banner text became unreadable in dark mode | Use white foreground on its existing dark green background. Scanner overlays also use a visible white foreground. |
| Focused product-name label touched the modal clipping edge | Add space at the top of the product form's scroll content. |
| Reduced-motion accessibility setting ignored | Show the existing static animation fallback when the operating system requests reduced motion. |
| Web build failed in stock summary | Remove the unnecessary 64-bit maximum literal and preserve integer quantities while clamping negative stock to zero. |

No dependency additions or database migrations are required.

## Automated coverage

- New page matrix: 19 pages at 390 px and 1366 px; empty, failure and populated fixture states; Nepali on narrow layouts and English on desktop; initial rendering, scroll and disposal. Some fixture collections remain empty even in populated mode, so this is not exhaustive record/interaction coverage.
- Pages: announcements, billing staff, categories, coupons, customers, delivery, expiry, orders, products, drinks, restock, stock history, showcase, SKU editor, store hours, streak, supplier bills, wholesale and customer-menu settings.
- Create forms: products, drinks, wholesale, categories, coupons and delivery staff, at both widths. Required-field rejection and Cancel are checked to send zero API writes.
- Specific regressions: out-of-order customer/supplier responses; catalog disposal during cache recovery; failed settings load and successful retry; damaged local dashboard data; session signals and stale 401 responses; sign-in banner on phone/desktop; wholesale foreground contrast in both Windows themes.
- Server access matrix derives 86 route/method combinations from actual router declarations. Checks 322 denied requests using unauthenticated, customer, delivery and billing identities, including admin-only billing actions. Denied requests cannot write records. Separate HTTP checks prove old tokens stay revoked after customer/delivery reactivation.
- Existing suites also exercise billing idempotency, payments, stock deductions, returns/exchanges, local records, customer removal safeguards, uploads, auth/roles, filtering, supplier receipts and transactions with mocks/temporary fixtures.

## Validation results

- Full Flutter suite: **440 passed**, including the final coupon, session, cache recovery, form-validation and contrast regressions.
- Full backend `npm test`, including pretest groups and the new route-security audit: **passed**.
- Backend TypeScript compilation: **passed**.
- Windows debug preview: **built and ran**. Inspected English/Nepali product views, product modal, table view, wholesale stock units, SKU navigation and light/dark appearance using test data. The native preview was closed afterward.
- Actual application Windows release build (`lib/main.dart`): **passed**, producing the current `build/windows/x64/runner/Release/RamPrasadBilling.exe`. No ZIP was regenerated or published.
- Localization scan: no missing billing-copy candidates after adding the new messages.
- Flutter analyzer: **no issues** after the final changes. Git whitespace check: passed.
- Browser preview: **compiled and served HTTP 200** after the stock-summary fix. Startup recording captured zero page/console errors and zero failed/HTTP-error requests; a missing Google Maps web key warning remains, with map pin selection disabled. Observed Nepali language switching and the product semantics tree. Integrated-browser modal actions were unreliable and are **not verified end to end**.

Expected negative-test logs (invalid image buffers, unavailable email providers and mocked network errors) are not evidence of production failures. Native debug linking emitted missing Firebase PDB warnings but produced a running executable.

## Reproduce

All shell commands must follow the RTK project instruction.

```powershell
rtk powershell -NoProfile -File tool/run-admin-audit.ps1 flutter
rtk powershell -NoProfile -File tool/run-admin-audit.ps1 analyze
rtk powershell -NoProfile -File tool/run-admin-audit.ps1 backend
rtk powershell -NoProfile -File tool/run-admin-audit.ps1 typescript
rtk node tool/billing_localization.cjs audit
```

The audit runner writes logs below ignored `tmp/`. The VS Code tasks **Preview isolated admin audit** and **Preview isolated admin audit in browser** launch [the test-only preview](../tool/admin_audit_preview.dart). Do not distribute this preview as the actual app: mutations are intentionally disabled.

New regression sources: [page/form matrix](../test/widget/admin_page_audit_test.dart), [recovery/race cases](../test/widget/admin_audit_regressions_test.dart), [HTTP authorization/session cases](../backend/tests/admin-audit-security.test.ts). Existing API/session and responsive-navigation tests were extended.

## Remaining access and testing limits

- No isolated CockroachDB instance, staging URL, or staging staff accounts were supplied. Actual database constraints/migrations, real multi-device races and UI-to-database end-to-end CRUD remain unverified. In-memory Prisma fixtures cannot establish those results.
- Physical printers, cameras, barcode scanners, mobile photo picking, real bank/Fonepay confirmations, push delivery and mail delivery require device/service trials. Automated payment/printing fixtures do not prove physical output or a real charge.
- The browser/native preview is a fixture-backed subset, not an authenticated tour of every live screen. Browser-specific uploads, every keyboard/screen-reader path, all sorting/pagination permutations and every real-data edge case have not been certified.
- No production deployment, GitHub release, APK or replacement Windows ZIP was published for this audit. Existing packages do not automatically include these source fixes.
