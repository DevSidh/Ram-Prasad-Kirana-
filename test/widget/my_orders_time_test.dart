import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:freshharvest_grocery/providers/order_provider.dart';
import 'package:freshharvest_grocery/screens/order/my_orders_screen.dart';
import 'package:freshharvest_grocery/services/api_service.dart';

class _OrdersApi extends ApiService {
  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    if (endpoint != '/orders') {
      throw StateError('Unexpected order endpoint: $endpoint');
    }
    return {
      'data': [
        {
          'id': 'order-1',
          'orderNumber': 'FH-1001',
          'items': [],
          'address': {
            'id': 'address-1',
            'fullName': 'Asha',
            'phone': '9800000000',
            'street': 'Main Road',
            'city': 'Janakpur',
          },
          'status': 'PLACED',
          'paymentMethod': 'COD',
          'paymentStatus': 'PENDING',
          'subtotal': 400,
          'total': 450,
          'createdAt': '2026-10-10T08:00:00.000Z',
        },
      ],
    };
  }
}

void main() {
  testWidgets('customer order history displays the placement timestamp',
      (tester) async {
    final orders = OrderProvider(apiService: _OrdersApi());
    addTearDown(orders.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<OrderProvider>.value(
        value: orders,
        child: const MaterialApp(home: MyOrdersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Order #FH-1001'), findsOneWidget);
    expect(find.textContaining('Ordered '), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
