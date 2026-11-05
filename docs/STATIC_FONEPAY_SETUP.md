# Static QR payments in POS

## Business QR setup

The store owner's new eSewa Circle QR is bundled at
`assets/images/business_esewa_qr.jpeg` and is now the default payment QR.
Its original pixels and white quiet zone are preserved. The QR is available
offline and requires no remote image download.

For another approved bundled image, set the build define
`FONEPAY_STATIC_QR_ASSET=assets/images/your_approved_qr.png`.
Missing or unreadable images disable payment confirmation. No sample or
generated replacement QR is used. Keep the image's original white quiet zone.

## Cashier procedure

1. Select eSewa / QR and press Pay. No completed sale or payment is created yet.
2. The customer scans the static QR and manually enters the displayed NPR total.
3. Tick **I received the full payment of this bill** to record your confirmation.
   There is no transaction-reference field or automatic payment check.
4. A stable internal cashier-confirmation ID is generated for retries and audit.
   It is explicitly classified as CASHIER_CONFIRMATION, not a bank transaction ID.
5. Press **Payment Verified — Create & Print Bill** once. This records a manual
   cashier attestation, not automatic Fonepay verification.
6. If printing fails, use **Reprint Bill**. The committed bill number is reused;
   the payment is not recorded again.

Cancel/Back before confirmation creates no completed bill. Printing cannot
change an already committed payment back to pending. Keep the dialog open and
retry the same checkout if saving fails or the network response is uncertain.
Do not start another bill for a payment already received.

## Storage and deployment

- Deploy the updated backend before using online static-QR POS checkout. No
  merchant API credentials or Fonepay server API are required.
- The eSewa provider is recorded in audit metadata under the existing DIGITAL
  payment category. API responses, bills and UI show eSewa. No enum migration
  is needed. Existing Fonepay bills remain unchanged.
- No database migration: the existing payment collection's `note` stores a
  versioned `FASTSTORE_MANUAL_FONEPAY_V1:` JSON audit record containing MANUAL,
  reference, cashier ID, server confirmation time, NPR currency and exact amount.
  The existing `recordedById` also identifies the authenticated cashier.
- Computer-only bills keep the same audit record in their existing local JSON.
  They remain computer-only and are not silently uploaded on a network error.
- Stock, totals, discounts, VAT and invoice numbering use existing checkout
  validation. Backend request references deduplicate retries; local initial print
  claims are recorded under the existing financial writer lock.
- Old API-backed Fonepay checkouts retain their separate recovery workflow; they
  cannot be manually marked paid through this new-sale action.
- Customer checkout does not receive a manual payment-confirmation button.
