import 'package:freshharvest_grocery/models/pos_models.dart';
import 'package:freshharvest_grocery/models/fonepay_payment_request.dart';

PosSale fonepayFixtureSale(
        {String status = 'COMPLETED',
        String paymentStatus = 'PENDING',
        String paymentMethod = 'PENDING',
        double paidAmount = 13}) =>
    PosSale(
        id: 'fonepay-fixture-sale',
        receiptNumber: 'POS-TEST-QR',
        invoiceNumber: 'RPGS-2026-TEST-ONLY',
        customerName: 'Test customer',
        customerPhone: '9800000000',
        status: status,
        paymentMethod: paymentMethod,
        paymentStatus: paymentStatus,
        subtotal: 113.01,
        discount: 13,
        vatRate: 13,
        vatAmount: 13,
        total: 113.01,
        paidAmount: paidAmount,
        outstandingAmount: 113.01 - paidAmount,
        refundedAmount: 0,
        createdAt: DateTime.utc(2026, 11, 4),
        items: const [
          PosSaleItem(
              id: 'line',
              productId: 'fixture',
              productName: 'Test product',
              sku: 'TEST-ONLY',
              quantity: 1,
              weightGrams: null,
              unitPrice: 113.01,
              lineTotal: 113.01)
        ]);

Map<String, dynamic> fonepayFixtureJson(
        {String amount = '100.01',
        String state = 'READY',
        String environment = 'sandbox',
        DateTime? expiresAt,
        String saleId = 'fonepay-fixture-sale'}) =>
    {
      'id': 'test-request',
      'saleId': saleId,
      'invoiceNumber': 'RPGS-2026-TEST-ONLY',
      'reference': 'TEST-FONEPAY-NONPAYABLE',
      'currency': 'NPR',
      'amount': amount,
      'state': state,
      'environment': environment,
      'merchantName': 'TEST FIXTURE STORE',
      'qrPayload': 'TEST-ONLY-NONPAYABLE-FONEPAY-FIXTURE',
      'expiresAt':
          (expiresAt ?? DateTime.now().toUtc().add(const Duration(hours: 1)))
              .toIso8601String(),
    };
FonepayPaymentRequest fonepayFixtureRequest() =>
    FonepayPaymentRequest.fromJson(fonepayFixtureJson());
