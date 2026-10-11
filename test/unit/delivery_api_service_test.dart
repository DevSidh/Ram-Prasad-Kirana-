import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/services/api_service.dart';
import 'package:freshharvest_grocery/services/delivery_api_service.dart';

class _DeliveryApi extends ApiService {
  final patches = <(String, Map<String, dynamic>)>[];

  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    if (endpoint == '/delivery/profile') {
      return {
        'id': 'rider-1',
        'name': 'Ram',
        'email': 'ram@example.test',
        'phone': '9800000000',
        'isAvailable': true,
      };
    }
    return {
      'assignments': [
        {
          'id': 'delivery-1',
          'status': 'ASSIGNED',
          'assignedAt': '2026-10-09T08:00:00.000Z',
          'cashCollected': 0,
          'order': {
            'id': 'order-1',
            'orderNumber': 'FH-1001',
            'status': 'PROCESSING',
            'paymentMethod': 'COD',
            'paymentStatus': 'PENDING',
            'total': 1250,
            'cashDue': 1250,
            'customerName': 'Asha',
            'customerPhone': '9800000000',
            'address': 'Main Road, Janakpur',
            'latitude': 26.728,
            'longitude': 85.925,
            'items': [
              {'name': 'Rice', 'quantity': 2},
            ],
          },
        },
      ],
      'summary': {
        'assigned': 1,
        'inProgress': 0,
        'deliveredToday': 0,
        'cashToCollect': 1250,
      },
    };
  }

  @override
  Future<dynamic> patch(String endpoint, Map<String, dynamic> body) async {
    patches.add((endpoint, body));
  }
}

void main() {
  test('loads assigned order details and customer cash due', () async {
    final api = _DeliveryApi();
    final service = DeliveryApiService(api);

    final profile = await service.getProfile();
    final page = await service.getAssignments();

    expect(profile.name, 'Ram');
    expect(profile.isAvailable, isTrue);
    expect(page.summary.assigned, 1);
    expect(page.summary.cashToCollect, 1250);
    expect(page.assignments.single.order.orderNumber, 'FH-1001');
    expect(page.assignments.single.order.customerName, 'Asha');
    expect(page.assignments.single.order.customerPhone, '9800000000');
    expect(page.assignments.single.order.address, 'Main Road, Janakpur');
    expect(page.assignments.single.order.cashDue, 1250);
    expect(page.assignments.single.order.items.single.quantity, 2);
    expect(page.assignments.single.order.items.single.name, 'Rice');
    expect(page.assignments.single.order.latitude, 26.728);
    expect(page.assignments.single.order.longitude, 85.925);
  });

  test('sends controlled workflow and customer cash confirmation fields',
      () async {
    final api = _DeliveryApi();
    final service = DeliveryApiService(api);

    await service.setAvailability(false);
    await service.updateAssignment('delivery-1', 'ACCEPTED');
    await service.updateAssignment(
      'delivery-1',
      'DELIVERED',
      recipientName: 'Asha',
      cashCollected: 1250,
    );

    expect(
      api.patches.map((patch) => patch.$1),
      [
        '/delivery/availability',
        '/delivery/assignments/delivery-1',
        '/delivery/assignments/delivery-1',
      ],
    );
    expect(
      api.patches.map((patch) => patch.$2),
      [
        {'isAvailable': false},
        {'status': 'ACCEPTED'},
        {
          'status': 'DELIVERED',
          'recipientName': 'Asha',
          'cashCollected': 1250.0,
        },
      ],
    );
  });
}
