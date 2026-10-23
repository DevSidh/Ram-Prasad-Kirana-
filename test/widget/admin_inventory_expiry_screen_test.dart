import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/screens/admin/admin_inventory_expiry_screen.dart';
import 'package:freshharvest_grocery/services/api_service.dart';

class _ExpiryApi extends ApiService {
  Map<String, String>? expiryQuery;

  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    if (endpoint == '/admin/categories') {
      return {
        'categories': [
          {
            'id': 'beverages',
            'name': 'Beverages',
            'slug': 'beverages',
            'isActive': true,
          },
        ],
      };
    }
    if (endpoint == '/admin/inventory/expiry') {
      expiryQuery = queryParams;
      return {
        'batches': [
          {
            'id': 'batch-1',
            'productId': 'product-1',
            'productName': 'Rice',
            'sku': 'RICE-1KG',
            'barcode': '12345678',
            'categoryName': 'Beverages',
            'unitLabel': '1 kg',
            'lotNumber': 'LOT-A',
            'manufacturedAt': '2026-10-01T00:00:00.000Z',
            'expiresAt': '2026-11-01T00:00:00.000Z',
            'receivedQuantity': 5,
            'remainingQuantity': 3,
            'daysRemaining': 9,
            'expiryStatus': 'expiring',
            'datesVerified': true,
          },
        ],
        'summary': {
          'warningDays': 30,
          'expiringSoonBatches': 1,
          'expiringSoonProducts': 1,
          'expiredBatches': 0,
          'expiredProducts': 0,
          'expiringTodayBatches': 0,
          'expiringTodayProducts': 0,
        },
        'pagination': {'page': 1, 'pageSize': 25, 'total': 1},
      };
    }
    throw StateError('Unexpected GET $endpoint');
  }
}

void main() {
  testWidgets('expiry screen filters batches and opens batch details',
      (tester) async {
    final api = _ExpiryApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminInventoryExpiryScreen(api: api)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Near to Expiry'), findsOneWidget);
    expect(find.text('Rice'), findsOneWidget);
    expect(api.expiryQuery?['days'], '30');

    await tester.tap(find.text('All categories'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beverages').last);
    await tester.pumpAndSettle();
    expect(api.expiryQuery?['categoryId'], 'beverages');

    await tester.tap(find.text('Rice'));
    await tester.pumpAndSettle();
    expect(find.text('Batch ID: batch-1'), findsOneWidget);
    expect(find.text('Lot number: LOT-A'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
