import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:freshharvest_grocery/screens/admin/admin_orders_screen.dart';
import 'package:freshharvest_grocery/services/admin_order_notification_service.dart';
import 'package:freshharvest_grocery/services/api_service.dart';

class _OrderNotificationService extends AdminOrderNotificationService {
  bool permissionRequested = false;
  final List<String> newOrders = [];

  @override
  Future<bool> requestPermission() async {
    permissionRequested = true;
    return true;
  }

  @override
  Future<bool> showNewOrder(String orderNumber) async {
    newOrders.add(orderNumber);
    return true;
  }
}

class _OrdersApi extends ApiService {
  final List<(String, Map<String, dynamic>)> patches = [];
  bool newOrderAdded = false;

  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    if (endpoint == '/admin/delivery/people') {
      return {'deliveryPeople': []};
    }
    if (endpoint == '/admin/orders/alerts') {
      return {
        'orders': [
          {'id': 'order-1', 'orderNumber': 'FH-1001'},
          if (newOrderAdded)
            {'id': 'order-2', 'orderNumber': 'FH-1002'},
        ],
      };
    }
    final orders = <Map<String, dynamic>>[
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
    ];
    if (newOrderAdded) {
      orders.insert(0, {
        'id': 'order-2',
        'orderNumber': 'FH-1002',
        'status': 'PLACED',
        'paymentMethod': 'COD',
        'paymentStatus': 'PENDING',
        'subtotal': 300,
        'deliveryFee': 50,
        'discount': 0,
        'total': 350,
        'customer': {'name': 'Bina', 'email': '', 'phone': '9810000000'},
        'shipping': {'name': 'Bina', 'phone': '9810000000'},
        'items': [],
        'statusHistory': [],
        'createdAt': '2026-10-09T10:05:00.000Z',
      });
    }
    return {
      'orders': orders,
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

    await tester.drag(find.byType(ListView).first, const Offset(0, -240));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update order status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmed').last);
    await tester.pumpAndSettle();

    expect(api.patches, hasLength(1));
    expect(api.patches.single.$1, '/admin/orders/order-1/status');
    expect(api.patches.single.$2, {'status': 'CONFIRMED'});
  });

  testWidgets('admin can cancel an order without deleting order history',
      (tester) async {
    final api = _OrdersApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminOrdersScreen(api: api)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('clear-all-order-item-details')), findsNothing);
    expect(find.textContaining('Cancelling preserves order'), findsOneWidget);
    await tester.tap(find.text('FH-1001'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -240));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update order status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelled').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel order'));
    await tester.pumpAndSettle();

    expect(api.patches, hasLength(1));
    expect(api.patches.single.$1, '/admin/orders/order-1/status');
    expect(api.patches.single.$2, {'status': 'CANCELLED'});
  });

  testWidgets('active admin sees new orders but is not alerted for old ones',
      (tester) async {
    final api = _OrdersApi();
    final notifications = _OrderNotificationService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminOrdersScreen(
            api: api,
            isActive: true,
            notificationService: notifications,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(notifications.permissionRequested, isTrue);
    expect(find.text('New order received: FH-1001'), findsNothing);

    api.newOrderAdded = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 60));
    expect(notifications.newOrders, isEmpty);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('New order received: FH-1002'), findsOneWidget);
    expect(notifications.newOrders, ['FH-1002']);
  });
}
