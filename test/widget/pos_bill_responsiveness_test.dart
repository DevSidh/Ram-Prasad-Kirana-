import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:freshharvest_grocery/core/billing_strings.dart';
import 'package:freshharvest_grocery/theme/app_theme.dart' as billing;
import 'package:freshharvest_grocery/theme/app_colors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/models/pos_models.dart';
import 'package:freshharvest_grocery/screens/admin/admin_billing_screen.dart';
import 'package:freshharvest_grocery/services/admin_api_service.dart';
import 'package:freshharvest_grocery/services/api_service.dart';
import 'package:freshharvest_grocery/services/offline_pos_store.dart';
import 'package:freshharvest_grocery/services/local_billing_store.dart';
import 'package:freshharvest_grocery/services/fonepay_api_service.dart';
import 'package:freshharvest_grocery/services/billing_customer_service.dart';

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
  Future<Map<String, dynamic>> getRoomInventory(
          {List<String>? productIds}) async =>
      {
        'rooms': [],
        'stocks': [],
        'totals': [
          {'productId': 'tea', 'total': 100, 'available': 100}
        ],
        'capturedAt': '2026-11-06T00:00:00Z',
      };
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
      Map<String, double>? unitPrices,
      List<Map<String, dynamic>>? roomPicks,
      Map<String, dynamic>? manualVerification}) {
    saves++;
    expectSync(expectedTotal, 10);
    expectSync(unitPrices, {'tea': 10});
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
  _MemoryStore(Directory root)
      : super(
            billingStore: LocalBillingStore(rootPath: root.path),
            useLocalStock: false);
  @override
  Future<List<PosSale>> readOfflineSales() async => [
        PosSale.fromJson({
          'id': 'fixture-local-customer',
          'receiptNumber': 'FIXTURE',
          'createdAt': '2026-11-04T00:00:00Z',
          'items': [],
          'customerName': 'SS',
          'customerPhone': '9801234567',
        })
      ];
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
  final previewKey = GlobalKey();
  setUp(() async {
    root = await Directory.systemTemp.createTemp('faststore-ui-test-');
    store = _MemoryStore(root);
    await store.saveCatalog([_tea]);
    api = _Api();
  });
  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    AppColors.clearWindowsAdminTheme();
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
  Future<void> start(WidgetTester tester, {PosProduct? scanned}) async {
    AppColors.windowsAdminDarkTheme = false;
    tester.view.reset();
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(RepaintBoundary(
        key: previewKey,
        child: MaterialApp(
            theme: billing.AppTheme.data,
            home: Scaffold(
                body: PosBillDialog(
              api: api,
              offlineStore: store,
              scannedProduct: scanned,
              loadLocalCustomers: () => BillingCustomerService.readLocal(store,
                  loadSavedCustomers: () async => []),
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
            )))));
    await settleIO(tester);
  }

  Finder field(String label) => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == label);

  testWidgets(
      'Nepali desktop checkout keeps customer, cart, search and payment controls readable',
      (tester) async {
    await tester.runAsync(() async {
      await BillingStrings.load();
      final font = FontLoader('FastStoreDevanagari')
        ..addFont(rootBundle.load('assets/fonts/NotoSansDevanagari.ttf'));
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    });
    BillingStrings.languageCode = 'ne';
    addTearDown(() => BillingStrings.languageCode = 'en');
    await start(tester);
    expect(find.text('Fixture tea'), findsWidgets);
    expect(find.text('बिल बनाउनुहोस् (F8)'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final image = await (previewKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary)
          .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('tmp/bilingual-preview')
        ..createSync(recursive: true);
      await File('${dir.path}/checkout-ne.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('typing a saved offline customer name also fills its phone',
      (tester) async {
    await start(tester);
    final name = find.byWidgetPredicate((widget) =>
        widget is TextField &&
        widget.decoration?.hintText == 'Temporary customer name');
    final phone = find.byWidgetPredicate((widget) =>
        widget is TextField &&
        widget.decoration?.hintText == 'Temporary customer phone');
    await tester.enterText(name, 'SS');
    await tester.pump(const Duration(milliseconds: 450));
    await settleIO(tester);
    expect(tester.widget<TextField>(phone).controller!.text, '9801234567');
    expect(find.textContaining('Saved on this computer'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('a wholesale sack uses pack quantity instead of loose grams',
      (tester) async {
    await start(tester,
        scanned: const PosProduct(
            id: 'wholesale-sack',
            name: 'Fixture wholesale sack',
            sku: 'SACK',
            barcode: null,
            price: 1000,
            unitLabel: '25 kg',
            available: 8));
    expect(find.textContaining('Fixture wholesale sack'), findsWidgets);
    expect(find.text('Weight in grams'), findsNothing);
    final quantity = field('Quantity').last;
    expect(tester.widget<TextField>(quantity).controller!.text, '1');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

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
    await settleIO(tester);
    await tester.tap(find.text('Use these rooms'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(api.saves, 1);
    api.saveGate!.completeError(
        const ApiResponseException('Fixture conflict', statusCode: 409));
    await tester.pump();
    expect(find.textContaining('Fixture conflict'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('eSewa QR Pay blocks repeated clicks while processing',
      (tester) async {
    await start(tester);
    await tester.tap(find.byWidgetPredicate((w) =>
        w is DropdownButtonFormField<String> &&
        w.decoration.labelText == 'Payment method'));
    await tester.pumpAndSettle();
    expect(find.textContaining('UPI'), findsNothing);
    await tester.tap(find.text('eSewa / QR').last);
    await tester.pumpAndSettle();
    final button =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Pay'));
    button.onPressed!();
    button.onPressed!();
    await tester.pump();
    expect(api.payment.checks, 0);
    expect(api.saves, 0);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Pay'))
            .onPressed,
        isNull);
    await settleIO(tester);
    await tester.tap(find.text('Use these rooms'));
    await settleIO(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Waiting for cashier to confirm payment received.'),
        findsOneWidget);
    await tester.tap(find.text('Cancel / Back'));
    await tester.pumpAndSettle();
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
