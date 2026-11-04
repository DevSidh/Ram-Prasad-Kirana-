# Fonepay Dynamic QR: implementation and activation

## Current status: merchant integration is blocked

### Resolving “Cannot GET /api/v1/admin/billing/fonepay/config”

This is a missing deployed backend route, not a bad QR amount or a printer problem. The local source registers GET `/api/v1/admin/billing/fonepay/config` behind billing authentication. On 2026-11-04, GitHub main was still `0b8eb1d`; the new Fonepay backend files were not committed/pushed. Deploying that old GitHub revision cannot provide these routes.

1. Publish the matching reviewed backend changes, including the Fonepay routes/services, shared sale serializer, Prisma schema and both Fonepay migrations. Do not commit backend secrets or local billing/customer data.
2. Deploy that new commit to the existing Render backend service. Review/back up and apply the migrations through the controlled deployment described below.
3. Confirm the signed-in app receives HTTP 200 JSON from the configuration endpoint. An unauthenticated HTTP 401 only confirms authentication is protecting the service; it does not verify that this specific route is deployed.
4. Until the official merchant adapter is supplied, the expected configuration is `enabled: false` with `FONEPAY_PROFILE_REQUIRED`. That is different from the old server's HTTP 404. Deployment alone does not activate real payments.

The updated Flutter client treats a missing configuration route as `FONEPAY_BACKEND_UPDATE_REQUIRED` and shows clear deployment instructions. It does not create a bill, accept a manual success claim or fall back to an offline payment. Retry fetches configuration again after deployment.

The application now has a saved-bill payment workflow, persistent requests, exact NPR amount checks, payment reconciliation guards, a billing dialog and QR-enabled PDFs. **It does not yet connect to Fonepay.** No account-issued API specification or UAT credentials were available during implementation.

The production gateway deliberately returns `FONEPAY_PROFILE_REQUIRED` (HTTP 503). The configuration endpoint reports `enabled: false`. Environment placeholders alone cannot activate it. No real or simulated success can reach production billing through these routes today. Existing cash/manual bank-transfer ledger entries remain available and are not represented as verified Fonepay payments. The old personal static QR UI has been removed.

## Checkout flow update (2026-11-04)

The old PhonePe/UPI choice and personal static QR/manual confirmation UI have now been removed. New billing offers **Fonepay** and changes its submit button to **Pay**. Cash and pending-cash billing retain their normal save behavior. Historical digital records remain labelled Bank transfer; they are not relabelled as verified Fonepay. The personal QR shortcut was also removed from customer checkout; COD ordering remains supported there.

For Fonepay, the following application workflow is implemented, behind the same disabled merchant gateway:

1. Check official merchant configuration first. If unavailable, show the configuration error and create no draft, bill, payment or offline fallback.
2. Save an immutable `PosSale` in `CHECKOUT` state with `FONEPAY` method and `PENDING` payment, using an idempotency UUID and server-validated quote. No invoice sequence, stock consumption or payment collection occurs here. CHECKOUT rows are excluded from completed sales, shift totals and ordinary pending-cash lists.
3. Store a unique provider reference against this saved checkout. Show the centered QR, NPR amount, merchant, reference, “Scan to pay with Fonepay” and “Waiting for payment…”. The top-right cross stops visible waiting and retains the reference. It does not cancel a bank request.
4. Automatic verification runs only when an activated official gateway supplies its documented `verificationPollSeconds` (5–120 seconds); otherwise explicit Verify is available. No provider polling limit is guessed. Callback/webhook transport still awaits the merchant-issued contract. Authenticated callbacks must invoke the same verification/reconciliation path.
5. Matching live proof is durably stored as `VERIFIED`, with provider transaction ID and verification time, before bill finalization. Sandbox proof never creates a real payment or bill.
6. Show a green tick and **Payment successful**, briefly wait, then finalize. Finalization consumes inventory, assigns the invoice number, completes the sale and creates one FONEPAY payment collection in a serializable transaction. Duplicate finalization returns the existing invoice.
7. If finalization fails, the verified proof survives and **Retry bill finalization** does not charge again. A changed checkout is blocked for reconciliation. Stock is not reserved while waiting, so inventory availability can prevent finalization after payment; replenish/reconcile under bank policy rather than collecting another payment.
8. A backend compare-and-set grants a single automatic print claim. The existing print flow runs only for that claim. Printer failure leaves the paid invoice available for manual reprinting from Invoices, without recharging. This guarantees at-most-once automatic print triggering, not exactly-once physical output: a crash after the claim can require manual reprinting.
9. **Pending Fonepay checkouts** in the invoice toolbar reopens closed checkouts, including verified payments awaiting finalization. Reopening uses the same persisted reference. Completed invoices remain in invoice history.

Close is disabled during the brief verified-payment finalization step to prevent the UI from implying that an already-started finalization was cancelled. Waiting can be closed before that step, including during an in-flight verification request.

If cart amount/details change after a draft, the old reference must be cancelled by the provider before the client requests a fresh draft/reference. If remote cancellation is unsupported or payment is already verified, the app blocks a replacement and requires reconciliation. A locally expired QR whose provider still reports PENDING does not release its active slot. Old/late successes cannot settle revised checkouts.

### Additional schema and code changes

- `backend/prisma/migrations/20261120000000_fonepay_checkout/migration.sql`: adds CHECKOUT sale status, FONEPAY payment method, verified/automatic-print timestamps and VERIFIED request state. Review/apply **after** the preceding request-table migration. Neither migration was applied to production by the agent.
- `backend/src/services/pos-sale-serializer.ts`: shared existing sale serialization, extracted from billing routes.
- `backend/tests/fonepay-checkout.test.ts`: draft creation, saved quote, idempotent replay, changed quote and disabled-gateway tests.
- `lib/models/pos_models.dart`: carries the automatic-print decision to the existing completion/printing flow.
- `lib/screens/checkout/checkout_screen.dart`: removes the static personal QR shortcut.
- `lib/widgets/personal_payment_qr_dialog.dart`: removed; its manual “Payment received” flow is no longer active.
- `test/widget/pos_bill_responsiveness_test.dart`: Pay label, disabled processing and repeated-click coverage.

New internal API operations are POST `/admin/billing/fonepay/requests/:id/finalize` and `/claim-print`, plus GET `/admin/billing/fonepay-checkouts`. POST `/admin/billing/sales` with method FONEPAY creates a checkout, not a completed invoice. Client success/amount evidence is never accepted by verification or finalization routes.

The older sections below describe the original saved-unpaid-invoice support and prerequisites. This checkout section supersedes their earlier statement that the new-bill dropdown is unchanged. Official API implementation/credentials, provider callbacks, UAT certification and physical printer validation remain blocked/unperformed.

Fonepay's public [FAQ](https://fonepay.com/faqs) describes merchant onboarding through participating banks and per-bill dynamic QR. It does not establish the API contract for this merchant account. Request the following through your acquiring bank or [Fonepay support](https://fonepay.com/contact-us).

## What you must obtain

1. Merchant-issued Dynamic QR integration specification, revision/date and merchant agreement; confirmation this is merchant billing QR rather than a different payment product.
2. Separate UAT and production base URLs and exact create, status/verification and cancellation endpoints.
3. Merchant code/name, API credentials, signing keys/certificates and the documented authentication/signature algorithm, canonicalization and response authentication rules. Supply secrets only through backend environment configuration.
4. Exact amount representation (major/minor units, decimal rules), NPR currency fields, allowed payment-reference format/length, expiry rules and QR response format.
5. Authenticated verification response fields: merchant, reference, currency, amount, final successful status and stable unique provider transaction ID. Clarify eventual consistency, reversals, late settlement and refunds.
6. Callback/webhook contract, signature verification and replay protection, retries, IP/mTLS requirements, status polling limits and idempotency rules.
7. UAT merchant credentials, payer/test accounts, test cases and certification/production approval process.

Do not paste secrets into chat or commit them. A static personal QR image is not sufficient to authorize this API integration. No community sample endpoint, password or signature scheme has been substituted.

## Existing architecture and amounts

- Flutter/Dart with the existing authenticated API service and billing screen; backend Express/TypeScript, Prisma and CockroachDB.
- Only an existing **server-saved, completed POS sale with a pending payment and positive balance** can start this flow. Admins can access all such sales; billing staff only their own shift's sales.
- The backend reads saved Decimal totals, taxes, discounts, received payments and revision metadata. It uses integer paisa to calculate `saved total - saved paid amount`; it never accepts an amount from Flutter. The saved final total already includes invoice calculations/rounding.
- Internal canonical amount is a two-decimal NPR string. The future reviewed gateway must translate this into the amount format specified by Fonepay. This is not an assumption about Fonepay's wire format.
- Bills with refunds are blocked pending explicit reconciliation support.
- Computer-only bills/customers are **not uploaded** for QR generation. Their Fonepay action is disabled. Supporting them would require a separate approved design and storage decision.
- This addition covers POS checkouts and saved POS invoices. It does not add Fonepay checkout payments for online customer orders.

## Files and dependency

Backend:

- `backend/src/services/fonepay-gateway.ts`: gateway contract and deliberately disabled production factory.
- `backend/src/services/fonepay-payments.ts`: persisted intents, saved amount/revision checks, verification and atomic collection.
- `backend/src/routes/admin-fonepay.ts`: authenticated billing API, strict empty POST bodies.
- `backend/src/routes/admin-billing.ts`: route mounting.
- `backend/prisma/schema.prisma` and `backend/prisma/migrations/20261119000000_fonepay_payment_requests/migration.sql`: additive request model/migration.
- `backend/.env.example`, `backend/package.json`: configuration placeholders and test command.
- `backend/tests/fonepay-payments.test.ts`, `backend/tests/migration-schema-locks.test.ts`: fixtures and migration guard.

Flutter:

- `lib/models/fonepay_payment_request.dart`: validated request, bill matching and sandbox isolation.
- `lib/services/fonepay_api_service.dart`: backend calls; no client amount or payment proof.
- `lib/widgets/fonepay_payment_dialog.dart`: QR/status/verification, reference recovery, cancellation and printing.
- `lib/screens/admin/admin_billing_screen.dart`: Pay with Fonepay action on saved pending invoices.
- `lib/services/pos_receipt_service.dart`, `lib/services/invoice_pdf_builder.dart`: QR payment instructions in existing invoice layouts.
- `pubspec.yaml`, `pubspec.lock`: added `qr_flutter` 4.1.0. Existing PDF, printing and preferences packages are reused.
- `test/fixtures/fonepay_fixture.dart`, `test/unit/fonepay_payment_test.dart`, `test/widget/fonepay_payment_dialog_test.dart`: nonpayable fixtures and client tests.
- `tool/fonepay_print_validation.dart`: local PDF rasterization harness, not the production application entry point.

## Database deployment

**No production database migration has been run for this task.** Review and back up before deploying.

1. Review the additive migration with the database administrator. It adds `PosFonepayRequest` and indexes/FK; it does not delete historical data or alter historical balances.
2. The migration includes schema unlock/relock statements around schema operations, matching this CockroachDB project's existing changefeed constraints. Review active changefeeds and privileges first.
3. Generate Prisma Client and apply the migration through the project's normal controlled deployment (`npm run prisma:generate`, then `npm run prisma:migrate:deploy` from the backend).
4. If a migration fails, inspect actual database state and Prisma history before resolving it. Do not blindly mark it applied or delete migration records.
5. Deploy backend and Flutter changes together only after compatibility review. Payment activation remains disabled regardless of migration completion.

## Backend configuration and remaining adapter work

The example environment contains placeholders:

```dotenv
FONEPAY_MODE=disabled
FONEPAY_OFFICIAL_DOCUMENT_REVISION=
FONEPAY_MERCHANT_CODE=
FONEPAY_MERCHANT_NAME=
FONEPAY_API_BASE_URL=
FONEPAY_API_USERNAME=
FONEPAY_API_PASSWORD=
FONEPAY_SIGNING_SECRET=
```

These names reserve configuration space; **authentication is not implemented yet** and the final fields may change with the issued specification. Never put merchant secrets in Flutter, APK assets, QR payload logging, or frontend environment files.

After receiving the specification, implement a reviewed gateway with authenticated create/verify/cancel, exact response validation, HTTPS endpoints, bounded/abortable network calls and the provider's signature requirements. Replace the disabled factory and update `/config` only when this profile is explicitly configured and validated. Callback handling is not implemented; add it according to the official contract and have authenticated notifications trigger authoritative reconciliation. Do not trust notification text or client success flags.

## Operator flow after activation

1. Save a server-backed bill with a pending balance, then open its invoice and choose **Pay with Fonepay**.
2. Backend stores a unique reference and frozen saved balance before contacting the provider. Reopening resumes the reference; duplicate create requests do not generate another charge.
3. Display merchant, bill number, NPR amount, reference, QR and state. Sandbox requests are visibly labelled and cannot create a real payment collection.
4. Choose **Verify with Fonepay**. Today this is a manual action with a five-second backend lease between requests; provider polling intervals must come from the official contract.
5. Only authenticated live proof matching environment, merchant, reference, currency and exact amount can settle a bill. A single serializable transaction updates the balance, records the collection and stores the unique provider transaction.
6. For an existing unpaid invoice, use **Print/PDF with QR** or **80 mm receipt with QR** in the dialog. New checkout drafts cannot be printed as completed bills from this dialog; their verified final bill uses the existing completion/print flow. A4/58 mm/80 mm builders support QR payment instructions for unpaid invoices. Ordinary existing print actions do not automatically fetch a payment request. Paid/expired/stale QRs are not printed as payable.

### Failure and revision handling

- Timeout or uncertain creation retains the same reference and blocks a second remote request.
- Closing the dialog is not cancellation. Unsupported remote cancellation does not release the request slot or imply the bank stopped accepting the QR.
- Bill edits or other payments invalidate the frozen fingerprint. Old QR payloads disappear and old successes cannot settle the revised balance.
- Confirmed failed/cancelled/expired requests can be retired; locally detected expiry alone retains the active slot until provider reconciliation/cancellation. Requesting a replacement may remain blocked for this reason.
- Late success, duplicate provider transaction or mismatched evidence enters `REVIEW`. It does not credit another bill. An authorized operator must reconcile the provider account and resolve/refund according to bank policy; no automatic refund or review-resolution UI is implemented.
- Sandbox verification uses `TEST_VERIFIED`, never updates sale balances or payment collections. Fixture gateways exist only in tests; there is no production mock mode.

## Validation and limitations

Local tests cover exact money, saved-bill binding, ownership, duplicate create/verify/transaction handling, tampered fields, revised bills, expiry/cancellation, uncertain responses, throttling, sandbox isolation, disabled configuration and client-body rejection.

Flutter tests cover model validation, reference recovery, disabled configuration, sandbox UI, exact displayed balance and PDF generation. The app's Windows printing plugin renders nonpayable fixture PDFs for A4, 58 mm and 80 mm; their PNG previews are visually inspected for QR, amounts and clipping.

**This is not Fonepay UAT certification.** Official QR generation/scanning, merchant authentication, actual bank verification, real callbacks, cancellation, late settlement, physical printer output and phone banking-app compatibility remain untested until official merchant access is supplied. Test QRs contain literal `TEST-ONLY-NONPAYABLE-FONEPAY-FIXTURE`; they cannot be used to pay.

Before enabling live mode, run the bank's full UAT matrix with exact/incorrect amounts, matching/mismatching references and merchants, duplicates, simultaneous notifications, network interruption, expiry, bill revisions and printing. Obtain approval and perform a reconciled low-value production smoke payment under the merchant's authorization.

Run local checks with `npm run test:fonepay` / `npm test` / `npm run build` in the backend and `flutter test` in the Flutter root. Never ship the print harness as the app; build the normal `lib/main.dart` entry point.

### Recorded local results (2026-11-04)

- Full Flutter suite after the checkout changes: **258 tests passed**.
- Full backend suite, including Fonepay orchestration fixtures and migration guards: **passed**.
- Backend TypeScript build and Prisma Client generation: **passed**.
- Normal Windows Release build from `lib/main.dart`: **passed**. This is the application build, not the print harness.
- VS Code diagnostics for the changed billing/payment/printing files: **no errors**.
- Windows Profile compilation of the print validation harness: **passed**; A4, 58 mm and 80 mm fixture PDFs each rendered to one page and were visually inspected. Fixtures display NPR 113.01 final total, NPR 13.00 already received and NPR 100.01 payable QR balance.
- Final paid A4 and 80 mm receipt fixtures were also rendered and visually inspected, showing Fonepay and the saved NPR 113.01 total. These are document fixtures, not evidence of a bank payment.
- Checkout-specific local cases cover exact quote rounding, no completed bill/stock/collection before payment, modal closing during in-flight verification, a visible success state, retained verification after stock failure, idempotent finalization and the single automatic print claim. Provider callback transport remains unimplemented; duplicate reconciliation calls are tested locally instead.
- Provider UAT/live API, live database migration, real banking-app scan and physical printer tests: **not run / blocked by missing merchant access or hardware**.
