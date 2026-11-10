# Windows Admin Panel Audit Checklist

## Access and shell
- [x] Login, auth session, role gate, admin shell navigation
- [x] Dashboard, date filter, loading, empty, and error states
- [x] Window resize and narrow viewport smoke tests

## Billing and financials
- [x] New retail invoice, product search, barcode shortcut, cart and totals
- [x] Wholesale and drinks billing entry points
- [x] Customer selection and offline customer details
- [x] Payment methods, pending cash, partial payment, duplicate-click protection
- [x] Hold/resume and local-only save behavior
- [x] Room inventory source selection during item entry
- [x] Invoice history, bill details, refund/return entry points
- [x] Receipt generation and configured paper-width paths

## Catalog and stock
- [x] Products CRUD, images, SKU/barcode, categories
- [x] Wholesale products and supplier/restock flows
- [x] Drinks menu and menu settings
- [x] Inventory rooms and expiry view
- [x] Stock validation and local catalogue cache paths

## Operations
- [x] Customers, customer menu settings
- [x] Online orders, delivery staff, assignments, order status
- [x] Reports, announcements, coupons, streaks, store hours
- [x] Billing staff permissions and settings/showcase screens
- [x] Backup/export and local sync service paths

## Verification
- [x] `flutter analyze`
- [x] Admin page audit tests
- [x] Invoice responsiveness tests
- [x] Full test suite: prior local catalogue cleanup/recovery failures resolved
- [ ] Physical printer, offline network, 5,000-product profile run

## Recheck — 2026-11-10
- [x] Complete Flutter suite before follow-up fixes: 465 passed
- [x] Complete backend test command and TypeScript build
- [x] Windows release launched: restored session, dashboard totals, invoice history, invoice product grid (52 products)
- [x] Slow legacy profile refresh moved off startup path; isolated regression test
- [x] Android offline customer storage reviewed and corrected to application support directory
- [x] Room controllers ignore hidden Unassigned selections
- [ ] Physical Android install/update and device smoke test (no Android device connected)
- [ ] Every production menu exercised manually (covered by fixture tests; runtime smoke test limited to the screens above)
