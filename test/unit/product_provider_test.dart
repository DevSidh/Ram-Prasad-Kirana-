import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freshharvest_grocery/providers/product_provider.dart';
import 'package:freshharvest_grocery/services/api_service.dart';

class _CatalogApi extends ApiService {
  int version = 0;
  int productRequestCount = 0;
  int emptyProductResponses = 0;
  bool failProductRequests = false;
  List<String> serverWishlist = [];
  final List<List<String>> wishlistWrites = [];
  Completer<dynamic>? wishlistLoad;
  int wishlistWriteCount = 0;
  final Completer<void> twoWishlistWrites = Completer<void>();

  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    if (endpoint == '/account/wishlist') {
      if (wishlistLoad != null) return wishlistLoad!.future;
      return {'productIds': serverWishlist};
    }
    if (endpoint == '/categories') {
      return {
        'data': [
          {'id': 'cat-pantry', 'name': 'Pantry', 'slug': 'pantry'},
          {'id': 'cat-fresh', 'name': 'Fresh', 'slug': 'fresh'},
        ],
      };
    }
    productRequestCount++;
    if (failProductRequests) throw Exception('catalog unavailable');
    if (emptyProductResponses > 0) {
      emptyProductResponses--;
      return {
        'data': <Map<String, dynamic>>[],
        'pagination': {'page': 1, 'limit': 100, 'total': 0},
      };
    }
    final products = <Map<String, dynamic>>[
      {
        'id': 'rice',
        'name': 'Rice',
        'categoryId': 'cat-pantry',
        'categorySlug': 'pantry',
        'price': 120,
        'stock': 12,
        'rating': 4.6,
        'reviewCount': 21,
        'description': 'Everyday rice.',
        'weight': '1 kg',
        'isOrganic': true,
        'isBestSeller': true,
        'isFeatured': true,
        'imageUrl': 'https://cdn.example/rice.webp',
      },
      {
        'id': 'lentils',
        'name': 'Lentils',
        'categoryId': 'cat-pantry',
        'categorySlug': 'pantry',
        'price': 240,
        'stock': 8,
        'rating': 4.1,
        'reviewCount': 8,
        'description': 'Red lentils.',
        'weight': '1 kg',
      },
      {
        'id': 'greens',
        'name': 'Leafy greens',
        'categoryId': 'cat-fresh',
        'categorySlug': 'fresh',
        'price': 80,
        'stock': 5,
        'rating': 4.8,
        'reviewCount': 15,
        'description': 'Fresh greens.',
        'weight': '1 bunch',
        'isFeatured': true,
      },
      {
        'id': 'premium',
        'name': 'Premium Greens',
        'categoryId': 'cat-fresh',
        'categorySlug': 'fresh',
        'price': 3500,
        'stock': 2,
        'rating': 4.8,
        'description': 'Premium fresh greens.',
        'weight': '1 bunch',
      },
    ];
    if (version > 0) {
      products.add({
        'id': 'seasonal',
        'name': 'Seasonal fruit',
        'categoryId': 'cat-fresh',
        'categorySlug': 'fresh',
        'price': 100,
        'stock': 5,
        'rating': 4.5,
        'reviewCount': 2,
        'description': 'New seasonal fruit.',
        'weight': '1 kg',
      });
    }
    return {
      'data': products,
      'pagination': {
        'page': 1,
        'limit': 100,
        'total': products.length,
      },
    };
  }

  @override
  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    if (endpoint == '/account/wishlist') {
      serverWishlist = List<String>.from(body['productIds'] as List);
      wishlistWrites.add(serverWishlist);
      wishlistWriteCount++;
      if (wishlistWriteCount == 2 && !twoWishlistWrites.isCompleted) {
        twoWishlistWrites.complete();
      }
      return null;
    }
    return super.put(endpoint, body);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('catalog filters, sort, and saved products work together', () async {
    final provider = ProductProvider(apiService: _CatalogApi());
    await provider.loadCatalog();

    expect(provider.allProducts, hasLength(4));
    expect(provider.products.map((product) => product.id), contains('premium'));
    expect(
      provider.featuredProducts.map((product) => product.id),
      ['rice', 'greens'],
    );

    provider.setCatalogFilters(
      categorySlug: 'pantry',
      maxPrice: 200,
      minimumRating: 4.5,
      organicOnly: true,
    );
    expect(provider.products.map((product) => product.id), ['rice']);

    await provider.toggleWishlist('rice');
    provider.setCatalogFilters(favoritesOnly: true);
    expect(provider.products.map((product) => product.id), ['rice']);

    await provider.toggleWishlist('lentils');
    provider.setCatalogFilters(
      categorySlug: 'pantry',
      maxPrice: 300,
      minimumRating: 0,
      organicOnly: false,
      favoritesOnly: false,
    );
    provider.setSortBy('best_sellers');
    expect(
      provider.products.map((product) => product.id).toList(),
      ['rice', 'lentils'],
    );
    expect(provider.favoriteProducts.map((product) => product.id).toList(),
        ['rice', 'lentils']);

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getStringList('saved_product_ids'),
      containsAll(['rice', 'lentils']),
    );

    provider.resetCatalogFilters();
    expect(provider.products, hasLength(4));
    provider.dispose();
  });

  test(
      'catalog views and suggestion terms are reused until their inputs change',
      () async {
    final provider = ProductProvider(apiService: _CatalogApi());
    await provider.loadCatalog();

    final products = provider.products;
    final homeProducts = provider.homeProducts;
    expect(identical(products, provider.products), isTrue);
    expect(identical(homeProducts, provider.homeProducts), isTrue);
    expect(
      provider.searchSuggestions('GREEN'),
      ['Leafy greens', 'Premium Greens'],
    );

    await provider.toggleWishlist('rice');
    expect(identical(homeProducts, provider.homeProducts), isTrue);

    provider.setSearchQuery('rice');
    expect(identical(products, provider.products), isFalse);
    expect(provider.products.map((product) => product.id), ['rice']);

    provider.setHomeFilters(
      savedOnly: true,
      bestSellersOnly: false,
      cheapOnly: false,
    );
    expect(provider.homeProducts.map((product) => product.id), ['rice']);
    await provider.toggleWishlist('rice');
    expect(provider.wishlistIds, isEmpty);
    expect(provider.homeProducts, isEmpty);
    provider.dispose();
  });

  test('best sellers show the catalog and cheap shows carousel products',
      () async {
    final provider = ProductProvider(apiService: _CatalogApi());
    await provider.loadCatalog();
    await provider.toggleWishlist('rice');
    await provider.toggleWishlist('greens');

    provider.setHomeFilters(
      savedOnly: true,
      bestSellersOnly: false,
      cheapOnly: false,
    );
    expect(provider.products.map((product) => product.id), ['rice', 'greens']);

    provider.setHomeFilters(
      savedOnly: false,
      bestSellersOnly: true,
      cheapOnly: false,
    );
    expect(
      provider.products.map((product) => product.id),
      ['rice', 'greens', 'lentils', 'premium'],
    );

    provider.setHomeFilters(
      savedOnly: false,
      bestSellersOnly: false,
      cheapOnly: true,
    );
    expect(
      provider.products.map((product) => product.id),
      ['greens', 'rice'],
    );
    provider.dispose();
  });

  test('catalog refresh picks up admin changes without replacing cached items',
      () async {
    final api = _CatalogApi();
    final provider = ProductProvider(apiService: api);
    await provider.loadCatalog();
    expect(provider.allProducts, hasLength(4));

    await provider.refreshCatalogIfStale();
    expect(api.productRequestCount, 1);

    api.version = 1;
    await provider.refreshCatalogIfStale(minimumInterval: Duration.zero);

    expect(api.productRequestCount, 2);
    expect(provider.allProducts, hasLength(5));
    expect(provider.allProducts.map((product) => product.id),
        contains('seasonal'));
    provider.dispose();
  });

  test('catalog survives a transient API error and an unconfirmed empty list',
      () async {
    final api = _CatalogApi();
    final provider = ProductProvider(apiService: api);
    await provider.loadCatalog();
    final originalIds =
        provider.allProducts.map((product) => product.id).toList();

    api.failProductRequests = true;
    await provider.loadCatalog();
    expect(provider.allProducts.map((product) => product.id), originalIds);
    expect(provider.errorMessage, isNotNull);

    api
      ..failProductRequests = false
      ..emptyProductResponses = 1;
    await provider.loadCatalog();

    expect(provider.allProducts.map((product) => product.id), originalIds);
    expect(provider.errorMessage, contains('unconfirmed empty'));
    provider.dispose();
  });

  test('cached products and image URLs remain visible when startup is offline',
      () async {
    final firstProvider = ProductProvider(apiService: _CatalogApi());
    await firstProvider.loadCatalog();
    firstProvider.dispose();

    final offlineApi = _CatalogApi()..failProductRequests = true;
    final offlineProvider = ProductProvider(apiService: offlineApi);
    await offlineProvider.loadCatalog();

    expect(offlineProvider.allProducts, isNotEmpty);
    expect(offlineProvider.allProducts.first.imageUrl,
        'https://cdn.example/rice.webp');
    expect(offlineProvider.errorMessage, isNotNull);
    offlineProvider.dispose();
  });

  test('offline catalog cache hides excluded category products', () async {
    SharedPreferences.setMockInitialValues({
      'catalog_cache_v1': '''
{
  "categories": [
    {"id": "cat-produce", "name": "Fruits & Vegetables", "slug": "fruit-vegetables"},
    {"id": "cat-dairy", "name": "Dairy & Eggs", "slug": "dairy-eggs"},
    {"id": "cat-fruit", "name": "Fruit", "slug": "fruit"}
  ],
  "products": [
    {"id": "vegetable", "name": "Greens", "categoryId": "cat-produce", "price": 80, "weight": "1 bunch", "stock": 5, "description": "", "imageUrl": ""},
    {"id": "dairy", "name": "Milk", "categoryId": "cat-dairy", "price": 150, "weight": "1 L", "stock": 5, "description": "", "imageUrl": ""},
    {"id": "fruit", "name": "Apples", "categoryId": "cat-fruit", "price": 200, "weight": "1 kg", "stock": 5, "description": "", "imageUrl": ""}
  ]
}
''',
    });
    final offlineApi = _CatalogApi()..failProductRequests = true;
    final provider = ProductProvider(apiService: offlineApi);
    await provider.loadCatalog();

    expect(provider.categories.map((category) => category.id), ['cat-fruit']);
    expect(provider.allProducts.map((product) => product.id), ['fruit']);
    provider.dispose();
  });

  test('cheap catalog sorting includes products created by admin', () async {
    final api = _CatalogApi()..version = 1;
    final provider = ProductProvider(apiService: api);
    await provider.loadCatalog();

    provider
      ..resetCatalogFilters()
      ..setSearchQuery('')
      ..setSortBy('price_asc');

    expect(provider.products.first.id, 'greens');
    expect(
        provider.products.map((product) => product.id), contains('seasonal'));
    provider.dispose();
  });

  test('choosing an aisle clears filters that could hide its products',
      () async {
    final provider = ProductProvider(apiService: _CatalogApi());
    await provider.loadCatalog();
    provider.setCatalogFilters(
      categorySlug: 'pantry',
      maxPrice: 150,
      minimumRating: 4.5,
      organicOnly: true,
      favoritesOnly: true,
    );
    provider.setSearchQuery('not in the catalog');
    provider.setSortBy('price_desc');

    provider.selectCategory('fresh');

    expect(provider.selectedCategorySlug, 'fresh');
    expect(provider.searchQuery, isEmpty);
    expect(provider.sortBy, 'popular');
    expect(
      provider.products.map((product) => product.id),
      ['greens', 'premium'],
    );
    provider.dispose();
  });

  test('showcase selection updates featured products immediately', () async {
    final provider = ProductProvider(apiService: _CatalogApi());
    await provider.loadCatalog();

    provider.setFeaturedLocally('lentils', true);
    expect(
      provider.featuredProducts.map((product) => product.id),
      ['rice', 'lentils', 'greens'],
    );

    provider.setFeaturedLocally('rice', false);
    expect(
      provider.featuredProducts.map((product) => product.id),
      ['lentils', 'greens'],
    );
    provider.dispose();
  });

  test('signed-in saved items load and sync separately per account', () async {
    final api = _CatalogApi()..serverWishlist = ['rice'];
    final provider = ProductProvider(apiService: api);
    await provider.loadCatalog();

    provider.setAuthenticatedUser('customer-1');
    await provider.refreshWishlist();
    expect(provider.wishlistIds, ['rice']);

    await provider.toggleWishlist('lentils');
    expect(api.wishlistWrites.last, ['rice', 'lentils']);

    api.serverWishlist = ['greens'];
    provider.setAuthenticatedUser('customer-2');
    await provider.refreshWishlist();
    expect(provider.wishlistIds, ['greens']);
    provider.dispose();
  });

  test('saved-item edits during account load merge with server items',
      () async {
    final api = _CatalogApi()..wishlistLoad = Completer<dynamic>();
    final provider = ProductProvider(apiService: api);
    await provider.loadCatalog();
    provider.setAuthenticatedUser('customer-1');

    await provider.toggleWishlist('lentils');
    api.wishlistLoad!.complete({
      'productIds': ['rice'],
    });
    await api.twoWishlistWrites.future;

    expect(provider.wishlistIds, containsAll(['rice', 'lentils']));
    expect(api.serverWishlist, containsAll(['rice', 'lentils']));
    provider.dispose();
  });
}
