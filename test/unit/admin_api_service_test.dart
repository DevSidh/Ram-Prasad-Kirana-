import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:freshharvest_grocery/services/admin_api_service.dart';
import 'package:freshharvest_grocery/services/api_service.dart';

class _AdminApi extends ApiService {
  final List<(String, Map<String, dynamic>)> patches = [];
  final List<(String, Map<String, dynamic>)> puts = [];
  final List<(String, Map<String, dynamic>?)> deletes = [];
  String? requestedOrdersStatus;
  String? uploadedFileName;
  Uint8List? uploadedBytes;
  String? uploadedEndpoint;
  String? uploadedMethod;
  Map<String, String>? uploadedFields;
  Map<String, dynamic>? postedDeliveryPerson;
  Map<String, dynamic>? restockRequest;
  Map<String, String>? productQuery;
  Map<String, String>? wholesaleQuery;
  Map<String, String>? receiptHistoryQuery;
  Map<String, dynamic>? savedStoreSettings;
  Map<String, dynamic>? savedCoupon;
  Map<String, dynamic>? postedWholesaleItem;

  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    if (endpoint == '/admin/products') productQuery = queryParams;
    if (endpoint == '/admin/wholesale-items') {
      wholesaleQuery = queryParams;
      return {
        'wholesaleItems': [
          {
            'id': 'wholesale-1',
            'name': 'Bulk rice',
            'sku': 'WH-RICE',
            'slug': 'bulk-rice',
            'categoryId': 'pantry',
            'category': {'id': 'pantry', 'name': 'Pantry'},
            'price': 180,
            'stock': 60,
            'minimumQuantity': 5,
            'unitLabel': '1 kg',
            'isActive': true,
          },
        ],
        'pagination': {'page': 1, 'pageSize': 20, 'total': 1},
      };
    }
    if (endpoint == '/admin/coupons') {
      return {
        'coupons': [
          {
            'id': 'coupon-1',
            'code': 'SAVE10',
            'discountType': 'PERCENTAGE',
            'discountPercent': 10,
            'discountAmount': null,
            'minOrderAmount': 500,
            'maxDiscount': 150,
            'usageLimit': 20,
            'usedCount': 3,
            'isActive': true,
            'expiresAt': null,
          },
        ],
      };
    }
    if (endpoint == '/admin/store-settings') {
      return savedStoreSettings ??
          {
            'isOrderingEnabled': true,
            'isAcceptingOrders': true,
            'weeklyHours': List.generate(
              7,
              (index) => {
                'day': index + 1,
                'isOpen': true,
                'openTime': '09:00',
                'closeTime': '21:00',
              },
            ),
            'timeZone': 'Asia/Kathmandu',
            'statusMessage': 'The store is open and accepting orders.',
          };
    }
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
            'scheduledDeliveryAt': '2026-12-10T12:00:00.000Z',
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
    if (endpoint == '/admin/products' && queryParams?['stock'] == 'restock') {
      productQuery = queryParams;
      return {
        'products': [
          {
            'id': 'product-1',
            'name': 'Rice',
            'sku': 'rice-1kg',
            'slug': 'rice',
            'categoryId': 'pantry',
            'category': {'id': 'pantry', 'name': 'Pantry'},
            'price': 250,
            'stock': 2,
            'lowStockThreshold': 4,
            'isActive': true,
            'isFeatured': false,
          },
        ],
        'pagination': {'page': 1, 'pageSize': 100, 'total': 1},
      };
    }
    if (endpoint == '/admin/inventory/restock-history') {
      receiptHistoryQuery = queryParams;
      return {
        'receipts': [
          {
            'id': 'receipt-1',
            'quantity': 6,
            'balanceAfter': 8,
            'createdAt': '2026-10-19T10:00:00.000Z',
            'notes': 'Stock receipt added by store staff.',
            'product': {
              'id': 'product-1',
              'name': 'Rice',
              'sku': 'rice-1kg',
              'unitLabel': '1 kg',
            },
            'staff': {'id': 'admin-1', 'name': 'Store Admin'},
          },
        ],
        'pagination': {'page': 1, 'pageSize': 25, 'total': 1},
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
          'lowStockThreshold': 10,
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
    if (endpoint == '/admin/coupons/coupon-1/active') {
      return {
        'coupon': {
          ...?savedCoupon,
          ...body,
          'id': 'coupon-1',
          'code': 'SAVE10',
          'discountType': 'PERCENTAGE',
          'discountPercent': 10,
          'discountAmount': null,
          'minOrderAmount': 500,
          'maxDiscount': 150,
          'usageLimit': 20,
          'usedCount': 3,
          'expiresAt': null,
        },
      };
    }
  }

  @override
  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    puts.add((endpoint, body));
    savedStoreSettings = {
      ...body,
      'isAcceptingOrders': false,
      'timeZone': 'Asia/Kathmandu',
      'statusMessage': 'Online ordering is temporarily paused by the store.',
    };
    return savedStoreSettings;
  }

  @override
  Future<dynamic> delete(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    deletes.add((endpoint, body));
    return {'deletedItems': 7};
  }

  @override
  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    if (endpoint == '/admin/wholesale-items') {
      postedWholesaleItem = body;
      return {};
    }
    if (endpoint == '/admin/coupons') {
      savedCoupon = {
        ...body,
        'id': 'coupon-2',
        'isActive': true,
        'usedCount': 0,
      };
      return {'coupon': savedCoupon};
    }
    if (endpoint == '/admin/delivery/people') {
      postedDeliveryPerson = body;
    }
    if (endpoint == '/admin/products/product-1/restock') {
      restockRequest = body;
      return {
        'product': {
          'id': 'product-1',
          'name': 'Rice',
          'sku': 'rice-1kg',
          'slug': 'rice',
          'categoryId': 'pantry',
          'category': {'id': 'pantry', 'name': 'Pantry'},
          'price': 250,
          'stock': 8,
          'lowStockThreshold': 4,
          'isActive': true,
          'isFeatured': false,
        },
      };
    }
  }

  @override
  Future<dynamic> postFile(
    String endpoint, {
    required String fieldName,
    required Uint8List bytes,
    required String fileName,
    Map<String, String> fields = const {},
    String method = 'POST',
  }) async {
    uploadedEndpoint = endpoint;
    uploadedMethod = method;
    uploadedFields = fields;
    uploadedFileName = fileName;
    uploadedBytes = bytes;
    if (endpoint == '/admin/uploads/images') {
      return {'url': '/api/v1/images/asset-1'};
    }
    return {
      'product': {
        'imageUrl': '/api/v1/products/product-1/image',
      },
    };
  }
}

void main() {
  test('loads the restock queue and records received stock', () async {
    final api = _AdminApi();
    final adminApi = AdminApiService(api);

    final queue = await adminApi.getProducts(
      page: 1,
      pageSize: 100,
      stock: 'restock',
      sort: 'stock_asc',
    );
    final updated = await adminApi.restockProduct('product-1', 6);

    expect(api.productQuery?['stock'], 'restock');
    expect(api.productQuery?['sort'], 'stock_asc');
    expect(queue.products.single.lowStockThreshold, 4);
    expect(updated.stock, 8);
    expect(api.restockRequest, {'quantity': 6});
  });

  test('can filter the admin product catalog to vending drinks', () async {
    final api = _AdminApi();

    await AdminApiService(api).getProducts(page: 1, vendingDrink: true);

    expect(api.productQuery?['vendingDrink'], 'true');
  });

  test('loads the separate wholesale catalog', () async {
    final api = _AdminApi();

    final page = await AdminApiService(api).getWholesaleItems(page: 1);

    expect(api.wholesaleQuery, {'page': '1', 'pageSize': '20'});
    expect(page.items.single.name, 'Bulk rice');
    expect(page.items.single.stock, 60);
    expect(page.items.single.minimumQuantity, 5);
  });

  test('creates and updates independent wholesale items', () async {
    final api = _AdminApi();
    final adminApi = AdminApiService(api);
    final fields = {
      'name': 'Bulk rice',
      'price': 180,
      'stock': 60,
      'minimumQuantity': 5,
    };

    await adminApi.createWholesaleItem(fields);
    await adminApi.updateWholesaleItem('wholesale-1', {'stock': 75});
    await adminApi.setWholesaleItemActive('wholesale-1', false);

    expect(api.postedWholesaleItem, fields);
    expect(api.patches, hasLength(2));
    expect(api.patches[0].$1, '/admin/wholesale-items/wholesale-1');
    expect(api.patches[0].$2, containsPair('stock', 75));
    expect(api.patches[1].$1, '/admin/wholesale-items/wholesale-1');
    expect(api.patches[1].$2, containsPair('isActive', false));
  });

  test('loads staff-linked stock receipt history', () async {
    final api = _AdminApi();
    final adminApi = AdminApiService(api);

    final history = await adminApi.getRestockHistory(page: 1);

    expect(api.receiptHistoryQuery, {'page': '1', 'pageSize': '25'});
    expect(history.receipts.single.productName, 'Rice');
    expect(history.receipts.single.quantity, 6);
    expect(history.receipts.single.staffName, 'Store Admin');
    expect(history.receipts.single.createdAt.toUtc(),
        DateTime.utc(2026, 10, 19, 10));
  });

  test('admin can create, list, and pause promotional coupons', () async {
    final api = _AdminApi();
    final adminApi = AdminApiService(api);

    final current = await adminApi.getCoupons();
    final created = await adminApi.createCoupon({
      'code': 'FRESH20',
      'discountType': 'PERCENTAGE',
      'discountPercent': 20,
      'discountAmount': null,
      'minOrderAmount': 750,
      'maxDiscount': 200,
      'usageLimit': 30,
      'expiresAt': null,
    });
    final paused = await adminApi.setCouponActive('coupon-1', false);

    expect(current.single.code, 'SAVE10');
    expect(current.single.usedCount, 3);
    expect(created.code, 'FRESH20');
    expect(created.discountPercent, 20);
    expect(paused.isActive, isFalse);
    expect(api.patches.single.$1, '/admin/coupons/coupon-1/active');
    expect(api.patches.single.$2, {'isActive': false});
  });

  test('loads and saves store ordering controls and weekly hours', () async {
    final api = _AdminApi();
    final adminApi = AdminApiService(api);

    final current = await adminApi.getStoreSettings();
    final hours = current.weeklyHours
        .map((day) => day.copyWith(isOpen: day.day != 7))
        .toList();
    final saved = await adminApi.updateStoreSettings(
      isOrderingEnabled: false,
      weeklyHours: hours,
    );

    expect(current.weeklyHours, hasLength(7));
    expect(api.puts, hasLength(1));
    expect(api.puts.single.$1, '/admin/store-settings');
    expect(api.puts.single.$2['isOrderingEnabled'], isFalse);
    expect(api.puts.single.$2['weeklyHours'], hasLength(7));
    expect(saved.isOrderingEnabled, isFalse);
    expect(saved.weeklyHours.last.isOpen, isFalse);
  });

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
    final savedImageUrl = await adminApi.updateProductImage(
      'product-1',
      Uint8List.fromList([1, 2, 3]),
      'rice.png',
    );

    expect(api.patches, hasLength(2));
    expect(api.patches[0].$1, '/admin/products/product-1');
    expect(api.patches[0].$2, {'sku': 'pantry-masoor-dal-1kg'});
    expect(api.patches[1].$1, '/admin/products/product-2');
    expect(api.patches[1].$2, {'isFeatured': true});
    expect(api.uploadedEndpoint, '/admin/products/product-1');
    expect(api.uploadedMethod, 'PATCH');
    expect(api.uploadedFileName, 'rice.png');
    expect(api.uploadedFields, {
      'product': '{"imageUrl":null}',
    });
    expect(
      savedImageUrl,
      Uri.parse(api.baseUrl)
          .resolve('/api/v1/products/product-1/image')
          .toString(),
    );
  });

  test('loads admin order details and filters by status', () async {
    final api = _AdminApi();
    final result = await AdminApiService(api).getOrders(status: 'PLACED');

    expect(api.requestedOrdersStatus, 'PLACED');
    expect(result.pagination.total, 1);
    expect(result.orders.single.orderNumber, 'FH-1001');
    expect(result.orders.single.shippingAddress, 'Main Road, Janakpur');
    expect(result.orders.single.items.single.total, 500);
    expect(
      result.orders.single.scheduledDeliveryAt,
      DateTime.parse('2026-12-10T12:00:00.000Z'),
    );
  });

  test('clears order item details only after sending the typed confirmation',
      () async {
    final api = _AdminApi();

    final deleted = await AdminApiService(api).clearAllOrderItemDetails(
      confirmation: 'CONFIRM DELETE',
    );

    expect(deleted, 7);
    expect(api.deletes, hasLength(1));
    expect(api.deletes.single.$1, '/admin/orders/items');
    expect(api.deletes.single.$2, {'confirmation': 'CONFIRM DELETE'});
  });

  test('sets and clears the scheduled delivery time for an order', () async {
    final api = _AdminApi();
    final adminApi = AdminApiService(api);
    final scheduledAt = DateTime.utc(2026, 12, 10, 12);

    await adminApi.updateOrderDeliveryTime('order-1', scheduledAt);
    await adminApi.updateOrderDeliveryTime('order-1', null);

    expect(api.patches, hasLength(2));
    expect(api.patches[0].$1, '/admin/orders/order-1/delivery-time');
    expect(api.patches[0].$2, {
      'scheduledDeliveryAt': '2026-12-10T12:00:00.000Z',
    });
    expect(api.patches[1].$2, {'scheduledDeliveryAt': null});
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
      Uri.parse(api.baseUrl).resolve('/api/v1/images/asset-1').toString(),
    );
  });

  test('uploads a shared image for category artwork', () async {
    final api = _AdminApi();
    final bytes = Uint8List.fromList([137, 80, 78, 71]);

    final url = await AdminApiService(api).uploadImage(
      bytes,
      'aisle.png',
    );

    expect(api.uploadedEndpoint, '/admin/uploads/images');
    expect(api.uploadedFileName, 'aisle.png');
    expect(api.uploadedBytes, bytes);
    expect(url,
        Uri.parse(api.baseUrl).resolve('/api/v1/images/asset-1').toString());
  });
}
