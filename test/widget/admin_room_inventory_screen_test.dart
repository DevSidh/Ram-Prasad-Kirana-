import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/core/billing_strings.dart';
import 'package:freshharvest_grocery/screens/admin/admin_room_inventory_screen.dart';
import 'package:freshharvest_grocery/services/api_service.dart';
import 'package:freshharvest_grocery/services/offline_pos_store.dart';
import 'package:freshharvest_grocery/models/pos_models.dart';
import 'package:freshharvest_grocery/theme/app_theme.dart';
import 'package:freshharvest_grocery/widgets/billing_localized_widgets.dart';

class _MemoryStore extends OfflinePosStore {
  const _MemoryStore() : super(useLocalStock: false);
  @override
  Future<List<Map<String, dynamic>>> readPendingProducts() async => [];
  @override
  Future<void> mergeCatalog(List<PosProduct> products) async {}
  @override
  Future<void> saveCatalog(List<PosProduct> products) async {}
}

class _Api extends ApiService {
  int moves = 0, adds = 0;
  final rooms = <Map<String, dynamic>>[
    {'id': 'a', 'name': 'Main room', 'number': '01', 'active': true}
  ];
  int assigned = 6;
  @override
  Future<dynamic> get(String endpoint,
      {Map<String, String>? queryParams}) async {
    if (endpoint == '/admin/billing/rooms') {
      return {
        'rooms': rooms,
        'products': [
          {
            'id': 'tea',
            'name': 'Fixture tea',
            'sku': 'TEA',
            'barcode': null,
            'price': 10,
            'unitLabel': '1 pc',
            'available': 10
          }
        ],
        'stocks': [
          {'productId': 'tea', 'roomId': 'a', 'quantity': assigned}
        ],
        'totals': [
          {'productId': 'tea', 'total': 10, 'available': 10}
        ],
        'capturedAt': '2026-11-06T00:00:00Z'
      };
    }
    if (endpoint == '/admin/products') {
      return {
        'products': [
          {
            'id': 'tea',
            'name': 'Fixture tea',
            'sku': 'TEA',
            'price': 10,
            'stock': 10,
            'isActive': true,
            'unitLabel': '1 pc'
          }
        ],
        'pagination': {'page': 1, 'pageSize': 100, 'total': 1}
      };
    }
    if (endpoint == '/admin/wholesale-items') {
      return {
        'wholesaleItems': [],
        'pagination': {'page': 1, 'pageSize': 100, 'total': 0}
      };
    }
    throw StateError('Unexpected fixture read $endpoint');
  }

  @override
  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    if (endpoint == '/admin/billing/rooms/transfers') {
      assigned += body['quantity'] as int;
      moves++;
      return {'success': true};
    }
    if (endpoint == '/admin/billing/rooms') {
      rooms.add({'id': 'b', ...body, 'active': true});
      adds++;
      return {};
    }
    throw StateError('Unexpected fixture write $endpoint');
  }
}

void main() {
  testWidgets(
      'billing staff can inspect inventory without admin catalog reads or write controls',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.data,
        home: AdminRoomInventoryScreen(
            api: _Api(), offlineStore: const _MemoryStore(), readOnly: true)));
    await tester.pumpAndSettle();
    expect(find.text('Fixture tea'), findsOneWidget);
    expect(find.text('Manage rooms'), findsNothing);
    expect(find.text('Place / move stock'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final lang in ['en', 'ne']) {
    for (final width in [360.0, 1366.0]) {
      testWidgets('Inventory layout, search and room filter $lang $width',
          (tester) async {
        await tester.runAsync(() => BillingStrings.load());
        BillingStrings.languageCode = lang;
        addTearDown(() => BillingStrings.languageCode = 'en');
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.data,
            home: AdminRoomInventoryScreen(
                api: _Api(), offlineStore: const _MemoryStore())));
        await tester.pumpAndSettle();
        expect(find.text('Fixture tea'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.enterText(find.byType(BillingTextFormField), 'not found');
        await tester.pump();
        expect(find.text('Fixture tea'), findsNothing);
        await tester.enterText(find.byType(BillingTextFormField), 'TEA');
        await tester.pump();
        expect(find.text('Fixture tea'), findsOneWidget);
        await tester
            .ensureVisible(find.widgetWithText(ChoiceChip, '01 · Main room'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ChoiceChip, '01 · Main room'));
        await tester.pump();
        expect(find.text('Fixture tea'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
  testWidgets(
      'placing stock changes room count and creating a room saves name and number',
      (tester) async {
    final api = _Api();
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.data,
        home: AdminRoomInventoryScreen(
            api: api, offlineStore: const _MemoryStore())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Place / move stock'));
    await tester.pumpAndSettle();
    final quantity = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Quantity');
    await tester.enterText(quantity, '2');
    await tester.tap(find.widgetWithText(FilledButton, 'Move stock'));
    await tester.pumpAndSettle();
    expect(api.moves, 1);
    expect(api.assigned, 8);
    await tester.tap(find.text('Manage rooms'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add room'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.labelText == 'Room name'),
        'Back room');
    await tester.enterText(
        find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.labelText == 'Room number'),
        '02');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(api.adds, 1);
    expect(find.text('02 · Back room'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
