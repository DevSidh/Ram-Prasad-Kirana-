import 'dart:convert';
import 'dart:typed_data';

import '../models/admin_models.dart';
import '../models/store_availability.dart';
import 'api_service.dart';

class AdminApiService {
  final ApiService _api;

  AdminApiService(this._api);

  Future<AdminBroadcastResult> broadcastNotification({
    required String title,
    required String body,
    String? couponCode,
  }) async {
    final response = _asMap(await _api.post('/admin/notifications/broadcast', {
      'title': title.trim(),
      'body': body.trim(),
      if (couponCode != null && couponCode.trim().isNotEmpty)
        'couponCode': couponCode.trim().toUpperCase(),
    }));
    final recipientCount = response['recipientCount'];
    final notificationsCreated = response['notificationsCreated'];
    final pushDelivery = response['pushDelivery'];
    if (recipientCount is! int ||
        notificationsCreated is! int ||
        pushDelivery is! Map<String, dynamic> ||
        pushDelivery['available'] is! bool ||
        pushDelivery['sent'] is! int ||
        pushDelivery['failed'] is! int ||
        (pushDelivery['error'] != null && pushDelivery['error'] is! String)) {
      throw Exception('The server returned an invalid broadcast result.');
    }
    return AdminBroadcastResult(
      recipientCount: recipientCount,
      notificationsCreated: notificationsCreated,
      pushAvailable: pushDelivery['available'] as bool,
      pushSent: pushDelivery['sent'] as int,
      pushFailed: pushDelivery['failed'] as int,
      pushError: pushDelivery['error'] as String?,
    );
  }

  Future<AdminBroadcastResult> sendCustomerNotification({
    required String userId,
    required String title,
    required String body,
    String? couponCode,
  }) async {
    final response = _asMap(await _api.post('/admin/notifications/customer', {
      'userId': userId,
      'title': title.trim(),
      'body': body.trim(),
      if (couponCode != null && couponCode.trim().isNotEmpty)
        'couponCode': couponCode.trim().toUpperCase(),
    }));
    return _broadcastResult(response);
  }

  AdminBroadcastResult _broadcastResult(Map<String, dynamic> response) {
    final recipientCount = response['recipientCount'];
    final notificationsCreated = response['notificationsCreated'];
    final pushDelivery = response['pushDelivery'];
    if (recipientCount is! int ||
        notificationsCreated is! int ||
        pushDelivery is! Map<String, dynamic> ||
        pushDelivery['available'] is! bool ||
        pushDelivery['sent'] is! int ||
        pushDelivery['failed'] is! int ||
        (pushDelivery['error'] != null && pushDelivery['error'] is! String)) {
      throw Exception('The server returned an invalid notification result.');
    }
    return AdminBroadcastResult(
      recipientCount: recipientCount,
      notificationsCreated: notificationsCreated,
      pushAvailable: pushDelivery['available'] as bool,
      pushSent: pushDelivery['sent'] as int,
      pushFailed: pushDelivery['failed'] as int,
      pushError: pushDelivery['error'] as String?,
    );
  }

  Future<AdminDashboard> getDashboard() async {
    return AdminDashboard.fromJson(_asMap(await _api.get('/admin/dashboard')));
  }

  Future<List<AdminCoupon>> getCoupons() async {
    final response = _asMap(await _api.get('/admin/coupons'));
    final coupons = response['coupons'];
    if (coupons is! List) {
      throw Exception('The server returned an invalid coupon list.');
    }
    return coupons
        .whereType<Map<String, dynamic>>()
        .map(AdminCoupon.fromJson)
        .toList();
  }

  Future<AdminCoupon> createCoupon(Map<String, dynamic> details) async {
    final response = _asMap(await _api.post('/admin/coupons', details));
    final coupon = response['coupon'];
    if (coupon is! Map<String, dynamic>) {
      throw Exception('The server did not return the saved coupon.');
    }
    return AdminCoupon.fromJson(coupon);
  }

  Future<AdminCoupon> issueProductCoupon({
    required String customerId,
    required String productId,
    required String discountType,
    required double discountValue,
  }) async {
    final response = _asMap(
      await _api.post('/admin/coupons/product', {
        'customerId': customerId,
        'productId': productId,
        'discountType': discountType,
        'discountValue': discountValue,
      }),
    );
    final coupon = response['coupon'];
    if (coupon is! Map<String, dynamic>) {
      throw Exception('The server did not return the product coupon.');
    }
    return AdminCoupon.fromJson(coupon);
  }

  Future<AdminCoupon> updateCoupon(
      String id, Map<String, dynamic> details) async {
    final response = _asMap(await _api.patch('/admin/coupons/$id', details));
    final coupon = response['coupon'];
    if (coupon is! Map<String, dynamic>) {
      throw Exception('The server did not return the updated coupon.');
    }
    return AdminCoupon.fromJson(coupon);
  }

  Future<AdminCoupon> setCouponActive(String id, bool isActive) async {
    final response = _asMap(await _api.patch(
      '/admin/coupons/$id/active',
      {'isActive': isActive},
    ));
    final coupon = response['coupon'];
    if (coupon is! Map<String, dynamic>) {
      throw Exception('The server did not return the updated coupon.');
    }
    return AdminCoupon.fromJson(coupon);
  }

  Future<void> removeCoupon(String id) async {
    await _api.delete('/admin/coupons/${Uri.encodeComponent(id)}');
  }

  Future<({List<AdminStreakReward> rewards, List<AdminStreakClaim> claims})>
      getStreakRewards() async {
    final response = _asMap(await _api.get('/admin/streak/rewards'));
    final rewards = response['rewards'];
    final claims = response['claims'];
    if (rewards is! List || claims is! List) {
      throw Exception('The server returned invalid buying streak settings.');
    }
    return (
      rewards: rewards
          .whereType<Map<String, dynamic>>()
          .map(AdminStreakReward.fromJson)
          .toList(growable: false),
      claims: claims
          .whereType<Map<String, dynamic>>()
          .map(AdminStreakClaim.fromJson)
          .toList(growable: false),
    );
  }

  Future<List<AdminStreakReward>> saveStreakRewards(
    List<AdminStreakReward> rewards,
  ) async {
    final response = _asMap(await _api.put('/admin/streak/rewards', {
      'rewards': rewards.map((reward) => reward.toJson()).toList(),
    }));
    final savedRewards = response['rewards'];
    if (savedRewards is! List) {
      throw Exception('The server did not return the saved streak rewards.');
    }
    return savedRewards
        .whereType<Map<String, dynamic>>()
        .map(AdminStreakReward.fromJson)
        .toList(growable: false);
  }

  Future<StoreAvailability> getStoreSettings() async {
    return StoreAvailability.fromJson(
        _asMap(await _api.get('/admin/store-settings')));
  }

  Future<StoreAvailability> updateStoreSettings({
    required bool isOrderingEnabled,
    required List<StoreHoursDay> weeklyHours,
  }) async {
    return StoreAvailability.fromJson(_asMap(await _api.put(
      '/admin/store-settings',
      {
        'isOrderingEnabled': isOrderingEnabled,
        'weeklyHours': weeklyHours.map((day) => day.toJson()).toList(),
      },
    )));
  }

  Future<AdminOrderPage> getOrders({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? status,
    DateTime? day,
  }) async {
    final response = _asMap(
      await _api.get(
        '/admin/orders',
        queryParams: {
          'page': '$page',
          'pageSize': '$pageSize',
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
          if (status != null) 'status': status,
          if (day != null) 'day': _storeDayKey(day),
        },
      ),
    );
    final orders = response['orders'];
    if (orders is! List) {
      throw Exception('The server returned an invalid order list.');
    }
    final pagination = response['pagination'];
    return AdminOrderPage(
      orders: orders
          .whereType<Map<String, dynamic>>()
          .map(AdminOrder.fromJson)
          .toList(),
      pagination: pagination is Map<String, dynamic>
          ? AdminPagination.fromJson(pagination)
          : AdminPagination(
              page: page, pageSize: pageSize, total: orders.length),
    );
  }

  Future<void> updateOrderStatus(
    String id,
    String status, {
    String? note,
  }) async {
    await _api.patch('/admin/orders/$id/status', {
      'status': status,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  Future<void> removeCustomer(
    String id, {
    required String confirmation,
  }) async {
    await _api.delete(
      '/admin/customers/${Uri.encodeComponent(id)}',
      body: {'confirmation': confirmation},
    );
  }

  Future<void> updateOrderDeliveryTime(
    String id,
    DateTime? scheduledDeliveryAt,
  ) async {
    await _api.patch('/admin/orders/$id/delivery-time', {
      'scheduledDeliveryAt': scheduledDeliveryAt?.toUtc().toIso8601String(),
    });
  }

  Future<List<AdminDeliveryPerson>> getDeliveryPeople() async {
    final response = _asMap(await _api.get('/admin/delivery/people'));
    final people = response['deliveryPeople'];
    if (people is! List) {
      throw Exception('The server returned an invalid delivery staff list.');
    }
    return people
        .whereType<Map<String, dynamic>>()
        .map(AdminDeliveryPerson.fromJson)
        .toList();
  }

  Future<List<({String id, String orderNumber})>> getRecentOrderAlerts({
    int limit = 50,
  }) async {
    final response = _asMap(await _api.get(
      '/admin/orders/alerts',
      queryParams: {'limit': '$limit'},
    ));
    final orders = response['orders'];
    if (orders is! List) {
      throw Exception('The server returned an invalid order alert list.');
    }
    return orders.map((order) {
      if (order is! Map<String, dynamic> ||
          order['id'] is! String ||
          order['orderNumber'] is! String) {
        throw Exception('The server returned an invalid order alert.');
      }
      return (
        id: order['id'] as String,
        orderNumber: order['orderNumber'] as String,
      );
    }).toList();
  }

  Future<List<AdminPendingDeliveryCash>> getPendingDeliveryCash() async {
    final response = _asMap(await _api.get('/admin/delivery/cash-pending'));
    final deliveries = response['deliveries'];
    if (deliveries is! List) {
      throw Exception('The server returned an invalid pending cash list.');
    }
    return deliveries
        .whereType<Map<String, dynamic>>()
        .map(AdminPendingDeliveryCash.fromJson)
        .toList();
  }

  Future<void> confirmDeliveryCashHandover(String deliveryId) async {
    await _api.patch('/admin/delivery/$deliveryId/cash-handover', const {});
  }

  Future<void> createDeliveryPerson({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    await _api.post('/admin/delivery/people', {
      'name': name.trim(),
      'email': email.trim(),
      if (phone.trim().isNotEmpty) 'phone': phone.trim(),
      'password': password,
    });
  }

  Future<void> setDeliveryPersonActive(String id, bool isActive) async {
    await _api.patch('/admin/delivery/people/$id/active', {
      'isActive': isActive,
    });
  }

  Future<void> assignDeliveryPerson(
      String orderId, String deliveryPersonId) async {
    await _api.patch('/admin/orders/$orderId/delivery-person', {
      'deliveryPersonId': deliveryPersonId,
    });
  }

  Future<List<AdminCustomerRemovalRecord>> getCustomerRemovalHistory({
    int page = 1,
    int pageSize = 25,
  }) async {
    final response = _asMap(await _api.get(
      '/admin/customers/removal-history',
      queryParams: {'page': '$page', 'pageSize': '$pageSize'},
    ));
    final records = response['records'];
    if (records is! List) {
      throw Exception('The server returned invalid customer removal history.');
    }
    return records
        .whereType<Map<String, dynamic>>()
        .map(AdminCustomerRemovalRecord.fromJson)
        .toList();
  }

  Future<AdminCustomerPage> getCustomers({
    int page = 1,
    int pageSize = 20,
    String? search,
    bool includeInactive = false,
  }) async {
    final response = _asMap(
      await _api.get(
        '/admin/customers',
        queryParams: {
          'page': '$page',
          'pageSize': '$pageSize',
          if (includeInactive) 'includeInactive': 'true',
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
        },
      ),
    );
    final customers = response['customers'];
    if (customers is! List) {
      throw Exception('The server returned an invalid customer list.');
    }

    final pagination = response['pagination'];
    return AdminCustomerPage(
      customers: customers
          .whereType<Map<String, dynamic>>()
          .map(AdminCustomer.fromJson)
          .toList(),
      pagination: pagination is Map<String, dynamic>
          ? AdminPagination.fromJson(pagination)
          : AdminPagination(
              page: page,
              pageSize: pageSize,
              total: customers.length,
            ),
    );
  }

  Future<void> updateCustomer(
    String customerId,
    Map<String, dynamic> fields,
  ) async {
    await _api.patch(
      '/admin/customers/${Uri.encodeComponent(customerId)}',
      fields,
    );
  }

  Future<Map<String, bool>> getCustomerMenuFeatures() async {
    final response = _asMap(
      await _api.get('/admin/customer-menu-features'),
    );
    final features = response['customerMenuFeatures'];
    if (features is! Map<String, dynamic>) {
      throw Exception('The store returned invalid customer menu settings.');
    }
    return {
      for (final entry in features.entries)
        if (entry.value is bool) entry.key: entry.value as bool,
    };
  }

  Future<Map<String, bool>> saveCustomerMenuFeatures(
    Map<String, bool> features,
  ) async {
    final response = _asMap(
      await _api.put(
        '/admin/customer-menu-features',
        features,
      ),
    );
    final saved = response['customerMenuFeatures'];
    if (saved is! Map<String, dynamic>) {
      throw Exception('The store returned invalid customer menu settings.');
    }
    return {
      for (final entry in saved.entries)
        if (entry.value is bool) entry.key: entry.value as bool,
    };
  }

  Future<List<AdminCategory>> getCategories() async {
    final response = _asMap(await _api.get('/admin/categories'));
    final categories = response['categories'];
    if (categories is! List) {
      throw Exception('The server returned an invalid category list.');
    }
    return categories
        .whereType<Map<String, dynamic>>()
        .map(AdminCategory.fromJson)
        .toList();
  }

  Future<void> createCategory(Map<String, dynamic> data) async {
    await _api.post('/admin/categories', data);
  }

  Future<void> updateCategory(
    String id,
    Map<String, dynamic> data,
  ) async {
    await _api.patch('/admin/categories/$id', data);
  }

  Future<AdminProductPage> getProducts({
    required int page,
    int pageSize = 20,
    String? stock,
    bool? wholesale,
    bool? vendingDrink,
    String sort = 'newest',
  }) async {
    final response = _asMap(
      await _api.get(
        '/admin/products',
        queryParams: {
          'page': '$page',
          'pageSize': '$pageSize',
          'sort': sort,
          if (stock != null) 'stock': stock,
          if (wholesale != null) 'wholesale': '$wholesale',
          if (vendingDrink != null) 'vendingDrink': '$vendingDrink',
        },
      ),
    );
    final products = response['products'];
    if (products is! List) {
      throw Exception('The server returned an invalid product list.');
    }
    final pagination = response['pagination'];
    return AdminProductPage(
      products: products
          .whereType<Map<String, dynamic>>()
          .map(AdminProduct.fromJson)
          .toList(),
      pagination: pagination is Map<String, dynamic>
          ? AdminPagination.fromJson(pagination)
          : AdminPagination(
              page: page, pageSize: pageSize, total: products.length),
    );
  }

  Future<AdminWholesaleItemPage> getWholesaleItems({
    required int page,
    int pageSize = 20,
    String? search,
  }) async {
    final response = _asMap(await _api.get(
      '/admin/wholesale-items',
      queryParams: {
        'page': '$page',
        'pageSize': '$pageSize',
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    ));
    final items = response['wholesaleItems'];
    if (items is! List) {
      throw Exception('The server returned an invalid wholesale item list.');
    }
    final pagination = response['pagination'];
    return AdminWholesaleItemPage(
      items: items
          .whereType<Map<String, dynamic>>()
          .map(AdminWholesaleItem.fromJson)
          .toList(),
      pagination: pagination is Map<String, dynamic>
          ? AdminPagination.fromJson(pagination)
          : AdminPagination(
              page: page, pageSize: pageSize, total: items.length),
    );
  }

  Future<void> createWholesaleItem(
    Map<String, dynamic> fields, {
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    if (imageBytes != null && imageName != null) {
      await _api.postFile(
        '/admin/wholesale-items',
        fieldName: 'image',
        bytes: imageBytes,
        fileName: imageName,
        fields: {'wholesaleItem': jsonEncode(fields)},
      );
      return;
    }
    await _api.post('/admin/wholesale-items', fields);
  }

  Future<void> updateWholesaleItem(
    String id,
    Map<String, dynamic> fields, {
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    if (imageBytes != null && imageName != null) {
      await _api.postFile(
        '/admin/wholesale-items/$id',
        fieldName: 'image',
        bytes: imageBytes,
        fileName: imageName,
        fields: {'wholesaleItem': jsonEncode(fields)},
        method: 'PATCH',
      );
      return;
    }
    await _api.patch('/admin/wholesale-items/$id', fields);
  }

  Future<void> setWholesaleItemActive(String id, bool isActive) async {
    await _api.patch('/admin/wholesale-items/$id', {'isActive': isActive});
  }

  Future<List<AdminProduct>> getAllProducts({
    String? stock,
    bool? wholesale,
    String sort = 'newest',
  }) async {
    const pageSize = 100;
    final allProducts = <AdminProduct>[];
    var page = 1;

    while (true) {
      final result = await getProducts(
        page: page,
        pageSize: pageSize,
        stock: stock,
        wholesale: wholesale,
        sort: sort,
      );
      allProducts.addAll(result.products);
      if (allProducts.length >= result.pagination.total) {
        return allProducts;
      }
      if (result.products.isEmpty) {
        throw Exception('The server returned an incomplete product list.');
      }
      page++;
    }
  }

  Future<void> createProduct(
    Map<String, dynamic> fields,
    double stock, {
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    if (imageBytes != null && imageName != null) {
      await _api.postFile(
        '/admin/products',
        fieldName: 'image',
        bytes: imageBytes,
        fileName: imageName,
        fields: {
          'product': jsonEncode({...fields, 'stock': stock})
        },
      );
      return;
    }
    await _api.post('/admin/products', {
      ...fields,
      'stock': stock,
    });
  }

  Future<void> updateProduct(
    String id,
    Map<String, dynamic> fields,
    double stock, {
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    if (imageBytes != null && imageName != null) {
      await _api.postFile(
        '/admin/products/$id',
        fieldName: 'image',
        bytes: imageBytes,
        fileName: imageName,
        fields: {
          'product': jsonEncode({...fields, 'stock': stock})
        },
        method: 'PATCH',
      );
      return;
    }
    await _api.patch('/admin/products/$id', {
      ...fields,
      'stock': stock,
    });
  }

  Future<void> deactivateProduct(String id) async {
    await _api.delete('/admin/products/$id');
  }

  Future<void> setProductActive(String id, bool isActive) async {
    await _api.patch('/admin/products/$id', {'isActive': isActive});
  }

  Future<AdminProduct> restockProduct(
    String id,
    Map<String, dynamic> batch,
  ) async {
    final response = _asMap(
      await _api.post('/admin/products/$id/restock', batch),
    );
    final product = response['product'];
    if (product is! Map<String, dynamic>) {
      throw Exception('The server returned an invalid restocked product.');
    }
    return AdminProduct.fromJson(product);
  }

  Future<Map<String, dynamic>> lookupProductBarcode(String barcode) async {
    final response = _asMap(await _api.get(
      '/admin/products/barcode-lookup',
      queryParams: {'barcode': barcode.trim()},
    ));
    if (response['found'] is! bool ||
        response['source'] is! String ||
        (response['product'] != null &&
            response['product'] is! Map<String, dynamic>)) {
      throw const FormatException(
        'The server returned an invalid barcode lookup response.',
      );
    }
    return response;
  }

  Future<AdminProduct> receiveProductBatch(
    String productId,
    Map<String, dynamic> batch,
  ) async {
    final response = _asMap(
      await _api.post('/admin/products/$productId/batches', batch),
    );
    final product = response['product'];
    if (product is! Map<String, dynamic>) {
      throw const FormatException(
        'The server returned an invalid product after receiving the batch.',
      );
    }
    return AdminProduct.fromJson(product);
  }

  Future<AdminInventoryExpiryPage> getExpiryBatches({
    required int warningDays,
    required String status,
    required int page,
    String? categoryId,
    bool lowStock = false,
  }) async {
    final response = _asMap(await _api.get(
      '/admin/inventory/expiry',
      queryParams: {
        'days': '$warningDays',
        'status': status,
        'page': '$page',
        'pageSize': '25',
        'lowStock': '$lowStock',
        if (categoryId != null) 'categoryId': categoryId,
      },
    ));
    return AdminInventoryExpiryPage.fromJson(response);
  }

  Future<AdminRestockHistoryPage> getRestockHistory({
    required int page,
    int pageSize = 25,
    DateTime? day,
  }) async {
    final response = _asMap(
      await _api.get(
        '/admin/inventory/restock-history',
        queryParams: {
          'page': '$page',
          'pageSize': '$pageSize',
          if (day != null) 'day': _storeDayKey(day),
        },
      ),
    );
    final receipts = response['receipts'];
    if (receipts is! List) {
      throw Exception('The server returned invalid restock history.');
    }
    final pagination = response['pagination'];
    return AdminRestockHistoryPage(
      receipts: receipts
          .whereType<Map<String, dynamic>>()
          .map(AdminRestockReceipt.fromJson)
          .toList(),
      pagination: pagination is Map<String, dynamic>
          ? AdminPagination.fromJson(pagination)
          : AdminPagination(
              page: page,
              pageSize: pageSize,
              total: receipts.length,
            ),
    );
  }

  Future<void> updateProductSku(String id, String sku) async {
    await _api.patch('/admin/products/$id', {'sku': sku});
  }

  Future<void> updateProductFeatured(String id, bool isFeatured) async {
    await _api.patch('/admin/products/$id', {'isFeatured': isFeatured});
  }

  Future<void> updateProductPrices(
    String id, {
    required double price,
    required double? originalPrice,
  }) async {
    await _api.patch('/admin/products/$id', {
      'price': price,
      'originalPrice': originalPrice,
    });
  }

  Future<String> updateProductImage(
    String id,
    Uint8List bytes,
    String fileName,
  ) async {
    final response = _asMap(await _api.postFile(
      '/admin/products/$id',
      fieldName: 'image',
      bytes: bytes,
      fileName: fileName,
      fields: {
        'product': jsonEncode({'imageUrl': null})
      },
      method: 'PATCH',
    ));
    final product = response['product'];
    if (product is! Map<String, dynamic> || product['imageUrl'] is! String) {
      throw Exception('The server did not return the saved product image.');
    }
    return Uri.parse(_api.baseUrl)
        .resolve(product['imageUrl'] as String)
        .toString();
  }

  Future<String> uploadProductImage(Uint8List bytes, String fileName) async {
    return _uploadImage(
      bytes,
      fileName,
      endpoint: '/admin/uploads/product-images',
    );
  }

  Future<String> uploadImage(Uint8List bytes, String fileName) async {
    return _uploadImage(bytes, fileName, endpoint: '/admin/uploads/images');
  }

  Future<String> _uploadImage(
    Uint8List bytes,
    String fileName, {
    required String endpoint,
  }) async {
    final response = _asMap(await _api.postFile(
      endpoint,
      fieldName: 'image',
      bytes: bytes,
      fileName: fileName,
    ));
    final path = response['url'];
    if (path is! String || !path.startsWith('/api/v1/images/')) {
      throw Exception('The server returned an invalid image URL.');
    }
    return Uri.parse(_api.baseUrl).resolve(path).toString();
  }
}

class AdminBroadcastResult {
  final int recipientCount;
  final int notificationsCreated;
  final bool pushAvailable;
  final int pushSent;
  final int pushFailed;
  final String? pushError;

  const AdminBroadcastResult({
    required this.recipientCount,
    required this.notificationsCreated,
    required this.pushAvailable,
    required this.pushSent,
    required this.pushFailed,
    this.pushError,
  });
}

class AdminProductPage {
  final List<AdminProduct> products;
  final AdminPagination pagination;

  const AdminProductPage({required this.products, required this.pagination});
}

class AdminWholesaleItemPage {
  final List<AdminWholesaleItem> items;
  final AdminPagination pagination;

  const AdminWholesaleItemPage({
    required this.items,
    required this.pagination,
  });
}

class AdminRestockHistoryPage {
  final List<AdminRestockReceipt> receipts;
  final AdminPagination pagination;

  const AdminRestockHistoryPage({
    required this.receipts,
    required this.pagination,
  });
}

class AdminOrderPage {
  final List<AdminOrder> orders;
  final AdminPagination pagination;

  const AdminOrderPage({required this.orders, required this.pagination});
}

class AdminCustomerPage {
  final List<AdminCustomer> customers;
  final AdminPagination pagination;

  const AdminCustomerPage({
    required this.customers,
    required this.pagination,
  });
}

class AdminPagination {
  final int page;
  final int pageSize;
  final int total;

  const AdminPagination({
    required this.page,
    required this.pageSize,
    required this.total,
  });

  factory AdminPagination.fromJson(Map<String, dynamic> json) {
    return AdminPagination(
      page: _asInt(json['page']),
      pageSize: _asInt(json['pageSize']) > 0 ? _asInt(json['pageSize']) : 20,
      total: _asInt(json['total']),
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  throw Exception('The server returned an invalid response.');
}

String _storeDayKey(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  return '${normalized.year.toString().padLeft(4, '0')}-'
      '${normalized.month.toString().padLeft(2, '0')}-'
      '${normalized.day.toString().padLeft(2, '0')}';
}

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
