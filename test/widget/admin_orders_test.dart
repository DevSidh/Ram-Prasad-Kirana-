import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:freshharvest_grocery/screens/admin/admin_orders_screen.dart';
import 'package:freshharvest_grocery/services/api_service.dart';

class _OrdersApi extends ApiService {
  final List<(String, Map<String, dynamic>)> patches = [];

  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    if (endpoint == '/admin/delivery/people') {
      return {'deliveryPeople': []};
    }
    return {
      'orders': [
        {
          'id': 'order-1',
          'orderNumber': 'FH-1001',
          'status': 'PLACED',
          'paymentMethod': 'COD',
          'paymentStatus': 'PENDING',
          'subtotal': 500,
          'deliveryFee': 50,
          'discount': 0,
          'total': 550,
          'customer': {
            'id': 'customer-1',
            'name': 'Asha',
            'email': 'asha@example.com',
            'phone': '9800000000',
          },
          'shipping': {
            'name': 'Asha',
            'phone': '9800000000',
            'address': 'Main Road',
            'city': 'Janakpur',
          },
          'items': [
            {
              'id': 'item-1',
              'name': 'Rice',
              'sku': 'rice-1kg',
              'quantity': 2,
              'price': 250,
              'total': 500,
            },
          ],
          'statusHistory': [],
          'createdAt': '2026-10-09T10:00:00.000Z',
        },
      ],
      'pagination': {'page': 1, 'pageSize': 20, 'total': 1},
    };
  }

  @override
  Future<dynamic> patch(String endpoint, Map<String, dynamic> body) async {
    patches.add((endpoint, body));
  }
}

void main() {
  testWidgets('admin can review an order and advance it to confirmed',
      (tester) async {
    final api = _OrdersApi();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminOrdersScreen(api: api)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FH-1001'), findsOneWidget);
    await tester.tap(find.text('FH-1001'));
    await tester.pumpAndSettle();
    expect(find.text('Rice × 2'), findsOneWidget);
    expect(find.textContaining('Main Road, Janakpur'), findsOneWidget);

    await tester.tap(find.text('Update order status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmed').last);
    await tester.pumpAndSettle();

    expect(api.patches, hasLength(1));
    expect(api.patches.single.$1, '/admin/orders/order-1/status');
    expect(api.patches.single.$2, {'status': 'CONFIRMED'});
  });
}
