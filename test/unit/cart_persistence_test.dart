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
  bool expiredToken = false;
  final Completer<void> twoSavesCompleted = Completer<void>();

  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    if (endpoint == '/account/cart') {
      loadCount++;
      if (expiredToken) {
        throw const ApiResponseException('Invalid or expired access token',
            statusCode: 401);
      }
      return cartLoad?.future ?? savedCart;
    }
    return super.get(endpoint, queryParams: queryParams);
  }

  @override
  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    if (endpoint == '/account/cart') {
      if (expiredToken) {
        throw const ApiResponseException('Invalid or expired access token',
            statusCode: 401);
      }
      if (failNextSave) {
        failNextSave = false;
        throw Exception('Network unavailable');
      }
      cartWrites.add(
        (body['items'] as List).cast<Map<String, dynamic>>(),
      );
      savedCart = {
        'items': cartWrites.last.map((item) {
          final saved = _savedItem(
            item['productId']! as String,
            item['quantity']! as int,
          );
          saved['isWholesale'] = item['isWholesale'];
          if (item['weightGrams'] != null) {
            saved['weightGrams'] = item['weightGrams'];
          }
          return saved;
        }).toList(),
      };
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
  test(
      'expired cart session requests sign-in and preserves additions through renewal',
      () async {
    final api = _CartApi()..expiredToken = true;
    api.savedCart = {
      'items': [_savedItem('apples', 2)]
    };
    api.setAuthToken('expired');
    final cart = CartProvider(apiService: api);
    addTearDown(cart.dispose);
    cart.setAuthenticatedUser('customer-1');
    await cart.refreshSavedCart();
    expect(cart.requiresSignIn, isTrue);
    expect(cart.syncError, contains('Sign in again'));
    cart.addItem(Product.fromJson(
        _savedItem('rice', 1)['product'] as Map<String, dynamic>));
    expect(cart.itemCount, 1);
    api.expiredToken = false;
    api.setAuthToken('renewed');
    cart.setAuthenticatedUser('customer-1');
    await cart.refreshSavedCart();
    expect(cart.requiresSignIn, isFalse);
    expect(cart.items.keys.toSet(), {'apples', 'rice'});
    expect(cart.itemCount, 3);
  });

  test(
      'renewing after an unauthorized save keeps quantities and does not mix accounts',
      () async {
    final api = _CartApi()
      ..savedCart = {
        'items': [_savedItem('apples', 2)]
      };
    api.setAuthToken('old-token');
    final cart = CartProvider(apiService: api);
    addTearDown(cart.dispose);
    cart.setAuthenticatedUser('customer-1');
    await cart.refreshSavedCart();
    api.expiredToken = true;
    cart.addItem(Product.fromJson(
        _savedItem('apples', 1)['product'] as Map<String, dynamic>));
    await cart.refreshSavedCart();
    expect(cart.requiresSignIn, isTrue);
    expect(cart.itemCount, 3);
    api.expiredToken = false;
    api.setAuthToken('new-token');
    cart.setAuthenticatedUser('customer-1');
    await cart.retrySync();
    expect(cart.requiresSignIn, isFalse);
    expect(cart.itemCount, 3);
    api.savedCart = {'items': <Map<String, dynamic>>[]};
    cart.setAuthenticatedUser('customer-2');
    await cart.refreshSavedCart();
    expect(cart.itemCount, 0);
  });

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

  test('refresh saves pending additions before loading the server cart',
      () async {
    final api = _CartApi();
    final cart = CartProvider(apiService: api);
    addTearDown(cart.dispose);
    cart.setAuthenticatedUser('customer-1');
    await Future<void>.delayed(Duration.zero);
    expect(cart.isLoading, isFalse);

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
      3,
    );

    await cart.refreshSavedCart();

    expect(cart.itemCount, 3);
    expect(api.cartWrites, hasLength(1));
    expect(api.cartWrites.single, [
      {'productId': 'bananas', 'quantity': 3, 'isWholesale': false},
    ]);
    expect(
      (api.savedCart['items'] as List)
          .map((item) => (item as Map<String, dynamic>)['product']['id']),
      ['bananas'],
    );
  });

  test('does not save local additions until the initial cart load completes',
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

    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(api.cartWrites, isEmpty);

    api.cartLoad!.complete({
      'items': [_savedItem('apples', 2)],
    });
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(cart.itemCount, 3);
    expect(api.cartWrites, hasLength(1));
    expect(
      api.cartWrites.single.map((item) => item['productId']),
      containsAll(['apples', 'bananas']),
    );
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
