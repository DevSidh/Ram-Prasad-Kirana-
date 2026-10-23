import 'dart:async';

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class CartProvider extends ChangeNotifier {
  final Map<String, CartItem> _items = {};
  final ApiService? _apiService;
  String? _accountUserId;
  bool _isLoading = false;
  bool _disposed = false;
  bool _hasLoadedAccountCart = false;
  bool _hasUnsavedChanges = false;
  String? _syncError;
  bool _syncErrorFromSave = false;
  String? _suggestedCouponCode;
  Timer? _saveDebounce;
  int _revision = 0;
  Future<void> _syncQueue = Future<void>.value();
  Future<void>? _cartLoadFuture;
  final Set<String> _localOverridesDuringLoad = {};
  bool _clearDuringLoad = false;

  CartProvider({ApiService? apiService}) : _apiService = apiService;

  Map<String, CartItem> get items => {..._items};
  CartItem? itemForProduct(String productId, {bool isWholesale = false}) =>
      _items[_itemKey(productId, isWholesale)];
  List<CartItem> get itemList => _items.values.toList();
  int get itemCount =>
      _items.values.fold(0, (sum, item) => sum + item.quantity);
  bool get isLoading => _isLoading;
  String? get syncError => _syncError;
  bool get hasUnavailableItems => _items.values.any((item) {
        final minimumQuantity =
            item.isWholesale ? item.product.wholesaleMinimumQuantity : 1;
        return (item.weightGrams != null
                ? item.weightGrams! > item.product.availableWeightGrams
                : item.quantity > item.product.stock) ||
            item.quantity > 100 ||
            item.product.stock < minimumQuantity ||
            (item.isWholesale &&
                (!item.product.isWholesale ||
                    item.product.wholesalePrice == null));
      });
  String? get suggestedCouponCode => _suggestedCouponCode;

  double get subtotal =>
      _items.values.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get deliveryFee => AppConstants.defaultDeliveryFee;

  double get grandTotal => subtotal + deliveryFee;

  String _itemKey(String productId, bool isWholesale) =>
      isWholesale ? '$productId:wholesale' : productId;

  void setAuthenticatedUser(String? userId) {
    if (_accountUserId == userId) return;
    _accountUserId = userId;
    final revision = ++_revision;
    _items.clear();
    _hasLoadedAccountCart = userId == null || _apiService == null;
    _hasUnsavedChanges = false;
    _suggestedCouponCode = null;
    _localOverridesDuringLoad.clear();
    _clearDuringLoad = false;
    _cartLoadFuture = null;
    _saveDebounce?.cancel();
    _saveDebounce = null;
    _isLoading = userId != null && _apiService != null;
    _syncError = null;
    _syncErrorFromSave = false;
    scheduleMicrotask(() {
      if (!_disposed) notifyListeners();
    });
    if (_isLoading) unawaited(_startAccountCartLoad(userId!, revision));
  }

  Future<void> _startAccountCartLoad(String userId, int revision) {
    final load = _loadAccountCart(userId, revision);
    _cartLoadFuture = load;
    unawaited(load.whenComplete(() {
      if (identical(_cartLoadFuture, load)) _cartLoadFuture = null;
    }));
    return load;
  }

  Future<void> refreshSavedCart() async {
    final userId = _accountUserId;
    if (userId == null || _apiService == null) return;
    if (_isLoading) {
      await _cartLoadFuture;
      return;
    }
    if (_syncErrorFromSave) {
      await retrySync();
      return;
    }
    if (_hasLoadedAccountCart && _hasUnsavedChanges) {
      _saveDebounce?.cancel();
      _saveDebounce = null;
      try {
        await _writeCurrentCart();
      } on Exception {
        return;
      }
      return;
    }
    _isLoading = true;
    _syncError = null;
    _syncErrorFromSave = false;
    notifyListeners();
    await _startAccountCartLoad(userId, _revision);
  }

  Future<void> retrySync() async {
    if (_syncErrorFromSave) {
      try {
        await _writeCurrentCart();
      } on Exception catch (error) {
        if (_accountUserId != null) {
          _syncError = error.toString().replaceFirst('Exception: ', '');
          _syncErrorFromSave = true;
          if (!_disposed) notifyListeners();
        }
      }
      return;
    }
    await refreshSavedCart();
  }

  Future<void> _loadAccountCart(String userId, int revision) async {
    try {
      final response = await _apiService!.get('/account/cart');
      if (response is! Map<String, dynamic> || response['items'] is! List) {
        throw const FormatException(
          'The server returned an invalid saved basket.',
        );
      }
      final restoredItems = <String, CartItem>{};
      for (final entry in response['items'] as List) {
        if (entry is! Map<String, dynamic> ||
            entry['product'] is! Map<String, dynamic> ||
            entry['quantity'] is! num ||
            entry['isWholesale'] is! bool) {
          throw const FormatException(
            'The server returned an invalid saved basket item.',
          );
        }
        final item = CartItem(
          product: Product.fromJson(entry['product'] as Map<String, dynamic>),
          quantity: (entry['quantity'] as num).toInt(),
          isWholesale: entry['isWholesale'] as bool,
          weightGrams: (entry['weightGrams'] as num?)?.toInt(),
        );
        restoredItems[_itemKey(item.product.id, item.isWholesale)] = item;
      }
      if (_accountUserId != userId) return;
      _hasLoadedAccountCart = true;
      if (_revision != revision ||
          _localOverridesDuringLoad.isNotEmpty ||
          _clearDuringLoad) {
        final localItems = Map<String, CartItem>.from(_items);
        if (_clearDuringLoad) restoredItems.clear();
        for (final key in _localOverridesDuringLoad) {
          final item = localItems[key];
          if (item == null) {
            restoredItems.remove(key);
          } else {
            restoredItems[key] = item;
          }
        }
        _items
          ..clear()
          ..addAll(restoredItems);
        _localOverridesDuringLoad.clear();
        _clearDuringLoad = false;
        _hasUnsavedChanges = true;
        _isLoading = false;
        _scheduleServerSave();
        notifyListeners();
        return;
      }
      _items
        ..clear()
        ..addAll(restoredItems);
      _localOverridesDuringLoad.clear();
      _clearDuringLoad = false;
      _isLoading = false;
      _syncError = null;
      _syncErrorFromSave = false;
      notifyListeners();
    } catch (error) {
      if (_accountUserId != userId) return;
      _isLoading = false;
      _hasLoadedAccountCart = false;
      _syncError = error.toString().replaceFirst('Exception: ', '');
      _syncErrorFromSave = false;
      notifyListeners();
    }
  }

  void addItem(
    Product product, [
    int quantity = 1,
    bool isWholesale = false,
  ]) {
    if (isWholesale &&
        (!product.isWholesale || product.wholesalePrice == null)) {
      throw StateError('Wholesale pricing is not available for this product.');
    }
    final key = _itemKey(product.id, isWholesale);
    if (_items.containsKey(key)) {
      final current = _items[key]!;
      final minimumQuantity =
          isWholesale ? product.wholesaleMinimumQuantity : 1;
      if (product.stock < minimumQuantity) {
        throw StateError(
            'There is not enough stock for the wholesale minimum.');
      }
      final maximumQuantity = product.stock.clamp(0, 100);
      if (maximumQuantity < minimumQuantity) {
        throw StateError(
            'There is not enough stock for the wholesale minimum.');
      }
      final newQty =
          (current.quantity + quantity).clamp(minimumQuantity, maximumQuantity);
      _items[key] = CartItem(
        product: product,
        quantity: newQty,
        isWholesale: isWholesale,
      );
    } else {
      final minimumQuantity =
          isWholesale ? product.wholesaleMinimumQuantity : 1;
      final maximumQuantity = product.stock.clamp(0, 100);
      if (maximumQuantity < minimumQuantity) {
        throw StateError(
            'There is not enough stock for the wholesale minimum.');
      }
      _items[key] = CartItem(
        product: product,
        quantity: quantity.clamp(minimumQuantity, maximumQuantity),
        isWholesale: isWholesale,
      );
    }
    _markChanged(key: key);
  }

  void addWeightedItem(Product product, int weightGrams) {
    if (!product.isSoldByWeight || weightGrams < 1) {
      throw StateError('Enter a valid weight in kilograms.');
    }
    final key = _itemKey(product.id, false);
    final current = _items[key];
    final nextWeight = (current?.weightGrams ?? 0) + weightGrams;
    if (nextWeight > product.availableWeightGrams) {
      throw StateError('The requested weight exceeds available stock.');
    }
    _items[key] = CartItem(
      product: product,
      quantity: 1,
      weightGrams: nextWeight,
    );
    _markChanged(key: key);
  }

  void setWeightedItem(Product product, int weightGrams) {
    if (!product.isSoldByWeight || weightGrams < 0) {
      throw StateError('Enter a valid weight in kilograms.');
    }
    if (weightGrams == 0) {
      removeItem(product.id);
      return;
    }
    if (weightGrams > product.availableWeightGrams) {
      throw StateError('The requested weight exceeds available stock.');
    }
    final key = _itemKey(product.id, false);
    _items[key] = CartItem(
      product: product,
      quantity: 1,
      weightGrams: weightGrams,
    );
    _markChanged(key: key);
  }

  void updateQuantity(
    String productId,
    int quantity, {
    bool isWholesale = false,
  }) {
    final key = _itemKey(productId, isWholesale);
    if (!_items.containsKey(key)) return;
    if (quantity <= 0) {
      removeItem(productId, isWholesale: isWholesale);
      return;
    }
    final item = _items[key]!;
    final minimumQuantity =
        isWholesale ? item.product.wholesaleMinimumQuantity : 1;
    final maximumQuantity = item.product.stock.clamp(0, 100);
    if (maximumQuantity < minimumQuantity) {
      return;
    }
    _items[key] = CartItem(
      product: item.product,
      quantity: quantity.clamp(minimumQuantity, maximumQuantity),
      isWholesale: isWholesale,
    );
    _markChanged(key: key);
  }

  void removeItem(String productId, {bool isWholesale = false}) {
    _items.remove(_itemKey(productId, isWholesale));
    _markChanged(key: _itemKey(productId, isWholesale));
  }

  void restoreItem(
    Product product,
    int quantity, {
    bool isWholesale = false,
  }) {
    final key = _itemKey(product.id, isWholesale);
    _items[key] = CartItem(
      product: product,
      quantity: quantity,
      isWholesale: isWholesale,
    );
    _markChanged(key: key);
  }

  void clearCart() {
    _items.clear();
    _suggestedCouponCode = null;
    _markChanged(clearAll: true);
  }

  void suggestCouponCode(String code) {
    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty || normalizedCode == _suggestedCouponCode) {
      return;
    }
    _suggestedCouponCode = normalizedCode;
    notifyListeners();
  }

  void clearSuggestedCouponCode([String? expectedCode]) {
    if (expectedCode != null &&
        _suggestedCouponCode != expectedCode.trim().toUpperCase()) {
      return;
    }
    if (_suggestedCouponCode == null) return;
    _suggestedCouponCode = null;
    notifyListeners();
  }

  void _markChanged({String? key, bool clearAll = false}) {
    if (_accountUserId != null && _apiService != null) {
      _hasUnsavedChanges = true;
    }
    if (_isLoading && _accountUserId != null) {
      if (clearAll) _clearDuringLoad = true;
      if (key != null) _localOverridesDuringLoad.add(key);
    }
    _revision++;
    _syncError = null;
    notifyListeners();
    _scheduleServerSave();
  }

  void _scheduleServerSave() {
    if (_accountUserId == null || _apiService == null) return;
    if (_isLoading || !_hasLoadedAccountCart) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 250), () {
      _saveDebounce = null;
      unawaited(_writeCurrentCart().catchError((_) {}));
    });
  }

  Future<void> _writeCurrentCart() async {
    final userId = _accountUserId;
    final apiService = _apiService;
    if (userId == null || apiService == null) return;
    final items = _items.values
        .map((item) => {
              'productId': item.product.id,
              'quantity': item.quantity,
              'isWholesale': item.isWholesale,
              if (item.weightGrams != null) 'weightGrams': item.weightGrams,
            })
        .toList(growable: false);
    final revision = _revision;

    Future<void> send() async {
      if (_accountUserId != userId) return;
      try {
        await apiService.put('/account/cart', {'items': items});
        if (_accountUserId == userId) {
          if (_revision == revision) _hasUnsavedChanges = false;
          _syncError = null;
          _syncErrorFromSave = false;
        }
      } catch (error) {
        if (_accountUserId == userId) {
          _syncError = error.toString().replaceFirst('Exception: ', '');
          _syncErrorFromSave = true;
        }
        rethrow;
      } finally {
        if (_accountUserId == userId && !_disposed) notifyListeners();
      }
    }

    final pending = _syncQueue.then<void>(
      (_) => send(),
      onError: (Object _, StackTrace __) => send(),
    );
    _syncQueue = pending;
    return pending;
  }

  @override
  void dispose() {
    _disposed = true;
    _saveDebounce?.cancel();
    super.dispose();
  }
}
