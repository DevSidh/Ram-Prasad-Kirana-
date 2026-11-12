# Faststore catalogue import

The supplied `product_catalogue_unlimited_and_error_audit.xlsx` contained 84 rows.

The libSQL batch importer applied all 84 rows in nine Turso write batches.

## Verified live database totals

- Active retail/drink products: 333
- Active drinks: 14
- Wholesale items: 36
- Combined active catalogue records: 369
- Products marked unlimited stock: 231
- Products with positive room stock allocations: 64

The import is idempotent by deterministic SKU and existing product ID matching. Missing prices used Rs. 100; blank or `Unlimited` stock used unlimited stock. Invalid workbook locations were retained in the source workbook but were not invented as room assignments.

Detailed source workbook: `Faststore-Inventory-Details-84-Rows.xlsx`.
