import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:freshharvest_grocery/models/address.dart';
import 'package:freshharvest_grocery/models/order.dart';
import 'package:freshharvest_grocery/providers/order_provider.dart';
import 'package:freshharvest_grocery/screens/order/order_tracking_screen.dart';
import 'package:freshharvest_grocery/services/api_service.dart';

class _LiveOrderApi extends ApiService {
  String status = 'PLACED';
  int orderRequests = 0;

  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    orderRequests += 1;
    return {
      'order': {
        'id': 'order-1',
        'orderNumber': 'FH-1',
        'items': <dynamic>[],
        'address': <String, dynamic>{},
        'status': status,
        'paymentMethod': 'COD',
        'paymentStatus': 'PENDING',
        'subtotal': 100,
        'deliveryFee': 50,
        'discount': 0,
        'tip': 0,
        'total': 150,
        'createdAt': '2026-10-11T00:00:00.000Z',
      },
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tracking refreshes order milestones as admin status changes',
      (tester) async {
    final api = _LiveOrderApi();
    final orders = OrderProvider(apiService: api);
    addTearDown(orders.dispose);
    final order = Order(
      id: 'order-1',
      orderNumber: 'FH-1',
      items: const [],
      address: Address(
        id: 'address-1',
        title: 'Home',
        fullName: 'Customer',
        phone: '',
        city: 'Janakpur',
        street: 'Main Road',
      ),
      status: 'PLACED',
      paymentMethod: 'COD',
      paymentStatus: 'PENDING',
      subtotal: 100,
      total: 150,
      createdAt: '2026-10-11T00:00:00.000Z',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<OrderProvider>.value(
        value: orders,
        child: MaterialApp(home: OrderTrackingScreen(order: order)),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(api.orderRequests, greaterThan(0));
    final trackingScaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(trackingScaffold.backgroundColor, const Color(0xFFF6FAF7));
    expect(trackingScaffold.extendBody, isTrue);
    expect(trackingScaffold.extendBodyBehindAppBar, isTrue);
    expect(
      tester.widget<AppBar>(find.byType(AppBar)).forceMaterialTransparency,
      isTrue,
    );
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('Order received'), findsOneWidget);

    final requestsBeforeBackground = api.orderRequests;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 40));
    expect(api.orderRequests, requestsBeforeBackground);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(api.orderRequests, greaterThan(requestsBeforeBackground));

    api.status = 'CONFIRMED';
    await tester.pump(const Duration(seconds: 20));
    await tester.pump();
    expect(find.text('Order confirmed'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);

    api.status = 'PROCESSING';
    await tester.pump(const Duration(seconds: 20));
    await tester.pump();
    expect(find.text('Being prepared'), findsOneWidget);

    api.status = 'OUT_FOR_DELIVERY';
    await tester.pump(const Duration(seconds: 20));
    await tester.pump();
    expect(find.text('On the way to you'), findsOneWidget);
    expect(find.text('Waiting for rider location'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
