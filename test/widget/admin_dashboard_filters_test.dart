import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/screens/admin/admin_dashboard_screen.dart';
import 'package:freshharvest_grocery/services/api_service.dart';
import 'package:freshharvest_grocery/services/offline_pos_store.dart';

class _DashboardApi extends ApiService {
  String? day;
  bool fail = false;
  @override
  Future<dynamic> get(String endpoint,
      {Map<String, String>? queryParams}) async {
    day = queryParams?['day'];
    if (fail) throw StateError('Offline fixture');
    return {
      'sales': {'total': day == null ? 1000 : 100},
      'recentOrders': []
    };
  }
}

class _DashboardStore extends OfflinePosStore {
  String? day;
  Map<String, dynamic>? snapshot;
  @override
  Future<double> readOfflineSalesTotal() async {
    day = null;
    return 200;
  }

  @override
  Future<double> readOfflineSalesTotalForDay(String value) async {
    day = value;
    return 20;
  }

  @override
  Future<Map<String, dynamic>?> readDashboardSnapshot() async => snapshot;
  @override
  Future<void> saveDashboardSnapshot(Map<String, dynamic> value) async {
    snapshot = value;
  }
}

void main() {
  testWidgets(
      'dashboard date filters online and local sales and can be cleared',
      (tester) async {
    final api = _DashboardApi();
    final store = _DashboardStore();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AdminDashboardScreen(api: api, offlineStore: store))));
    await tester.pumpAndSettle();
    expect(api.day, isNull);
    await tester.tap(find.text('All dates'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(api.day, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    expect(store.day, api.day);
    expect(store.snapshot?['filterDay'], api.day);
    await tester.tap(find.text('Clear date filter'));
    await tester.pumpAndSettle();
    expect(api.day, isNull);
    expect(store.day, isNull);
    expect(tester.takeException(), isNull);
  });
}
