import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/category.dart';
import '../models/product.dart';
import '../models/wholesale_item.dart';
import '../services/api_service.dart';

class ProductProvider extends ChangeNotifier {
  static const _catalogCacheKey = 'catalog_cache_v1';

  final ApiService _apiService;
  List<Product> _products = [];
  List<Category> _categories = [];
  final Map<int, List<Product>> _filteredProductViews = {};
  List<Product>? _featuredProductsCache;
  List<Product>? _wishlistProductsCache;
  List<({String value, String normalized})> _searchTerms = const [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedCategorySlug = 'all';
  String _searchQuery = '';
  String _sortBy = 'popular';
  double _maxPrice = double.infinity;
  double _minimumRating = 0;
  bool _organicOnly = false;
  bool _favoritesOnly = false;
  bool _homeBestSellersOnly = false;
  bool _homeCheapOnly = false;
  final List<String> _wishlistIds = [];
  Set<String> _wishlistIdSet = {};
  final Map<String, bool> _wishlistOverridesDuringLoad = {};
  int _wishlistRevision = 0;
  bool _disposed = false;
  bool _loadingWishlist = false;
  String? _authenticatedUserId;
  String? _wishlistErrorMessage;
  Future<void> _wishlistSyncQueue = Future<void>.value();
  Future<void>? _catalogLoad;
  DateTime? _lastCatalogLoadAt;

  ProductProvider({required ApiService apiService}) : _apiService = apiService {
    unawaited(loadCatalog());
    unawaited(_loadWishlist());
  }

  List<Product> get products => _getFilteredProducts();
  List<Product> get homeProducts =>
      _getFilteredProducts(ignoreSelectedCategory: true);
  List<Product> get featuredProducts =>
      _featuredProductsCache ??= List<Product>.unmodifiable(
        _products.where((product) => product.isFeatured),
      );
  List<Product> get favoriteProducts =>
      _getFilteredProducts(onlyFavorites: true);
  List<Product> get wishlistProducts =>
      _wishlistProductsCache ??= List<Product>.unmodifiable(
        _products.where((product) => _wishlistIdSet.contains(product.id)),
      );
  List<Product> get allProducts => List.unmodifiable(_products);
  List<Category> get categories => List.unmodifiable(_categories);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get selectedCategorySlug => _selectedCategorySlug;
  String get searchQuery => _searchQuery;
  String get sortBy => _sortBy;
  double get maxPrice => _maxPrice;
  double get minimumRating => _minimumRating;
  bool get organicOnly => _organicOnly;
  bool get favoritesOnly => _favoritesOnly;
  bool get homeBestSellersOnly => _homeBestSellersOnly;
  bool get homeCheapOnly => _homeCheapOnly;
  int get favoriteCount => _wishlistIds.length;
  List<String> get wishlistIds => List.unmodifiable(_wishlistIds);
  ApiService get apiService => _apiService;
  String? get wishlistErrorMessage => _wishlistErrorMessage;
  bool get loadingWishlist => _loadingWishlist;

  void setAuthenticatedUser(String? userId) {
    if (_authenticatedUserId == userId) return;
    _authenticatedUserId = userId;
    final revision = ++_wishlistRevision;
    _wishlistErrorMessage = null;
    _loadingWishlist = userId != null;
    _wishlistIds.clear();
    _wishlistIdSet.clear();
    _wishlistOverridesDuringLoad.clear();
    _invalidateWishlistViews();
    scheduleMicrotask(() {
      if (!_disposed) notifyListeners();
    });
    if (userId == null) {
      unawaited(_loadWishlist());
    } else {
      unawaited(_loadAccountWishlist(userId, revision));
    }
  }

  bool _isExcludedCustomerCategory(Category category) {
    final normalized = '${category.name} ${category.slug}'.toLowerCase();
    return normalized.contains('rice') ||
        normalized.contains('vegetable') ||
        normalized.contains('dairy');
  }

  Future<void> loadCatalog() async {
    final activeLoad = _catalogLoad;
    if (activeLoad != null) {
      await activeLoad;
      return;
    }
    final load = _fetchCatalog();
    _catalogLoad = load;
    try {
      await load;
    } finally {
      if (identical(_catalogLoad, load)) _catalogLoad = null;
    }
  }

  Future<void> refreshCatalogIfStale({
    Duration minimumInterval = const Duration(seconds: 45),
  }) async {
    final lastLoad = _lastCatalogLoadAt;
    if (_products.isNotEmpty &&
        lastLoad != null &&
        DateTime.now().difference(lastLoad) < minimumInterval) {
      return;
    }
    await loadCatalog();
  }

  Future<void> _fetchCatalog() async {
    if (_products.isEmpty) await _restoreCatalogCache();
    if (_disposed) return;

    _isLoading = _products.isEmpty;
    _errorMessage = null;
    notifyListeners();

    try {
      final initialResponses = await Future.wait<dynamic>([
        _apiService.get('/categories'),
        _apiService.get(
          '/products',
          queryParams: const {'page': '1', 'limit': '100'},
        ),
      ]);
      final categoriesResponse = initialResponses[0];
      if (categoriesResponse is! Map<String, dynamic> ||
          categoriesResponse['data'] is! List) {
        throw const FormatException(
            'The server returned an invalid category list.');
      }
      final categoryData = categoriesResponse['data'] as List<dynamic>;
      if (categoryData.any((item) => item is! Map<String, dynamic>)) {
        throw const FormatException(
            'The server returned an invalid category list.');
      }
      final productsById = <String, Product>{};
      var page = 1;
      var total = 0;
      dynamic productsResponse = initialResponses[1];
      while (true) {
        if (productsResponse is! Map<String, dynamic> ||
            productsResponse['data'] is! List) {
          throw const FormatException(
              'The server returned an invalid product list.');
        }
        final productData = productsResponse['data'] as List<dynamic>;
        final pagination = productsResponse['pagination'];
        if (pagination is! Map<String, dynamic>) {
          throw const FormatException(
              'The server returned invalid product pagination.');
        }
        final pageLimit = (pagination['limit'] as num?)?.toInt() ?? 0;
        final reportedTotal = pagination['total'];
        if (reportedTotal is! num || reportedTotal < 0) {
          throw const FormatException(
              'The server returned invalid product pagination.');
        }
        total = reportedTotal.toInt();
        if (pageLimit <= 0 ||
            productData.any((item) => item is! Map<String, dynamic>) ||
            (productData.isEmpty && productsById.length < total)) {
          throw const FormatException(
              'The server returned an incomplete product list.');
        }
        for (final item in productData.cast<Map<String, dynamic>>()) {
          final product = Product.fromJson(item);
          if (product.id.isEmpty) {
            throw const FormatException(
                'The server returned a product without an ID.');
          }
          productsById[product.id] = product;
        }
        if (productsById.length >= total) break;
        page++;
        productsResponse = await _apiService.get(
          '/products',
          queryParams: {'page': '$page', 'limit': '100'},
        );
      }

      if (productsById.isEmpty && _products.isNotEmpty) {
        final confirmation = await _apiService.get(
          '/products',
          queryParams: const {'page': '1', 'limit': '100'},
        );
        if (confirmation is! Map<String, dynamic> ||
            confirmation['data'] is! List ||
            (confirmation['data'] as List).isNotEmpty ||
            confirmation['pagination'] is! Map<String, dynamic> ||
            ((confirmation['pagination'] as Map<String, dynamic>)['total']
                    as num?) !=
                0) {
          throw const FormatException(
              'The server returned an unconfirmed empty product list.');
        }
      }

      if (_disposed) return;
      final categories = categoryData
          .cast<Map<String, dynamic>>()
          .map(Category.fromJson)
          .toList(growable: false);
      final excludedCategoryIds = categories
          .where(_isExcludedCustomerCategory)
          .map((category) => category.id)
          .toSet();
      _categories = categories
          .where((category) => !excludedCategoryIds.contains(category.id))
          .toList(growable: false);
      _replaceProducts(
        productsById.values
            .where(
                (product) => !excludedCategoryIds.contains(product.categoryId))
            .toList(growable: false),
      );
      _lastCatalogLoadAt = DateTime.now();
      _isLoading = false;
      notifyListeners();
      await _persistCatalogCache();
    } catch (error) {
      if (_disposed) return;
      _errorMessage = error.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _restoreCatalogCache() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final cached = preferences.getString(_catalogCacheKey);
      if (_disposed || cached == null) return;
      final decoded = jsonDecode(cached);
      if (decoded is! Map<String, dynamic> ||
          decoded['products'] is! List ||
          decoded['categories'] is! List) {
        throw const FormatException('Saved product catalog is invalid.');
      }
      final productData = decoded['products'] as List<dynamic>;
      final categoryData = decoded['categories'] as List<dynamic>;
      if (productData.any((item) => item is! Map<String, dynamic>) ||
          categoryData.any((item) => item is! Map<String, dynamic>)) {
        throw const FormatException('Saved product catalog is invalid.');
      }
      final categories = categoryData
          .cast<Map<String, dynamic>>()
          .map(Category.fromJson)
          .toList(growable: false);
      final excludedCategoryIds = categories
          .where(_isExcludedCustomerCategory)
          .map((category) => category.id)
          .toSet();
      _replaceProducts(
        productData
            .cast<Map<String, dynamic>>()
            .map(Product.fromJson)
            .where(
                (product) => !excludedCategoryIds.contains(product.categoryId))
            .toList(growable: false),
      );
      _categories = categories
          .where((category) => !excludedCategoryIds.contains(category.id))
          .toList(growable: false);
      notifyListeners();
    } catch (error, stackTrace) {
      debugPrint(
          'Unable to restore cached product catalog: $error\n$stackTrace');
    }
  }

  Future<void> _persistCatalogCache() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _catalogCacheKey,
        jsonEncode({
          'products': _products.map((product) => product.toJson()).toList(),
          'categories':
              _categories.map((category) => category.toJson()).toList(),
        }),
      );
    } catch (error, stackTrace) {
      debugPrint('Unable to save cached product catalog: $error\n$stackTrace');
    }
  }

  void setFeaturedLocally(String productId, bool isFeatured) {
    _replaceProducts(
      _products
          .map(
            (product) => product.id == productId
                ? product.copyWith(isFeatured: isFeatured)
                : product,
          )
          .toList(growable: false),
    );
    notifyListeners();
  }

  void setProductImageLocally(String productId, String? imageUrl) {
    _replaceProducts(
      _products
          .map(
            (product) => product.id == productId
                ? product.copyWith(imageUrl: imageUrl)
                : product,
          )
          .toList(growable: false),
    );
    notifyListeners();
  }

  void setSelectedCategory(String slug) {
    if (_selectedCategorySlug == slug) return;
    _selectedCategorySlug = slug;
    _invalidateFilteredProducts();
    notifyListeners();
  }

  void selectCategory(String slug) {
    _selectedCategorySlug = slug;
    _searchQuery = '';
    _sortBy = 'popular';
    _maxPrice = double.infinity;
    _minimumRating = 0;
    _organicOnly = false;
    _favoritesOnly = false;
    _homeBestSellersOnly = false;
    _homeCheapOnly = false;
    _invalidateFilteredProducts();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    _invalidateFilteredProducts();
    notifyListeners();
  }

  void setSortBy(String sort) {
    if (_sortBy == sort) return;
    _sortBy = sort;
    _invalidateFilteredProducts();
    notifyListeners();
  }

  void setHomeFilters({
    required bool savedOnly,
    required bool bestSellersOnly,
    required bool cheapOnly,
  }) {
    if (_favoritesOnly == savedOnly &&
        _homeBestSellersOnly == bestSellersOnly &&
        _homeCheapOnly == cheapOnly) {
      return;
    }
    _favoritesOnly = savedOnly;
    _homeBestSellersOnly = bestSellersOnly;
    _homeCheapOnly = cheapOnly;
    _invalidateFilteredProducts();
    notifyListeners();
  }

  void setFilters({double? maxPrice, bool? organicOnly}) {
    final nextMaxPrice = maxPrice ?? _maxPrice;
    final nextOrganicOnly = organicOnly ?? _organicOnly;
    if (_maxPrice == nextMaxPrice && _organicOnly == nextOrganicOnly) return;
    _maxPrice = nextMaxPrice;
    _organicOnly = nextOrganicOnly;
    _invalidateFilteredProducts();
    notifyListeners();
  }

  List<String> searchSuggestions(String query, {int limit = 6}) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty || limit <= 0) return const [];

    final suggestions = <String>[];
    for (final term in _searchTerms) {
      if (term.normalized.contains(normalizedQuery)) {
        suggestions.add(term.value);
        if (suggestions.length == limit) break;
      }
    }
    return suggestions;
  }

  Future<List<Product>> searchWholesaleProducts(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return const [];

    final response = await _apiService.get(
      '/wholesale',
      queryParams: {
        'search': normalizedQuery,
        'page': '1',
        'limit': '100',
      },
    );
    if (response is! Map<String, dynamic> || response['data'] is! List) {
      throw const FormatException(
        'The server returned an invalid wholesale search result.',
      );
    }

    return (response['data'] as List)
        .whereType<Map<String, dynamic>>()
        .map(WholesaleItem.fromJson)
        .map((item) => item.toProduct())
        .toList(growable: false);
  }

  void _replaceWishlistIds(Iterable<String> productIds) {
    final ids = productIds.toList(growable: false);
    _wishlistIds
      ..clear()
      ..addAll(ids);
    _wishlistIdSet = _wishlistIds.toSet();
    _invalidateWishlistViews();
  }

  Future<void> toggleWishlist(String productId) async {
    final userId = _authenticatedUserId;
    final revision = ++_wishlistRevision;
    if (_wishlistIdSet.contains(productId)) {
      _replaceWishlistIds(_wishlistIds.where((id) => id != productId));
    } else {
      _replaceWishlistIds([..._wishlistIds, productId]);
    }
    if (userId != null && _loadingWishlist) {
      _wishlistOverridesDuringLoad[productId] =
          _wishlistIdSet.contains(productId);
    }
    _wishlistErrorMessage = null;
    notifyListeners();
    try {
      if (userId == null) {
        await _persistWishlist();
      } else {
        final snapshot = List<String>.from(_wishlistIds);
        await _queueWishlistSave(userId, snapshot);
      }
    } catch (error) {
      if (revision == _wishlistRevision) {
        if (_wishlistIdSet.contains(productId)) {
          _replaceWishlistIds(_wishlistIds.where((id) => id != productId));
        } else {
          _replaceWishlistIds([..._wishlistIds, productId]);
        }
        _wishlistErrorMessage =
            error.toString().replaceFirst('Exception: ', '');
        notifyListeners();
      }
      rethrow;
    }
  }

  bool isWishlisted(String productId) => _wishlistIdSet.contains(productId);

  Future<void> _loadWishlist() async {
    final revision = _wishlistRevision;
    try {
      final preferences = await SharedPreferences.getInstance();
      if (_disposed || revision != _wishlistRevision) return;
      _replaceWishlistIds(
        preferences.getStringList('saved_product_ids') ?? const [],
      );
      notifyListeners();
    } catch (error, stackTrace) {
      debugPrint('Unable to load saved products: $error\n$stackTrace');
    }
  }

  Future<void> _loadAccountWishlist(String userId, int revision) async {
    try {
      final response = await _apiService.get('/account/wishlist');
      if (response is! Map<String, dynamic> ||
          response['productIds'] is! List ||
          (response['productIds'] as List).any((id) => id is! String)) {
        throw const FormatException(
          'The server returned an invalid saved-items list.',
        );
      }
      if (_disposed || _authenticatedUserId != userId) {
        return;
      }
      final changedDuringLoad = revision != _wishlistRevision ||
          _wishlistOverridesDuringLoad.isNotEmpty;
      final productIds =
          (response['productIds'] as List).cast<String>().toSet();
      if (changedDuringLoad) {
        for (final entry in _wishlistOverridesDuringLoad.entries) {
          if (entry.value) {
            productIds.add(entry.key);
          } else {
            productIds.remove(entry.key);
          }
        }
      }
      _replaceWishlistIds(productIds);
      _wishlistOverridesDuringLoad.clear();
      _wishlistErrorMessage = null;
      _loadingWishlist = false;
      notifyListeners();
      if (changedDuringLoad) {
        try {
          await _queueWishlistSave(userId, List<String>.from(_wishlistIds));
        } catch (error) {
          if (!_disposed && _authenticatedUserId == userId) {
            _wishlistErrorMessage =
                error.toString().replaceFirst('Exception: ', '');
            notifyListeners();
          }
        }
      }
    } catch (error) {
      if (_disposed ||
          revision != _wishlistRevision ||
          _authenticatedUserId != userId) {
        return;
      }
      _wishlistErrorMessage = error.toString().replaceFirst('Exception: ', '');
      _loadingWishlist = false;
      notifyListeners();
    }
  }

  Future<void> refreshWishlist() async {
    final userId = _authenticatedUserId;
    if (userId == null) {
      await _loadWishlist();
      return;
    }
    _loadingWishlist = true;
    _wishlistErrorMessage = null;
    notifyListeners();
    await _loadAccountWishlist(userId, _wishlistRevision);
  }

  Future<void> _queueWishlistSave(
    String userId,
    List<String> productIds,
  ) {
    Future<void> send() async {
      if (_authenticatedUserId != userId) return;
      await _apiService.put('/account/wishlist', {'productIds': productIds});
    }

    final pending = _wishlistSyncQueue.then<void>(
      (_) => send(),
      onError: (Object _, StackTrace __) => send(),
    );
    _wishlistSyncQueue = pending;
    return pending;
  }

  Future<void> _persistWishlist() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList('saved_product_ids', _wishlistIds);
    } catch (error) {
      _wishlistErrorMessage = error.toString().replaceFirst('Exception: ', '');
      debugPrint('Unable to save favorite products: $error');
      rethrow;
    }
  }

  void setCatalogFilters({
    double? maxPrice,
    double? minimumRating,
    bool? organicOnly,
    bool? favoritesOnly,
    String? categorySlug,
  }) {
    final nextMaxPrice = maxPrice ?? _maxPrice;
    final nextMinimumRating = minimumRating ?? _minimumRating;
    final nextOrganicOnly = organicOnly ?? _organicOnly;
    final nextFavoritesOnly = favoritesOnly ?? _favoritesOnly;
    final nextCategorySlug = categorySlug ?? _selectedCategorySlug;
    if (_maxPrice == nextMaxPrice &&
        _minimumRating == nextMinimumRating &&
        _organicOnly == nextOrganicOnly &&
        _favoritesOnly == nextFavoritesOnly &&
        _selectedCategorySlug == nextCategorySlug) {
      return;
    }
    _maxPrice = nextMaxPrice;
    _minimumRating = nextMinimumRating;
    _organicOnly = nextOrganicOnly;
    _favoritesOnly = nextFavoritesOnly;
    _selectedCategorySlug = nextCategorySlug;
    _invalidateFilteredProducts();
    notifyListeners();
  }

  void resetCatalogFilters() {
    if (_maxPrice == double.infinity &&
        _minimumRating == 0 &&
        !_organicOnly &&
        !_favoritesOnly &&
        !_homeBestSellersOnly &&
        !_homeCheapOnly &&
        _selectedCategorySlug == 'all') {
      return;
    }
    _maxPrice = double.infinity;
    _minimumRating = 0;
    _organicOnly = false;
    _favoritesOnly = false;
    _homeBestSellersOnly = false;
    _homeCheapOnly = false;
    _selectedCategorySlug = 'all';
    _invalidateFilteredProducts();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  List<Product> _getFilteredProducts({
    bool onlyFavorites = false,
    bool ignoreSelectedCategory = false,
  }) {
    final cacheKey = (onlyFavorites ? 2 : 0) | (ignoreSelectedCategory ? 1 : 0);
    final cached = _filteredProductViews[cacheKey];
    if (cached != null) return cached;

    final query = _searchQuery.trim().toLowerCase();
    final filterCategory =
        !ignoreSelectedCategory && _selectedCategorySlug != 'all';
    final filterFavorites = onlyFavorites || _favoritesOnly;
    final favoriteIds = filterFavorites ? _wishlistIds.toSet() : null;
    final result = <Product>[];
    for (final product in _products) {
      if (query.isNotEmpty &&
          !product.name.toLowerCase().contains(query) &&
          !(product.brand?.toLowerCase().contains(query) ?? false) &&
          !(product.categoryName?.toLowerCase().contains(query) ?? false) &&
          !product.description.toLowerCase().contains(query)) {
        continue;
      }
      if (filterCategory && product.categorySlug != _selectedCategorySlug) {
        continue;
      }
      if (favoriteIds != null && !favoriteIds.contains(product.id)) continue;
      if (_organicOnly && !product.isOrganic) continue;
      if (_homeCheapOnly && !product.isFeatured) continue;
      if (_maxPrice.isFinite && product.price > _maxPrice) continue;
      if (product.rating < _minimumRating) continue;
      result.add(product);
    }

    if (_homeCheapOnly || _sortBy == 'price_asc') {
      result.sort((a, b) => a.price.compareTo(b.price));
    } else if (_sortBy == 'price_desc') {
      result.sort((a, b) => b.price.compareTo(a.price));
    } else if (_sortBy == 'rating') {
      result.sort((a, b) => b.rating.compareTo(a.rating));
    } else if (_sortBy == 'best_sellers') {
      result.sort((a, b) => b.isBestSeller == a.isBestSeller
          ? b.reviewCount.compareTo(a.reviewCount)
          : b.isBestSeller
              ? 1
              : -1);
    } else {
      result.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
    }

    final immutableResult = List<Product>.unmodifiable(result);
    _filteredProductViews[cacheKey] = immutableResult;
    return immutableResult;
  }

  void _replaceProducts(List<Product> products) {
    _products = products;
    final seenTerms = <String>{};
    final searchTerms = <({String value, String normalized})>[];
    for (final product in products) {
      for (final value in [
        product.name,
        if (product.brand?.isNotEmpty == true) product.brand!,
        if (product.categoryName?.isNotEmpty == true) product.categoryName!,
      ]) {
        if (seenTerms.add(value)) {
          searchTerms.add(
            (value: value, normalized: value.toLowerCase()),
          );
        }
      }
    }
    _searchTerms = List.unmodifiable(searchTerms);
    _invalidateProductViews();
  }

  void _invalidateFilteredProducts() {
    _filteredProductViews.clear();
  }

  void _invalidateWishlistViews() {
    _filteredProductViews.remove(2);
    if (_favoritesOnly) {
      _filteredProductViews.remove(0);
      _filteredProductViews.remove(1);
    }
    _wishlistProductsCache = null;
  }

  void _invalidateProductViews() {
    _invalidateFilteredProducts();
    _featuredProductsCache = null;
    _wishlistProductsCache = null;
  }
}
