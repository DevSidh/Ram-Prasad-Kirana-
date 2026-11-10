# FastStore 3.3.5 — Windows billing computer

Windows-only release. Android remains on 3.3.4.

- Includes the current invoice-entry layout with inline editable unit price and line total.
- Includes existing local billing, receipt PDF archiving, Excel exports and catalogue cache features.
- Extract the complete ZIP to a new folder. Close the old app, then open RamPrasadBilling.exe from the new folder. Keep DLLs and the data folder beside it.
- Preserve C:\Ramprasad store and all existing business records. This package does not migrate or delete business data.

Validation: release build and static-analysis results are reported with publication. Physical printer operation and real billing-computer performance require hardware verification. Three failures were reported by the previous release's full CI suite; this release does not claim to resolve them. Backend deployment-dependent features still require the matching server code.
