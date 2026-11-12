import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/screens/admin/admin_customers_screen.dart';
import 'package:freshharvest_grocery/screens/admin/admin_dashboard_screen.dart';
import 'package:freshharvest_grocery/screens/admin/admin_supplier_bills_screen.dart';
import 'package:freshharvest_grocery/screens/admin/admin_products_screen.dart';
import 'package:freshharvest_grocery/screens/admin/admin_wholesale_screen.dart';
import 'package:freshharvest_grocery/screens/admin/admin_coupons_screen.dart';
import 'package:freshharvest_grocery/screens/admin/customer_menu_settings_screen.dart';
import 'package:freshharvest_grocery/services/api_service.dart';
import 'package:freshharvest_grocery/services/offline_pos_store.dart';

class _QueuedApi extends ApiService {
  final requests = <Completer<dynamic>>[];
  int writes = 0;
  @override
  Future<dynamic> get(String endpoint, {Map<String, String>? queryParams}) {
    final response = Completer<dynamic>();
    requests.add(response);
    return response.future;
  }

  @override
  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    writes++;
    return body;
  }
}

Map<String, dynamic> _customers(String name) => {
      'customers': [
        {
          'id': name,
          'name': name,
          'email': '$name@example.test',
          'phone': '9800000000'
        }
      ],
      'pagination': {'page': 1, 'pageSize': 20, 'total': 1}
    };

class _BrokenStorage extends OfflinePosStore {
  const _BrokenStorage();
  @override
  Future<double> readOfflineSalesTotal() async =>
      throw const FormatException('bad ledger');
  @override
  Future<Map<String, dynamic>?> readDashboardSnapshot() async =>
      throw const FormatException('bad snapshot');
  @override
  Future<void> saveDashboardSnapshot(Map<String, dynamic> snapshot) async {}
}

class _DeferredCache extends OfflinePosStore {
  final categories = Completer<List<Map<String, dynamic>>>();
  @override
  Future<List<Map<String, dynamic>>> readPendingProducts() async => [];
  @override
  Future<List<Map<String, dynamic>>> readCategories() => categories.future;
}

class _UnavailableApi extends ApiService {
  @override
  Future<dynamic> get(String endpoint,
          {Map<String, String>? queryParams}) async =>
      throw const ApiNetworkException();
}

class _CouponStatusApi extends ApiService {
  _CouponStatusApi({this.active = true});
  bool active;
  Map<String, dynamic> get coupon => {
        'id': 'featured',
        'code': 'TEST50',
        'discountType': 'FIXED',
        'discountAmount': 50,
        'minOrderAmount': 100,
        'isActive': active,
        'isBannerFeatured': true
      };
  @override
  Future<dynamic> get(String endpoint,
          {Map<String, String>? queryParams}) async =>
      {
        'coupons': [coupon]
      };
  @override
  Future<dynamic> patch(String endpoint, Map<String, dynamic> body) async {
    active = body['isActive'] as bool;
    return {'coupon': coupon};
  }
}

void main() {
  testWidgets('pausing a featured coupon keeps the banner selector valid',
      (tester) async {
    tester.view.physicalSize = const Size(1366, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _CouponStatusApi();
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: AdminCouponsScreen(api: api))));
    await tester.pumpAndSettle();
    final toggle = find.byType(Switch);
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(api.active, isFalse);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('banner-none')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AdminCouponsScreen(api: _CouponStatusApi(active: false)))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull,
        reason: 'Existing inactive featured coupons must also load safely');
  });
  for (final wholesale in [false, true]) {
    testWidgets(
        'closing ${wholesale ? "wholesale" : "products"} while cache recovery waits is safe',
        (tester) async {
      final store = _DeferredCache();
      final api = _UnavailableApi();
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: wholesale
                  ? AdminWholesaleScreen(api: api, offlineStore: store)
                  : AdminProductsScreen(api: api, offlineStore: store))));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      store.categories.complete([]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('customer search ignores stale successes and failures',
      (tester) async {
    final api = _QueuedApi();
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: AdminCustomersScreen(api: api))));
    await tester.enterText(find.byType(TextField), 'latest');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(api.requests, hasLength(2));
    api.requests[1].complete(_customers('Latest customer'));
    await tester.pumpAndSettle();
    api.requests[0].completeError(Exception('Stale failure'));
    await tester.pumpAndSettle();
    expect(find.text('Latest customer'), findsOneWidget);
    expect(find.textContaining('Stale failure'), findsNothing);

    await tester.enterText(find.byType(TextField), 'older');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.enterText(find.byType(TextField), 'newer');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    api.requests[3].complete(_customers('Newest customer'));
    await tester.pumpAndSettle();
    api.requests[2].complete(_customers('Old customer'));
    await tester.pumpAndSettle();
    expect(find.text('Newest customer'), findsOneWidget);
    expect(find.text('Old customer'), findsNothing);
  });

  testWidgets(
      'failed settings load cannot overwrite saved settings with defaults',
      (tester) async {
    final api = _QueuedApi();
    await tester
        .pumpWidget(MaterialApp(home: CustomerMenuSettingsScreen(api: api)));
    api.requests.single.completeError(Exception('Unavailable'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
            .onPressed,
        isNull);
    expect(
        tester
            .widget<SwitchListTile>(find.byType(SwitchListTile).first)
            .onChanged,
        isNull);
    expect(api.writes, 0);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    api.requests.last.complete({
      'customerMenuFeatures': {'orders': false}
    });
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
            .onPressed,
        isNotNull);
    expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile).first).value,
        false);
  });

  testWidgets('supplier search does not display an older failed request',
      (tester) async {
    final api = _QueuedApi();
    await tester
        .pumpWidget(MaterialApp(home: AdminSupplierBillsScreen(api: api)));
    await tester.enterText(find.byType(TextField), 'latest');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    api.requests[1].complete({
      'bills': [],
      'pagination': {'page': 1, 'pageSize': 20, 'total': 0}
    });
    await tester.pumpAndSettle();
    api.requests[0].completeError(Exception('Old supplier failure'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Old supplier failure'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('damaged local records do not block the live dashboard',
      (tester) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _QueuedApi();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AdminDashboardScreen(
                api: api, offlineStore: const _BrokenStorage()))));
    api.requests.single.complete({});
    await tester.pumpAndSettle();
    // Malformed local bill records are ignored individually. The live
    // dashboard remains available without presenting a false storage failure.
    expect(find.textContaining('Local bill totals could not be loaded'),
        findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
