import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/services/api_service.dart';
import 'package:freshharvest_grocery/services/offline_pos_store.dart';
import 'package:freshharvest_grocery/services/inventory_changes.dart';
import 'package:freshharvest_grocery/widgets/stock_summary_panel.dart';

class _Catalog extends ApiService {
  int rice = 1250, water = 3, requests = 0;
  bool failing = false;
  @override
  Future<dynamic> get(String endpoint,
      {Map<String, String>? queryParams}) async {
    if (endpoint != '/admin/products') {
      throw StateError('Unexpected endpoint: $endpoint');
    }
    requests++;
    if (failing) throw const ApiNetworkException();
    final products = [
      {
        'id': 'fixture-rice',
        'name': 'Rice',
        'price': 200,
        'weightStockKg': rice / 1000,
        'stock': rice / 1000,
        'unitLabel': '1 kg',
        'isActive': true
      },
      {
        'id': 'fixture-water',
        'name': 'Water',
        'price': 20,
        'stock': water,
        'unitLabel': '1 L',
        'isActive': true
      },
      {
        'id': 'fixture-paused',
        'name': 'Paused',
        'price': 20,
        'stock': 50,
        'unitLabel': '1 pc',
        'isActive': false
      },
    ];
    final page = int.parse(queryParams!['page']!);
    return {
      'products':
          page == 1 ? products.take(2).toList() : products.skip(2).toList(),
      'pagination': {'page': page, 'pageSize': 2, 'total': 3}
    };
  }
}

void main() {
  testWidgets(
      'summary loads every page and refreshes after stock changes without mixing units',
      (tester) async {
    final api = _Catalog();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: StockSummaryPanel(
                    api: api,
                    offlineStore:
                        const OfflinePosStore(useLocalStock: false))))));
    await tester.pumpAndSettle();
    expect(api.requests, 2);
    expect(find.text('Total products: 3'), findsOneWidget);
    expect(find.text('Active products: 2'), findsOneWidget);
    expect(find.text('Kilograms: 1.25'), findsOneWidget);
    expect(find.text('Packs (1 L): 3'), findsOneWidget);
    expect(find.text('Liters in sealed packs: 3'), findsOneWidget);
    api.rice = 1500;
    api.water = 1;
    InventoryChanges.notify();
    InventoryChanges.notify();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(api.requests, 4);
    expect(find.text('Kilograms: 1.5'), findsOneWidget);
    expect(find.text('Packs (1 L): 1'), findsOneWidget);
    api.failing = true;
    InventoryChanges.notify();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Stock totals could not be refreshed. Try again.'),
        findsOneWidget);
    expect(find.text('Kilograms: 1.5'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    InventoryChanges.notify();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
