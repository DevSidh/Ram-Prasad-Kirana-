import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/models/fonepay_payment_request.dart';
import 'package:freshharvest_grocery/services/pos_receipt_service.dart';
import 'package:freshharvest_grocery/services/fonepay_api_service.dart';
import 'package:freshharvest_grocery/services/api_service.dart';
import '../fixtures/fonepay_fixture.dart';

class _Api extends ApiService {
  final posted = <Map<String, dynamic>>[];
  @override
  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    posted.add(body);
    return {'request': fonepayFixtureJson()};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('canonical NPR balance uses saved total minus received payment', () {
    final request = fonepayFixtureRequest();
    expect(request.matchesPayableBill(fonepayFixtureSale()), isTrue);
    expect(request.amount, '100.01');
    expect(request.isTest, isTrue);
    expect(request.paid, isFalse);
  });
  test(
      'wrong amount, bill, expired or terminal QR cannot be displayed or printed',
      () async {
    for (final json in [
      fonepayFixtureJson(amount: '100.02'),
      fonepayFixtureJson(saleId: 'another-bill'),
      fonepayFixtureJson(expiresAt: DateTime.utc(2020)),
      fonepayFixtureJson(state: 'CANCELLED'),
      fonepayFixtureJson(state: 'PAID'),
      fonepayFixtureJson(state: 'STALE')
    ]) {
      final request = FonepayPaymentRequest.fromJson(json);
      expect(request.matchesPayableBill(fonepayFixtureSale()), isFalse);
      await expectLater(
          PosReceiptService.createInvoicePdf(fonepayFixtureSale(),
              fonepay: request),
          throwsStateError);
    }
  });
  test('currency and decimal response validation rejects unsafe provider data',
      () {
    for (final json in [
      {...fonepayFixtureJson(), 'currency': 'USD'},
      fonepayFixtureJson(amount: '1e3'),
      fonepayFixtureJson(amount: '100.001'),
      fonepayFixtureJson(environment: 'mock')
    ]) {
      expect(() => FonepayPaymentRequest.fromJson(json), throwsFormatException);
    }
    final testPaid =
        FonepayPaymentRequest.fromJson(fonepayFixtureJson(state: 'PAID'));
    expect(testPaid.paid, isFalse);
  });
  test('A4, 58mm and 80mm PDFs include renderable fixture QR without overflow',
      () async {
    final sale = fonepayFixtureSale();
    final request = fonepayFixtureRequest();
    final documents = [
      await PosReceiptService.createInvoicePdf(sale, fonepay: request),
      await PosReceiptService.createPdf(sale,
          paperWidthMm: 58, fonepay: request),
      await PosReceiptService.createPdf(sale,
          paperWidthMm: 80, fonepay: request)
    ];
    for (final bytes in documents) {
      expect(utf8.decode(bytes.sublist(0, 4)), '%PDF');
      expect(bytes.length, greaterThan(1000));
    }
  });
  test('client sends no amount or success evidence to create/verify/cancel',
      () async {
    final api = _Api();
    final service = FonepayApiService(api);
    await service.create('saved-bill');
    await service.verify('request');
    await service.cancel('request');
    expect(api.posted, [{}, {}, {}]);
  });
}
