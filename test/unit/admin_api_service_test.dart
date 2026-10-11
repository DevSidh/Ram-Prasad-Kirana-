import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:freshharvest_grocery/services/admin_api_service.dart';
import 'package:freshharvest_grocery/services/api_service.dart';

class _AdminApi extends ApiService {
  final List<(String, Map<String, dynamic>)> patches = [];
  String? requestedOrdersStatus;
  String? uploadedFileName;
  Uint8List? uploadedBytes;
  Map<String, dynamic>? postedDeliveryPerson;

  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    if (endpoint == '/admin/orders') {
      requestedOrdersStatus = queryParams?['status'];
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
            'customer': {'name': 'Asha', 'phone': '9800000000'},
            'shipping': {'address': 'Main Road', 'city': 'Janakpur'},
            'items': [
              {
                'name': 'Rice',
                'sku': 'rice-1kg',
                'quantity': 2,
                'price': 250,
                'total': 500,
              },
            ],
          },
        ],
        'pagination': {'page': 1, 'pageSize': 20, 'total': 1},
      };
    }
    if (endpoint == '/admin/delivery/people') {
      return {
        'deliveryPeople': [
          {
            'id': 'rider-1',
            'name': 'Ram',
            'email': 'ram@example.test',
            'phone': '9800000000',
            'isActive': true,
            'isAvailable': true,
            'activeDeliveries': 1,
          },
        ],
      };
    }
    if (endpoint == '/admin/delivery/cash-pending') {
      return {
        'deliveries': [
          {
            'id': 'delivery-1',
            'orderNumber': 'FH-1001',
            'deliveryPersonName': 'Ram',
            'cashCollected': 1250,
            'deliveredAt': '2026-10-12T10:00:00.000Z',
          },
        ],
      };
    }
    if (endpoint == '/admin/customers') {
      return {
        'customers': [
          {
            'id': 'customer-1',
            'name': 'Asha',
            'email': 'asha@example.com',
            'phone': '9800000000',
            'isActive': true,
            'orderCount': 2,
            'orderValue': 850,
            'addresses': [
              {'addressLine1': 'Main Road', 'city': 'Janakpur'},
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
    final page = int.parse(queryParams?['page'] ?? '1');
    return {
      'products': [
        {
          'id': 'product-$page',
          'name': 'Product $page',
          'sku': 'sku-$page',
          'slug': 'product-$page',
          'categoryId': 'pantry',
          'category': {'id': 'pantry', 'name': 'Pantry'},
          'price': 100,
          'stock': 4,
          'isActive': true,
          'isFeatured': page == 1,
        },
      ],
      'pagination': {'page': page, 'pageSize': 1, 'total': 2},
    };
  }

  @override
  Future<dynamic> patch(String endpoint, Map<String, dynamic> body) async {
    patches.add((endpoint, body));
  }

  @override
  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    if (endpoint == '/admin/delivery/people') {
      postedDeliveryPerson = body;
    }
  }

  @override
  Future<dynamic> postFile(
    String endpoint, {
    required String fieldName,
    required Uint8List bytes,
    required String fileName,
  }) async {
    uploadedFileName = fileName;
    uploadedBytes = bytes;
    return {'url': '/uploads/products/$fileName'};
  }
}

void main() {
  test('loads every product page for whole-catalog admin tools', () async {
    final api = _AdminApi();

    final products = await AdminApiService(api).getAllProducts();

    expect(products.map((product) => product.id), ['product-1', 'product-2']);
    expect(products.first.isFeatured, isTrue);
    expect(products.last.isFeatured, isFalse);
  });

  test('SKU and carousel updates patch only the intended product fields',
      () async {
    final api = _AdminApi();
    final adminApi = AdminApiService(api);

    await adminApi.updateProductSku('product-1', 'pantry-masoor-dal-1kg');
    await adminApi.updateProductFeatured('product-2', true);
    await adminApi.updateProductImage(
      'product-1',
      'https://store.example/uploads/rice.png',
    );

    expect(api.patches, hasLength(3));
    expect(api.patches[0].$1, '/admin/products/product-1');
    expect(api.patches[0].$2, {'sku': 'pantry-masoor-dal-1kg'});
    expect(api.patches[1].$1, '/admin/products/product-2');
    expect(api.patches[1].$2, {'isFeatured': true});
    expect(api.patches[2].$1, '/admin/products/product-1');
    expect(api.patches[2].$2, {
      'imageUrl': 'https://store.example/uploads/rice.png',
    });
  });

  test('loads admin order details and filters by status', () async {
    final api = _AdminApi();
    final result = await AdminApiService(api).getOrders(status: 'PLACED');

    expect(api.requestedOrdersStatus, 'PLACED');
    expect(result.pagination.total, 1);
    expect(result.orders.single.orderNumber, 'FH-1001');
    expect(result.orders.single.shippingAddress, 'Main Road, Janakpur');
    expect(result.orders.single.items.single.total, 500);
  });

  test('loads searchable customer records and order history', () async {
    final api = _AdminApi();
    final result = await AdminApiService(api).getCustomers(search: 'FH-1001');

    expect(result.pagination.total, 1);
    expect(result.customers.single.name, 'Asha');
    expect(result.customers.single.orderCount, 2);
    expect(
        result.customers.single.recentOrders.single['orderNumber'], 'FH-1001');
  });

  test('lists delivery staff and creates a delivery-only staff account',
      () async {
    final api = _AdminApi();
    final adminApi = AdminApiService(api);

    final people = await adminApi.getDeliveryPeople();
    await adminApi.createDeliveryPerson(
      name: ' Ram Prasad ',
      email: ' ram@example.test ',
      phone: ' 9800000000 ',
      password: 'long-enough-secret',
    );
    await adminApi.assignDeliveryPerson('order-1', 'rider-1');
    await adminApi.setDeliveryPersonActive('rider-1', false);

    expect(people.single.name, 'Ram');
    expect(people.single.activeDeliveries, 1);
    expect(api.postedDeliveryPerson, {
      'name': 'Ram Prasad',
      'email': 'ram@example.test',
      'phone': '9800000000',
      'password': 'long-enough-secret',
    });
    expect(
      api.patches.map((patch) => patch.$1),
      [
        '/admin/orders/order-1/delivery-person',
        '/admin/delivery/people/rider-1/active',
      ],
    );
    expect(
      api.patches.map((patch) => patch.$2),
      [
        {'deliveryPersonId': 'rider-1'},
        {'isActive': false},
      ],
    );
  });

  test('loads pending customer COD and confirms receipt once at the store',
      () async {
    final api = _AdminApi();
    final adminApi = AdminApiService(api);

    final deliveries = await adminApi.getPendingDeliveryCash();
    await adminApi.confirmDeliveryCashHandover(deliveries.single.id);

    expect(deliveries.single.orderNumber, 'FH-1001');
    expect(deliveries.single.deliveryPersonName, 'Ram');
    expect(deliveries.single.cashCollected, 1250);
    expect(api.patches, hasLength(1));
    expect(
      api.patches.single.$1,
      '/admin/delivery/delivery-1/cash-handover',
    );
    expect(api.patches.single.$2, isEmpty);
  });

  test('uploads product image bytes and returns its public API URL', () async {
    final api = _AdminApi();
    final bytes = Uint8List.fromList([137, 80, 78, 71]);

    final url = await AdminApiService(api).uploadProductImage(
      bytes,
      'product.png',
    );

    expect(api.uploadedFileName, 'product.png');
    expect(api.uploadedBytes, bytes);
    expect(
      url,
      Uri.parse(api.baseUrl)
          .resolve('/uploads/products/product.png')
          .toString(),
    );
  });
}
