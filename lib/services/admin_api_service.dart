import 'dart:typed_data';

import '../models/admin_models.dart';
import 'api_service.dart';

class AdminApiService {
  final ApiService _api;

  AdminApiService(this._api);

  Future<AdminDashboard> getDashboard() async {
    return AdminDashboard.fromJson(_asMap(await _api.get('/admin/dashboard')));
  }

  Future<AdminOrderPage> getOrders({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? status,
  }) async {
    final response = _asMap(
      await _api.get(
        '/admin/orders',
        queryParams: {
          'page': '$page',
          'pageSize': '$pageSize',
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
          if (status != null) 'status': status,
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
          : AdminPagination(page: page, pageSize: pageSize, total: orders.length),
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

  Future<void> assignDeliveryPerson(String orderId, String deliveryPersonId) async {
    await _api.patch('/admin/orders/$orderId/delivery-person', {
      'deliveryPersonId': deliveryPersonId,
    });
  }

  Future<AdminCustomerPage> getCustomers({
    int page = 1,
    int pageSize = 20,
    String? search,
  }) async {
    final response = _asMap(
      await _api.get(
        '/admin/customers',
        queryParams: {
          'page': '$page',
          'pageSize': '$pageSize',
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
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

  Future<AdminProductPage> getProducts(
      {required int page, int pageSize = 20}) async {
    final response = _asMap(
      await _api.get(
        '/admin/products',
        queryParams: {'page': '$page', 'pageSize': '$pageSize'},
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

  Future<List<AdminProduct>> getAllProducts() async {
    const pageSize = 100;
    final allProducts = <AdminProduct>[];
    var page = 1;

    while (true) {
      final result = await getProducts(page: page, pageSize: pageSize);
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

  Future<void> createProduct(Map<String, dynamic> fields, int stock) async {
    await _api.post('/admin/products', {
      ...fields,
      'stock': stock,
    });
  }

  Future<void> updateProduct(
    String id,
    Map<String, dynamic> fields,
    int stock,
  ) async {
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

  Future<void> updateProductSku(String id, String sku) async {
    await _api.patch('/admin/products/$id', {'sku': sku});
  }

  Future<void> updateProductFeatured(String id, bool isFeatured) async {
    await _api.patch('/admin/products/$id', {'isFeatured': isFeatured});
  }

  Future<void> updateProductImage(String id, String imageUrl) async {
    await _api.patch('/admin/products/$id', {'imageUrl': imageUrl});
  }

  Future<String> uploadProductImage(Uint8List bytes, String fileName) async {
    final response = _asMap(await _api.postFile(
      '/admin/uploads/images',
      fieldName: 'image',
      bytes: bytes,
      fileName: fileName,
    ));
    final path = response['url'];
    if (path is! String || !path.startsWith('/uploads/')) {
      throw Exception('The server returned an invalid image URL.');
    }
    return Uri.parse(_api.baseUrl).resolve(path).toString();
  }
}

class AdminProductPage {
  final List<AdminProduct> products;
  final AdminPagination pagination;

  const AdminProductPage({required this.products, required this.pagination});
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

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
