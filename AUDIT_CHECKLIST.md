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
- [ ] Full test suite: local catalogue cleanup/recovery failures remain
- [ ] Physical printer, offline network, 5,000-product profile run
