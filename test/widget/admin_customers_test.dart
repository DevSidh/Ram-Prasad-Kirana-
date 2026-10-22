import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:freshharvest_grocery/screens/admin/admin_customers_screen.dart';
import 'package:freshharvest_grocery/services/api_service.dart';

class _CustomersApi extends ApiService {
  Map<String, dynamic>? deleteBody;
  bool removed = false;

  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    return {
      'customers': removed
          ? []
          : [
              {
                'id': 'customer-1',
                'name': 'Asha Sharma',
                'email': 'asha@example.com',
                'phone': '9800000000',
                'isActive': true,
                'createdAt': '2026-01-20T00:00:00.000Z',
                'orderCount': 2,
                'orderValue': 850,
                'addresses': [
                  {
                    'label': 'Home',
                    'addressLine1': 'Main Road',
                    'city': 'Janakpur',
                  },
                ],
                'recentOrders': [
                  {
                    'orderNumber': 'FH-1001',
                    'status': 'DELIVERED',
                    'total': 550,
                  },
                ],
              },
            ],
      'pagination': {'page': 1, 'pageSize': 20, 'total': 1},
    };
  }

  @override
  Future<dynamic> delete(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    expect(endpoint, '/admin/customers/customer-1');
    deleteBody = body;
    removed = true;
  }
}

void main() {
  testWidgets('admin can review customer addresses and recent orders',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminCustomersScreen(api: _CustomersApi())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Asha Sharma'), findsOneWidget);
    await tester.tap(find.text('Asha Sharma'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Main Road'), findsOneWidget);
    expect(find.textContaining('FH-1001'), findsOneWidget);
    expect(find.textContaining('850'), findsOneWidget);
    expect(find.textContaining('Customer since'), findsOneWidget);
  });

  testWidgets('customer removal requires REMOVE USER and preserves history',
      (tester) async {
    final api = _CustomersApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminCustomersScreen(api: api)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Asha Sharma'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove customer'));
    await tester.pumpAndSettle();
    expect(find.textContaining('item lines, payments'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('remove-customer-confirmation')),
      'REMOVE USER',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove customer').last);
    await tester.pumpAndSettle();

    expect(api.deleteBody, {'confirmation': 'REMOVE USER'});
    expect(find.text('No customers found'), findsOneWidget);
  });
}
