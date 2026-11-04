import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/screens/admin/admin_restock_screen.dart';
import 'package:freshharvest_grocery/services/api_service.dart';

class _StockApi extends ApiService {
  Map<String, String>? lastQuery;
  @override
  Future<dynamic> get(String endpoint,
      {Map<String, String>? queryParams}) async {
    if (endpoint != '/admin/inventory/restock-history') {
      throw StateError(endpoint);
    }
    lastQuery = queryParams;
    return {
      'receipts': [
        {
          'id': 'movement-test',
          'quantity': 2,
          'balanceAfter': 5,
          'type':
              queryParams?['movementType'] == 'ALL' ? 'PURCHASED' : 'RESTOCKED',
          'referenceId': 'SALE-TEST',
          'notes': 'Test reason',
          'createdAt': '2020-01-02T06:00:00.000Z',
          'staff': {'name': 'Cashier test'},
          'product': {
            'id': 'tea',
            'name': 'Tea',
            'sku': 'TEST-TEA',
            'unitLabel': '1 kg'
          },
        }
      ],
      'pagination': {'page': 1, 'pageSize': 25, 'total': 1},
    };
  }
}

void main() {
  testWidgets('existing receipt history extends to searchable stock movements',
      (tester) async {
    final api = _StockApi();
    await tester
        .pumpWidget(MaterialApp(home: AdminRestockHistoryScreen(api: api)));
    await tester.pumpAndSettle();
    expect(api.lastQuery?['movementType'], 'RESTOCKED');
    expect(find.text('Recorded by Cashier test'), findsOneWidget);
    expect(find.text('Reference: SALE-TEST'), findsOneWidget);
    await tester.tap(find.text('Stock receipts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All movements').last);
    await tester.pumpAndSettle();
    expect(api.lastQuery?['movementType'], 'ALL');
    expect(find.text('PURCHASED: 2 kg'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Tea');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(api.lastQuery?['search'], 'Tea');
    expect(tester.takeException(), isNull);
  });
}
