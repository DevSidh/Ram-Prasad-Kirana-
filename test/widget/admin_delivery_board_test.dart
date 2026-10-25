import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:freshharvest_grocery/screens/admin/admin_delivery_people_screen.dart';
import 'package:freshharvest_grocery/services/api_service.dart';

class _DeliveryBoardApi extends ApiService {
  final patches = <(String, Map<String, dynamic>)>[];
  Map<String, dynamic> delivery = {};

  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    if (endpoint == '/admin/delivery/people') {
      return {
        'deliveryPeople': [
          {
            'id': 'rider-1',
            'name': 'Nabin',
            'email': 'nabin@example.test',
            'phone': '9800000000',
            'isActive': true,
            'isAvailable': true,
            'activeDeliveries': 0,
          },
        ],
      };
    }
    if (endpoint == '/admin/delivery/cash-pending') {
      return {'deliveries': []};
    }
    return {
      'orders': [
        {
          'id': 'order-1',
          'orderNumber': 'FH-501',
          'status': 'PROCESSING',
          'paymentMethod': 'COD',
          'paymentStatus': 'PENDING',
          'subtotal': 400,
          'deliveryFee': 50,
          'discount': 0,
          'total': 450,
          'customer': {
            'id': 'customer-1',
            'name': 'Asha',
            'email': 'asha@example.test',
            'phone': '9811111111',
          },
          'shipping': {
            'name': 'Asha',
            'phone': '9811111111',
            'address': 'Main Road',
            'city': 'Janakpur',
            'instructions': 'Call at the gate.',
          },
          'items': [
            {
              'id': 'item-1',
              'name': 'Rice',
              'sku': 'rice-1kg',
              'quantity': 2,
              'price': 200,
              'total': 400,
            },
          ],
          'delivery': delivery.isEmpty ? null : delivery,
          'statusHistory': [],
          'createdAt': '2026-10-10T08:00:00.000Z',
        },
      ],
      'pagination': {'page': 1, 'pageSize': 100, 'total': 1},
    };
  }

  @override
  Future<dynamic> patch(String endpoint, Map<String, dynamic> body) async {
    patches.add((endpoint, body));
    delivery = {
      'id': 'delivery-1',
      'status': 'ASSIGNED',
      'deliveryPersonId': body['deliveryPersonId'],
      'deliveryPerson': {
        'id': 'rider-1',
        'name': 'Nabin',
        'phone': '9800000000',
        'isActive': true,
      },
      'statusHistory': [],
    };
  }
}

void main() {
  testWidgets('admin assigns a prepared order from the delivery board',
      (tester) async {
    final api = _DeliveryBoardApi();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminDeliveryPeopleScreen(api: api)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('FH-501'), findsOneWidget);
    expect(find.textContaining('ORDERED '), findsOneWidget);
    await tester.tap(find.textContaining('FH-501'));
    await tester.pumpAndSettle();
    expect(find.text('Call at the gate.'), findsOneWidget);
    expect(find.textContaining('9811111111'), findsOneWidget);

    await tester.ensureVisible(find.text('Assign rider'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assign rider'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Nabin').last);
    await tester.pumpAndSettle();

    expect(api.patches, hasLength(1));
    expect(api.patches.single.$1, '/admin/orders/order-1/delivery-person');
    expect(
      api.patches.single.$2,
      {'deliveryPersonId': 'rider-1'},
    );
  });
}
