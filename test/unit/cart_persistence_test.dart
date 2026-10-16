import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/models/product.dart';
import 'package:freshharvest_grocery/providers/cart_provider.dart';
import 'package:freshharvest_grocery/services/api_service.dart';

class _CartApi extends ApiService {
  Map<String, dynamic> savedCart = {'items': <Map<String, dynamic>>[]};
  final List<List<Map<String, dynamic>>> cartWrites = [];
  Completer<dynamic>? cartLoad;
  int saveCount = 0;
  int loadCount = 0;
  bool failNextSave = false;
  final Completer<void> twoSavesCompleted = Completer<void>();

  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    if (endpoint == '/account/cart') {
      loadCount++;
      return cartLoad?.future ?? savedCart;
    }
    return super.get(endpoint, queryParams: queryParams);
  }

  @override
  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    if (endpoint == '/account/cart') {
      if (failNextSave) {
        failNextSave = false;
        throw Exception('Network unavailable');
      }
      cartWrites.add(
        (body['items'] as List).cast<Map<String, dynamic>>(),
      );
      saveCount++;
      if (saveCount == 2 && !twoSavesCompleted.isCompleted) {
        twoSavesCompleted.complete();
      }
      return null;
    }
    return super.put(endpoint, body);
  }
}

Map<String, dynamic> _savedItem(String id, int quantity) => {
      'product': {
        'id': id,
        'name': 'Apples',
        'categoryId': 'fruit',
        'categoryName': 'Fruit',
        'categorySlug': 'fruit',
        'price': 200,
        'unitLabel': '1 kg',
        'stock': 10,
        'description': 'Fresh apples',
        'imageUrl': '',
      },
      'quantity': quantity,
      'isWholesale': false,
    };

void main() {
  test('cart restores, syncs, and switches account data without mixing',
      () async {
    final api = _CartApi()
      ..savedCart = {
        'items': [_savedItem('apples', 2)],
      };
    final cart = CartProvider(apiService: api);
    addTearDown(cart.dispose);

    cart.setAuthenticatedUser('customer-1');
    await cart.refreshSavedCart();
    expect(cart.itemCount, 2);

    cart.updateQuantity('apples', 3);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(api.cartWrites.last, [
      {'productId': 'apples', 'quantity': 3, 'isWholesale': false},
    ]);

    api.savedCart = {'items': <Map<String, dynamic>>[]};
    cart.setAuthenticatedUser('customer-2');
    await cart.refreshSavedCart();
    expect(cart.items, isEmpty);
  });

  test('cart merges edits made while saved account items are loading',
      () async {
    final api = _CartApi()..cartLoad = Completer<dynamic>();
    final cart = CartProvider(apiService: api);
    addTearDown(cart.dispose);
    cart.setAuthenticatedUser('customer-1');

    cart.addItem(
      Product(
        id: 'bananas',
        name: 'Bananas',
        categoryId: 'fruit',
        price: 100,
        weight: '1 kg',
        stock: 10,
        description: 'Fresh bananas',
        imageUrl: '',
      ),
    );
    api.cartLoad!.complete({
      'items': [_savedItem('apples', 2)],
    });
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(cart.itemCount, 3);
    expect(cart.items.keys, containsAll(['apples', 'bananas']));
    expect(api.cartWrites, hasLength(1));
    expect(api.cartWrites.single.map((item) => item['productId']),
        containsAll(['apples', 'bananas']));
  });

  test('retry resends local edits after a saved-cart write failure', () async {
    final api = _CartApi()
      ..savedCart = {
        'items': [_savedItem('apples', 2)],
      };
    final cart = CartProvider(apiService: api);
    addTearDown(cart.dispose);
    cart.setAuthenticatedUser('customer-1');
    await cart.refreshSavedCart();

    api.failNextSave = true;
    cart.updateQuantity('apples', 3);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(cart.syncError, 'Network unavailable');
    final loadsBeforeRetry = api.loadCount;

    await cart.retrySync();

    expect(api.loadCount, loadsBeforeRetry);
    expect(api.cartWrites.last, [
      {'productId': 'apples', 'quantity': 3, 'isWholesale': false},
    ]);
    expect(cart.syncError, isNull);
  });
}
