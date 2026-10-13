import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freshharvest_grocery/providers/product_provider.dart';
import 'package:freshharvest_grocery/services/api_service.dart';

class _CatalogApi extends ApiService {
  int version = 0;
  int productRequestCount = 0;
  int emptyProductResponses = 0;
  bool failProductRequests = false;

  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
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
}
