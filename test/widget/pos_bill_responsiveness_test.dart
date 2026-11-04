import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/models/pos_models.dart';
import 'package:freshharvest_grocery/screens/admin/admin_billing_screen.dart';
import 'package:freshharvest_grocery/services/admin_api_service.dart';
import 'package:freshharvest_grocery/services/api_service.dart';
import 'package:freshharvest_grocery/services/offline_pos_store.dart';
import 'package:freshharvest_grocery/services/fonepay_api_service.dart';

class _FonepayTestApi extends FonepayApiService {
  _FonepayTestApi() : super(ApiService());
  int checks = 0;
  Completer<Map<String, dynamic>>? gate;
  @override
  Future<Map<String, dynamic>> configuration() {
    checks++;
    return (gate ??= Completer<Map<String, dynamic>>()).future;
  }
}

class _Api extends AdminApiService {
  _Api() : super(ApiService(baseUrl: 'http://127.0.0.1:1'));
  int searches = 0;
  int saves = 0;
  final payment = _FonepayTestApi();
  @override
  FonepayApiService get fonepay => payment;
  Completer<PosSale>? saveGate;
  final queries = <String, Completer<List<PosProduct>>>{};
  @override
  Future<List<PosProduct>> searchPosProducts(String query) async {
    searches++;
    if (queries[query] != null) return queries[query]!.future;
    return [_tea];
  }

  @override
  Future<PosSale> createPosSale(
      {required String idempotencyKey,
      required List<Map<String, dynamic>> items,
      required double discount,
      double vatRate = 0,
      required String paymentMethod,
      double? paidAmount,
      String? paidNowMethod,
      String? customerName,
      String? customerPhone,
      String? customerId,
      String? heldSaleId,
      double? expectedTotal,
      Map<String, double>? unitPrices}) {
    saves++;
    expect(expectedTotal, 10);
    expect(unitPrices, {'tea': 10});
    return (saveGate ??= Completer<PosSale>()).future;
  }
}

const _tea = PosProduct(
    id: 'tea',
    name: 'Fixture tea',
    sku: 'TEA',
    barcode: '8901234567890',
    price: 10,
    unitLabel: 'pcs',
    available: 100);

// UI assertions use deterministic storage; real file durability/cache/locking
// are covered by local_billing_store_test and pos_performance_correctness_test.
class _MemoryStore extends OfflinePosStore {
  @override
  Future<void> saveCatalog(List<PosProduct> products) async {}
  @override
  Future<void> mergeCatalog(List<PosProduct> products) async {}
  @override
  Future<List<PosProduct>> searchCatalog(String query) async => query.isEmpty ||
          'fixture tea tea 8901234567890'.contains(query.toLowerCase())
      ? [_tea]
      : [];
  @override
  Future<List<PosProduct>> projectLocalStock(List<PosProduct> products,
          {bool freshStock = false}) async =>
      products;
  @override
  Future<List<Map<String, dynamic>>> readPendingProducts() async => [];
}

void main() {
  late Directory root;
  late OfflinePosStore store;
  late _Api api;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('faststore-ui-test-');
    store = _MemoryStore();
    await store.saveCatalog([_tea]);
    api = _Api();
  });
  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    // Disposing a widget cannot cancel an already admitted asynchronous file
    // replacement. Let Windows close those fixture handles before cleanup.
    for (var attempt = 0;; attempt++) {
      try {
        await root.delete(recursive: true);
        break;
      } on FileSystemException catch (error) {
        if (error.osError?.errorCode != 32 || attempt >= 9) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  });
  Future<void> start(WidgetTester tester) async {
    tester.view.reset();
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: PosBillDialog(
      api: api,
      offlineStore: store,
      refreshCatalogOnOpen: false,
      operatorId: 'fixture',
      allowOfflineSync: false,
      onScan: () async => null,
      onNewBill: () {},
      heldSale: PosHeldSale(
          id: 'held',
          customerName: null,
          customerPhone: null,
          createdAt: DateTime.utc(2026),
          items: const [
            {
              'productId': 'tea',
              'productName': 'Fixture tea',
              'sku': 'TEA',
              'price': 10,
              'unitLabel': 'pcs',
              'quantity': 1
            },
          ]),
    ))));
    await settleIO(tester);
  }

  Finder field(String label) => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == label);

  testWidgets('quantity updates row, item count and total without losing focus',
      (tester) async {
    await start(tester);
    await tester.enterText(field('Qty'), '4');
    await tester.pump();
    expect(find.text('4 items'), findsOneWidget);
    expect(find.textContaining('40.00'), findsWidgets);
    await tester.tap(find.byTooltip('Increase quantity'));
    await tester.pump();
    expect(tester.widget<TextField>(field('Qty')).controller!.text, '5');
    await tester.tap(find.byTooltip('Remove item'));
    await tester.pump();
    expect(find.text('No items added yet'), findsOneWidget);
    expect(find.text('0 items'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
      'a cached scan opens quantity without a server round trip; burst is preserved',
      (tester) async {
    await start(tester);
    final searches = api.searches;
    final search = tester.widget<TextField>(find.byWidgetPredicate((w) =>
        w is TextField &&
        w.decoration?.labelText?.startsWith('Scan barcode') == true));
    search.onSubmitted!('8901234567890');
    search.onSubmitted!('8901234567890');
    for (var i = 0; i < 2; i++) {
      await settleIO(tester);
      expect(find.text('Add to bill'), findsOneWidget);
      await tester.tap(find.text('Add to bill'));
      await tester.pump(const Duration(milliseconds: 250));
    }
    await settleIO(tester);
    expect(api.searches, searches);
    expect(tester.widget<TextField>(field('Qty')).controller!.text, '3');
    expect(find.text('3 items'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('repeated completion clicks submit one immutable quote',
      (tester) async {
    await start(tester);
    final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Create bill (F8)'));
    button.onPressed!();
    button.onPressed!();
    await tester.pump();
    expect(api.saves, 1);
    api.saveGate!.completeError(
        const ApiResponseException('Fixture conflict', statusCode: 409));
    await tester.pump();
    expect(find.textContaining('Fixture conflict'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
      'Fonepay replaces UPI and Pay blocks repeated clicks while processing',
      (tester) async {
    await start(tester);
    await tester.tap(find.byWidgetPredicate((w) =>
        w is DropdownButtonFormField<String> &&
        w.decoration.labelText == 'Payment method'));
    await tester.pumpAndSettle();
    expect(find.textContaining('UPI'), findsNothing);
    await tester.tap(find.text('Fonepay').last);
    await tester.pumpAndSettle();
    final button =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Pay'));
    button.onPressed!();
    button.onPressed!();
    await tester.pump();
    expect(api.payment.checks, 1);
    expect(api.saves, 0);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Pay'))
            .onPressed,
        isNull);
    api.payment.gate!.complete(
        {'enabled': false, 'message': 'Official merchant profile required'});
    await tester.pumpAndSettle();
    expect(find.textContaining('Official merchant profile required'),
        findsOneWidget);
    expect(api.saves, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('a stale response cannot win during the next search debounce',
      (tester) async {
    await start(tester);
    final old = api.queries['old'] = Completer<List<PosProduct>>();
    final next = api.queries['new'] = Completer<List<PosProduct>>();
    final search = find.byWidgetPredicate((w) =>
        w is TextField &&
        w.decoration?.labelText?.startsWith('Scan barcode') == true);
    await tester.enterText(search, 'old');
    await tester.pump(const Duration(milliseconds: 260));
    await settleIO(tester);
    await tester.enterText(search, 'new');
    old.complete([
      const PosProduct(
          id: 'stale',
          name: 'Stale result',
          sku: 'OLD',
          barcode: null,
          price: 99,
          unitLabel: 'pcs',
          available: 1)
    ]);
    // Complete the old request before the new request's debounce finishes.
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Stale result'), findsNothing);
    await tester.pump(const Duration(milliseconds: 260));
    next.complete([_tea]);
    await settleIO(tester);
    expect(find.text('Stale result'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}

Future<void> settleIO(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}
