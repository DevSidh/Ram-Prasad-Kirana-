# FastStore performance implementation — 4 November 2026

## Scope and environment

Targeted improvements in the existing Flutter application, with its existing Provider/BLoC architecture, HTTP services, file records and Prisma/CockroachDB backend. No database reset, replacement, new migration, package, payment integration or production-data test was introduced.

Reference machine: Intel Core i7-14650HX, 24 logical processors, approximately 16 GB RAM, Windows build 26300. Flutter 3.47.5 stable, Dart 3.13.4, DevTools 2.60.0. Default Windows Impeller renderer; no renderer flags changed.

The measurements below use profile/release executables, not debug test timings. Fixtures are generated in unique temporary directories. The UI scenario drives the **production `PosBillDialog`**, with injected catalogue storage and a synthetic API. It does not submit payments or real sales. This is not a measurement of the entire authenticated application or external network/provider latency.

## Measured bottlenecks and changes

1. **Catalogue lookup reread the complete catalogue and every saved bill for each search.** Added a bounded catalogue cache (up to four catalogues of at most 20,000 products each), validated against file metadata. Larger catalogues still work without being retained in this cache. Filter before projecting stock. Display stock estimates have a one-second cache, immediately invalidated by app writes. Financial validation bypasses both caches and reads disk under the existing writer lock.
2. **Unchanged lookup responses rewrote the entire catalogue and its recovery copy.** Compare all product snapshot fields and skip unchanged writes. Actual changes still use the same atomic replacement and flushed storage path.
3. **Known barcodes waited for a network response.** Exact cached matches open the existing quantity prompt immediately. Uncached codes retain server lookup. Server checkout validates a supplied price/total quote inside its transaction; changed quotes return a conflict without saving a sale or consuming stock.
4. **Rapid scan callbacks could overlap lookups and quantity prompts.** Added an ordered queue that retains repeated codes, isolates individual errors, and stops admitting actions after disposal. A separate ordered addition queue prevents overlapping quantity dialogs. Checkout/hold cannot race admitted additions.
5. **Quantity edits rebuilt the entire composer.** Existing local state now has small ValueNotifier boundaries for cart membership and totals, and a notifier per cart line. Row identity and text controllers remain stable. Customer details and the product list do not rebuild for ordinary quantity edits. No state-management replacement or blanket repaint boundaries were introduced.
6. **A full catalogue download started on every bill window.** Full refreshes share in-flight work and reuse the last successful full refresh for five minutes. Successful product/drink/wholesale mutations invalidate that window; explicit pending-product retry forces refresh. Failed refreshes are not marked successful. Final checkout still checks authoritative prices and inventory.
7. **Identical in-flight POS searches could repeat.** Coalesced within the AdminApiService instance, scoped to the API authentication revision. Responses are not retained as a permanent network cache. Search invalidates older requests immediately when typing begins, including during debounce. Barcode submissions are never debounced or coalesced.
8. **Long histories serialized every file read.** Read financial records in batches of eight asynchronous reads, without caching their contents for financial checks. All recovery/error handling and writer locking remain.
9. **Dashboard networking waited for local history first.** Server and local reads now start concurrently; stale dashboard responses cannot replace a newer request. Valid live figures are displayed before persisting their nonfinancial snapshot. Snapshot-save failure has its own warning. Narrow dashboard metric grids use one column when two cards cannot fit. Billing amount text also scales down within its allocated row instead of overflowing.
10. **Duplicate actions before an asynchronous payment prompt were possible.** Added a checkout guard covering the prompt and submission, plus a product-save reentry guard. Existing idempotency, payment verification/manual confirmation rules, money rounding, permissions, durable commits and recovery are retained.

## Comparable profile measurements

Service workload: 2,000 products, 3,000 isolated saved bills; 30 barcode searches, 20 unchanged merges and 10 durable sale commits. Values are milliseconds. Warm searches below are a burst inside the display-cache lifetime; the first load or a refresh after expiry can still scan the history.

| Operation | Before p50 / p95 | After p50 / p95 |
|---|---:|---:|
| Warm cached barcode lookup | 722.905 / 843.798 | 0.698 / 1.616 |
| Unchanged product merge | 17.722 / 21.715 | 1.554 / 3.104 |
| Local durable sale including fresh stock validation | 719.209 / 752.310 | 773.567 / 854.723 |

The single cold catalogue/history read was 704.119 ms before and 502.748 ms after. This is **one sample**, not a cold-start percentile. Durable commits did not improve in this comparison and remain above the aspirational 500 ms goal for this history size. Filesystem flush, fresh full-history validation, antivirus and system scheduling remain costs. No durability checks were removed to obtain a better number.

Actual composer workload: 100 held cart lines, a 2,000-product fixture catalogue, 60 quantity edits, then 20 repeated queued scans.

| Measurement | Before p50 / p95 | After p50 / p95 |
|---|---:|---:|
| UI-thread build duration | 4.410 / 11.379 | 1.644 / 2.868 |
| Raster-thread duration | 1.391 / 4.192 | 1.412 / 3.727 |
| Quantity callback to completed frame | 9.716 / 28.479 | 4.631 / 18.302 |

Both UI runs retained all 20 admitted repeated scans. Only the initial product-list API call occurred; the cached scan burst did not request a server lookup per scan. These callbacks simulate submitted scanner input; they do not certify a physical USB/Bluetooth scanner's keyboard focus or camera/network transport.

Release-mode confirmation: UI build p95 **2.166 ms**, raster p95 **2.063 ms**, quantity callback-to-frame p95 **8.047 ms**, 20/20 scans retained. This scenario does not establish a 60/120 FPS guarantee across all screens and hardware.

Raw comparable results: [before services](performance/before-large.json), [after services](performance/after-final.json), [before composer](performance/billing-ui-profile.json), [after composer](performance/billing-ui-after.json), [release composer](performance/billing-ui-release.json). Other runs in that directory are exploratory/diagnostic and are not the comparison baseline.

## Diagnostics and memory

Attached DevTools to the Windows profile process and inspected its Performance frame analysis. A separate diagnostic run collected 1,308 CPU samples at a 1,000 µs sampling period over approximately 6.25 seconds; see [CPU summary](performance/cpu-summary.json). The largest exclusive samples were native engine/allocation/synchronization and Flutter frame work. No measured JSON/image CPU hotspot justified creating an isolate for each scan or moving plugins between isolates.

The diagnostic heap after requesting CPU samples includes the large profile response and serialization buffers; it is not comparable to ordinary application memory or evidence of a leak. Clean service workload peak process RSS was approximately 157 MB before / 149 MB after in these runs. A single short pass cannot establish long-session memory behavior or GC stability. Diagnostic timings are excluded from the clean comparisons.

## Verification

- Complete Flutter suite: **246 passed, zero failed**.
- Complete backend `npm test`: passed, including inventory concurrency, batches/FEFO, offline replay, refund bounds, idempotent collections, permissions, quotes and schema-lock checks.
- Backend TypeScript build: passed.
- Windows profile and release composer scenarios: passed, including repeated scan count and quantity totals.
- Production Windows release built from `lib/main.dart` for the delivery package.
- Existing responsive tests now inject deterministic storage/API fixtures instead of reading real billing files or waiting forever on animated network errors. They still exercise the actual navigation. The new widget tests cover row/count/totals, removal, repeated scans, duplicate checkout and stale search responses. Filesystem tests separately cover real temporary-file durability, invalidation, recovery and fresh financial reads.
- No production database queries, charges, notifications or printed receipts were used as test traffic.

## Remaining verification and costs

- No physical Android/iOS device was connected. Mobile frame times, lower-end hardware, battery, suspend/resume and camera scanning remain unverified. The shared Dart changes pass the Flutter tests; no mobile speed claim is made.
- Full process cold/warm startup, authentication/network startup, all navigation destinations, large image sets and long cashier sessions were not benchmarked end to end. The composer-first-frame number excludes process startup and authentication.
- The fresh local financial history scan remains a checkout cost. Warm display-cache numbers do not apply to that commit path or to the first lookup after the estimate expires.
- No live/staging database query plans or payment-provider timings were available. Existing bounded product queries and transactional inventory logic were preserved; no speculative database indexes/migrations or provider polling changes were made.
- Printer drivers, actual scanners/scales, multiple physical tills and real network-loss/reconnection require a device run. Existing automated recovery/concurrency tests are not a substitute for those trials.
- Authentication and online ordering semantics, server quote conflicts, computer-only bill storage and pending cash are preserved. A cached price that has changed must be reviewed/reselected before retrying; the server does not silently accept a changed total.

## Reproduce safely

From the repository root (RTK is configured on this workstation):

```powershell
rtk flutter run -d windows --profile -t tool/pos_performance.dart --dart-define=PERF_LABEL=services-repeat --no-resident
rtk flutter run -d windows --profile -t tool/billing_ui_performance.dart --dart-define=PERF_LABEL=composer-repeat --no-resident
rtk flutter run -d windows --release -t tool/billing_ui_performance.dart --dart-define=PERF_LABEL=composer-release-repeat --no-resident
# Separate diagnostic run; attach the printed DevTools URL.
rtk flutter run -d windows --profile -t tool/billing_ui_performance.dart --dart-define=PERF_LABEL=composer-trace --dart-define=PERF_DIAGNOSTIC=true
rtk flutter test
rtk npm test --prefix backend
rtk npm run build --prefix backend
rtk flutter build windows --release -t lib/main.dart
```

Keep benchmark runs separate from test/build activity and expensive tracing. Reproduce before/after on the same hardware, dataset and power settings. The harnesses only remove their own allocated temporary directories. Diagnostic raw CPU dumps are generated locally and ignored by Git because they are large.

## Modified implementation files for this performance pass

- [Billing composer and flow](../lib/screens/admin/admin_billing_screen.dart)
- [Dashboard](../lib/screens/admin/admin_dashboard_screen.dart), [shell](../lib/screens/admin/admin_shell.dart), [product save guard](../lib/screens/admin/admin_products_screen.dart)
- [Local financial storage](../lib/services/local_billing_store.dart), [offline catalogue](../lib/services/offline_pos_store.dart), [ordered work queue](../lib/services/ordered_work_queue.dart)
- [Admin API](../lib/services/admin_api_service.dart), [API authentication revision](../lib/services/api_service.dart)
- [Server transactional quote validation](../backend/src/routes/admin-billing.ts), [server checks](../backend/tests/admin-billing-reliability.test.ts)
- [Persistence/cache checks](../test/unit/pos_performance_correctness_test.dart), [queue checks](../test/unit/ordered_work_queue_test.dart), [composer checks](../test/widget/pos_bill_responsiveness_test.dart), [responsive fixtures](../test/widget/responsive_layout_test.dart)
- [Service harness](../tool/pos_performance.dart), [production composer harness](../tool/billing_ui_performance.dart)

## Rollout

Deploy the updated backend **before** distributing this client: it accepts and validates the new optional `quote` field. Older clients remain compatible because the field is optional. An older strict backend rejects the new client's field. No schema migration or new environment variable is required for this pass. No Git push, deployment or public release was performed.

The Windows ZIP contains the real main-application executable, DLLs and Flutter data, not either profiling harness. Extract the complete ZIP into its own application folder. Keep existing business data under `C:/Ramprasad store/` intact. No business data or credentials are bundled in the ZIP. This package does not contain a new signed Android release.

Profiling approach follows the [Flutter performance guidance](https://docs.flutter.dev/perf/ui-performance) and [DevTools Performance documentation](https://docs.flutter.dev/tools/devtools/performance); these distinguish profile/release measurements from debug results and warn that enhanced tracing affects timings.
