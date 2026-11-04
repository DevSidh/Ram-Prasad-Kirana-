import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:freshharvest_grocery/models/fonepay_payment_request.dart';
import 'package:freshharvest_grocery/services/api_service.dart';
import 'package:freshharvest_grocery/services/fonepay_api_service.dart';
import 'package:freshharvest_grocery/widgets/fonepay_payment_dialog.dart';
import '../fixtures/fonepay_fixture.dart';
import 'package:freshharvest_grocery/models/pos_models.dart';

class _FixtureApi extends FonepayApiService {
  _FixtureApi({this.enabled = true}) : super(ApiService());
  final bool enabled;
  int creates = 0;
  int resumes = 0;
  @override
  Future<Map<String, dynamic>> configuration() async => {
        'enabled': enabled,
        'message': 'Official merchant profile required',
      };
  @override
  Future<FonepayPaymentRequest> create(String saleId) async {
    creates++;
    return fonepayFixtureRequest();
  }

  @override
  Future<FonepayPaymentRequest> get(String id) async {
    resumes++;
    return fonepayFixtureRequest();
  }

  @override
  Future<FonepayPaymentRequest> verify(String id) async =>
      FonepayPaymentRequest.fromJson(
          fonepayFixtureJson(state: 'TEST_VERIFIED'));
}

class _CheckoutApi extends _FixtureApi {
  int finalizations = 0, claims = 0, verifications = 0;
  bool failFinalization = false;
  Completer<FonepayPaymentRequest>? verificationGate;
  @override
  Future<Map<String, dynamic>> configuration() async =>
      {'enabled': true, 'pollIntervalSeconds': 5};
  @override
  Future<FonepayPaymentRequest> create(String saleId) async {
    creates++;
    return FonepayPaymentRequest.fromJson(
        fonepayFixtureJson(environment: 'live'));
  }

  @override
  Future<FonepayPaymentRequest> verify(String id) async {
    verifications++;
    if (verificationGate != null) return await verificationGate!.future;
    return FonepayPaymentRequest.fromJson(
        fonepayFixtureJson(environment: 'live', state: 'VERIFIED'));
  }

  @override
  Future<PosSale> finalize(String id) async {
    finalizations++;
    if (failFinalization) throw StateError('TEST inventory unavailable');
    return fonepayFixtureSale(
        paymentMethod: 'FONEPAY',
        paymentStatus: 'COMPLETED',
        paidAmount: 113.01);
  }

  @override
  Future<bool> claimAutoPrint(String id) async {
    claims++;
    return claims == 1;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> open(WidgetTester tester, _FixtureApi api,
      {void Function(bool?)? onClose,
      bool checkout = false,
      void Function(Object?)? onResult}) async {
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return Scaffold(
          body: TextButton(
              onPressed: () async {
                final result = await showDialog<Object>(
                    context: context,
                    builder: (_) => FonepayPaymentDialog(
                        sale: fonepayFixtureSale(
                            status: checkout ? 'CHECKOUT' : 'COMPLETED'),
                        api: api,
                        finalizeCheckout: checkout));
                if (!checkout) onClose?.call(result as bool?);
                onResult?.call(result);
              },
              child: const Text('Open fixture')));
    })));
    await tester.tap(find.text('Open fixture'));
    await tester.pumpAndSettle();
  }

  testWidgets('missing merchant profile never generates a QR', (tester) async {
    final api = _FixtureApi(enabled: false);
    await open(tester, api);
    expect(find.textContaining('Official merchant profile required'),
        findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    expect(api.creates, 0);
    await tester.tap(find.text('Retry connection'));
    await tester.pumpAndSettle();
    expect(api.creates, 0);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });

  testWidgets('sandbox verification cannot report a real bill as paid',
      (tester) async {
    final api = _FixtureApi();
    bool? paid;
    await open(tester, api, onClose: (value) => paid = value);
    expect(find.textContaining('SANDBOX TEST'), findsOneWidget);
    expect(find.text('Payable: NPR 100.01'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    await tester.ensureVisible(find.text('Verify with Fonepay'));
    await tester.tap(find.text('Verify with Fonepay'));
    await tester.pumpAndSettle();
    expect(find.text('Status: TEST_VERIFIED'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(paid, isFalse);
  });

  testWidgets('reopening resumes the saved reference without creating another',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'fonepay_request_fonepay-fixture-sale': 'test-request',
    });
    final api = _FixtureApi();
    await open(tester, api);
    expect(api.resumes, 1);
    expect(api.creates, 0);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'verified checkout shows success and finalizes once before print claim',
      (tester) async {
    final api = _CheckoutApi();
    Object? result;
    await open(tester, api,
        checkout: true, onResult: (value) => result = value);
    expect(find.text('Scan to pay with Fonepay'), findsOneWidget);
    expect(find.text('Waiting for payment…'), findsOneWidget);
    await tester.ensureVisible(find.text('Verify with Fonepay'));
    await tester.tap(find.text('Verify with Fonepay'));
    await tester.pump();
    expect(find.text('Payment successful'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(result, isA<FonepayCheckoutCompletion>());
    expect((result as FonepayCheckoutCompletion).autoPrintAllowed, isTrue);
    expect(api.finalizations, 1);
    expect(api.claims, 1);
    expect(api.creates, 1);
  });

  testWidgets(
      'verified payment survives failed finalization and retries without another charge',
      (tester) async {
    final api = _CheckoutApi()..failFinalization = true;
    await open(tester, api, checkout: true);
    await tester.ensureVisible(find.text('Verify with Fonepay'));
    await tester.tap(find.text('Verify with Fonepay'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.textContaining('Payment is retained.'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    api.failFinalization = false;
    await tester.ensureVisible(find.text('Retry bill finalization'));
    await tester.tap(find.text('Retry bill finalization'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(api.finalizations, 2);
    expect(api.verifications, 1);
    expect(api.creates, 1);
  });

  testWidgets(
      'cross closes waiting and ignores an in-flight result while retaining reference',
      (tester) async {
    final api = _CheckoutApi()
      ..verificationGate = Completer<FonepayPaymentRequest>();
    Object? result = 'not-closed';
    await open(tester, api,
        checkout: true, onResult: (value) => result = value);
    await tester.ensureVisible(find.text('Verify with Fonepay'));
    await tester.tap(find.text('Verify with Fonepay'));
    await tester.pump();
    await tester.tap(find.byTooltip('Close payment'));
    await tester.pumpAndSettle();
    api.verificationGate!.complete(FonepayPaymentRequest.fromJson(
        fonepayFixtureJson(environment: 'live', state: 'VERIFIED')));
    await tester.pump(const Duration(seconds: 10));
    expect(result, isNull);
    expect(api.finalizations, 0);
    expect(api.verifications, 1);
    expect(
        (await SharedPreferences.getInstance())
            .getString('fonepay_request_fonepay-fixture-sale'),
        'test-request');
  });
}
