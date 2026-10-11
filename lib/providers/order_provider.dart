import 'package:flutter/material.dart';
import '../models/order.dart';
import '../models/cart_item.dart';
import '../models/address.dart';
import '../services/api_service.dart';

class OrderProvider extends ChangeNotifier {
  final ApiService _apiService;
  final List<Order> _orders = [];
  Order? _activeOrder;
  bool _isLoading = false;
  final Map<String, Future<void>> _ordersBeingRefreshed = {};

  OrderProvider({required ApiService apiService}) : _apiService = apiService;

  List<Order> get orders => [..._orders];
  Order? get activeOrder => _activeOrder;
  bool get isLoading => _isLoading;

  void setActiveOrder(Order order) {
    _activeOrder = order;
    notifyListeners();
  }

  Future<void> refreshOrder(String orderId) {
    final existingRefresh = _ordersBeingRefreshed[orderId];
    if (existingRefresh != null) return existingRefresh;

    final refresh = _fetchOrder(orderId);
    _ordersBeingRefreshed[orderId] = refresh;
    return refresh.whenComplete(() {
      if (identical(_ordersBeingRefreshed[orderId], refresh)) {
        _ordersBeingRefreshed.remove(orderId);
      }
    });
  }

  Future<void> _fetchOrder(String orderId) async {
    final response = await _apiService.get('/orders/$orderId');
    if (response is! Map<String, dynamic> ||
        response['order'] is! Map<String, dynamic>) {
      throw StateError('The server returned an invalid order response.');
    }

    final updatedOrder =
        Order.fromJson(response['order'] as Map<String, dynamic>);
    if (updatedOrder.id != orderId) {
      throw StateError('The server returned a different order.');
    }

    final index = _orders.indexWhere((order) => order.id == orderId);
    final currentOrder = index < 0 ? null : _orders[index];
    if (index < 0) {
      _orders.insert(0, updatedOrder);
    } else {
      _orders[index] = updatedOrder;
    }
    if (_activeOrder?.id == orderId) _activeOrder = updatedOrder;
    if (currentOrder == null ||
        currentOrder.status != updatedOrder.status ||
        currentOrder.deliveryPersonName != updatedOrder.deliveryPersonName ||
        currentOrder.deliveryPersonPhone != updatedOrder.deliveryPersonPhone) {
      notifyListeners();
    }
  }

  Future<Order> placeOrder({
    required List<CartItem> items,
    required Address address,
    required String paymentMethod,
    required String idempotencyKey,
    required double tip,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.post('/orders', {
        'items': items
            .map((item) => {
                  'productId': item.product.id,
                  'quantity': item.quantity,
                })
            .toList(),
        'addressId': address.id,
        'paymentMethod': paymentMethod,
        'tip': tip,
        'idempotencyKey': idempotencyKey,
      });
      if (response is! Map<String, dynamic> ||
          response['order'] is! Map<String, dynamic>) {
        throw StateError('The server returned an invalid order response.');
      }
      final order = Order.fromJson(response['order'] as Map<String, dynamic>);
      _orders.removeWhere((existing) => existing.id == order.id);
      _orders.insert(0, order);
      _activeOrder = order;
      return order;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadOrders() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _apiService.get('/orders');
      if (response is! Map<String, dynamic> || response['data'] is! List) {
        throw StateError('The server returned invalid order history.');
      }
      _orders
        ..clear()
        ..addAll(
          (response['data'] as List)
              .whereType<Map<String, dynamic>>()
              .map(Order.fromJson),
        );
      if (_activeOrder != null) {
          final activeId = _activeOrder!.id;
          for (final order in _orders) {
            if (order.id == activeId) {
              _activeOrder = order;
              break;
            }
          }
        }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateOrderStatus(String orderId, String newStatus) {
    final index = _orders.indexindexWhere((o) => o.id == orderId);
    if (index != -1) {
      final current = _orders[index];
      _orders[index] = Order(
        id: current.id,
        orderNumber: current.orderNumber,
        items: current.items,
        address: current.address,
        status: newStatus,
        paymentMethod: current.paymentMethod,
        paymentStatus:
            newStatus == 'DELIVERED' && current.paymentMethod == 'COD'
                ? 'COMPLETED'
                : current.paymentStatus,
        subtotal: current.subtotal,
        deliveryFee: current.deliveryFee,
        discount: current.discount,
        tip: current.tip,
        total: current.total,
        createdAt: current.createdAt,
        deliveryPersonName: current.deliveryPersonName,
        deliveryPersonPhone: current.deliveryPersonPhone,
      );
      if (_activeOrder?.id == orderId) {
        _activeOrder = _orders[index];
      }
      notifyListeners();
    }
  }

  Future<bool> cancelOrder(String orderId) async {
    final response = await _apiService.post('/orders/$orderId/cancel', const {});
    if (response is! Map<String, dynamic> ||
        response['order'] is! Map<String, dynamic>) {
      throw StateError('The server returned an invalid cancellation response.');
    }
    final order = Order.fromJson(response['order'] as Map<String, dynamic>);
    final index = _orders.indexWhere((existing) => existing.id == order.id);
    if (index < 0) {
      _orders.insert(0, order);
    } else {
      _orders[index] = order;
    }
    if (_activeOrder?.id == order.id) _activeOrder = order;
    notifyListeners();
    return true;
  }
}

extension ListExtensions<T> on List<T> {
  int indexindexWhere(bool Function(T) test) {
    for (int i = 0; i < length; i++) {
      if (test(this[i])) return i;
    }
    return -1;
  }
}
