import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/category.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class ProductProvider extends ChangeNotifier {
  static const _catalogCacheKey = 'catalog_cache_v1';

  final ApiService _apiService;
  List<Product> _products = [];
  List<Category> _categories = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedCategorySlug = 'all';
  String _searchQuery = '';
  String _sortBy = 'popular';
  double _maxPrice = double.infinity;
  double _minimumRating = 0;
  bool _organicOnly = false;
  bool _favoritesOnly = false;
  final List<String> _wishlistIds = [];
  int _wishlistRevision = 0;
  bool _disposed = false;
  Future<void>? _catalogLoad;
  DateTime? _lastCatalogLoadAt;

  ProductProvider({required ApiService apiService}) : _apiService = apiService {
    unawaited(loadCatalog());
    unawaited(_loadWishlist());
  }

  List<Product> get products => _getFilteredProducts();
  List<Product> get featuredProducts =>
      _products.where((product) => product.isFeatured).toList();
  List<Product> get favoriteProducts =>
      _getFilteredProducts(onlyFavorites: true);
  List<Product> get wishlistProducts => _products
      .where((product) => _wishlistIds.contains(product.id))
      .toList(growable: false);
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
  int get favoriteCount => _wishlistIds.length;
  List<String> get wishlistIds => List.unmodifiable(_wishlistIds);
  ApiService get apiService => _apiService;

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
      _categories = categoryData
          .cast<Map<String, dynamic>>()
          .map(Category.fromJson)
          .toList(growable: false);
      _products = productsById.values.toList(growable: false);
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
      _products = productData
          .cast<Map<String, dynamic>>()
          .map(Product.fromJson)
          .toList(growable: false);
      _categories = categoryData
          .cast<Map<String, dynamic>>()
          .map(Category.fromJson)
          .toList(growable: false);
      notifyListeners();
    } catch (error, stackTrace) {
      debugPrint('Unable to restore cached product catalog: $error\n$stackTrace');
    }
  }

  Future<void> _persistCatalogCache() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _catalogCacheKey,
        jsonEncode({
          'products': _products.map((product) => product.toJson()).toList(),
          'categories': _categories.map((category) => category.toJson()).toList(),
        }),
      );
    } catch (error, stackTrace) {
      debugPrint('Unable to save cached product catalog: $error\n$stackTrace');
    }
  }

  void setFeaturedLocally(String productId, bool isFeatured) {
    _products = _products
        .map(
          (product) => product.id == productId
              ? product.copyWith(isFeatured: isFeatured)
              : product,
        )
        .toList();
    notifyListeners();
  }

  void setProductImageLocally(String productId, String? imageUrl) {
    _products = _products
        .map(
          (product) => product.id == productId
              ? product.copyWith(imageUrl: imageUrl)
              : product,
        )
        .toList();
    notifyListeners();
  }

  void setSelectedCategory(String slug) {
    _selectedCategorySlug = slug;
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
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSortBy(String sort) {
    _sortBy = sort;
    notifyListeners();
  }

  void setFilters({double? maxPrice, bool? organicOnly}) {
    if (maxPrice != null) _maxPrice = maxPrice;
    if (organicOnly != null) _organicOnly = organicOnly;
    notifyListeners();
  }

  Future<void> toggleWishlist(String productId) async {
    _wishlistRevision++;
    if (_wishlistIds.contains(productId)) {
      _wishlistIds.remove(productId);
    } else {
      _wishlistIds.add(productId);
    }
    notifyListeners();
    await _persistWishlist();
  }

  bool isWishlisted(String productId) => _wishlistIds.contains(productId);

  Future<void> _loadWishlist() async {
    final revision = _wishlistRevision;
    try {
      final preferences = await SharedPreferences.getInstance();
      if (_disposed || revision != _wishlistRevision) return;
      _wishlistIds
        ..clear()
        ..addAll(preferences.getStringList('saved_product_ids') ?? const []);
      notifyListeners();
    } catch (error, stackTrace) {
      debugPrint('Unable to load saved products: $error\n$stackTrace');
    }
  }

  Future<void> _persistWishlist() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList('saved_product_ids', _wishlistIds);
    } catch (error, stackTrace) {
      debugPrint('Unable to save favorite products: $error\n$stackTrace');
    }
  }

  void setCatalogFilters({
    double? maxPrice,
    double? minimumRating,
    bool? organicOnly,
    bool? favoritesOnly,
    String? categorySlug,
  }) {
    if (maxPrice != null) _maxPrice = maxPrice;
    if (minimumRating != null) _minimumRating = minimumRating;
    if (organicOnly != null) _organicOnly = organicOnly;
    if (favoritesOnly != null) _favoritesOnly = favoritesOnly;
    if (categorySlug != null) _selectedCategorySlug = categorySlug;
    notifyListeners();
  }

  void resetCatalogFilters() {
    _maxPrice = double.infinity;
    _minimumRating = 0;
    _organicOnly = false;
    _favoritesOnly = false;
    _selectedCategorySlug = 'all';
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  List<Product> _getFilteredProducts({bool onlyFavorites = false}) {
    var result = List<Product>.from(_products);

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      result = result
          .where(
            (product) =>
                product.name.toLowerCase().contains(query) ||
                (product.brand?.toLowerCase().contains(query) ?? false) ||
                (product.categoryName?.toLowerCase().contains(query) ??
                    false) ||
                product.description.toLowerCase().contains(query),
          )
          .toList();
    }

    if (_selectedCategorySlug != 'all') {
      result = result
          .where((product) => product.categorySlug == _selectedCategorySlug)
          .toList();
    }

    if (onlyFavorites || _favoritesOnly) {
      result =
          result.where((product) => _wishlistIds.contains(product.id)).toList();
    }

    if (_organicOnly) {
      result = result.where((product) => product.isOrganic).toList();
    }

    if (_maxPrice.isFinite) {
      result = result.where((product) => product.price <= _maxPrice).toList();
    }
    result =
        result.where((product) => product.rating >= _minimumRating).toList();

    if (_sortBy == 'price_asc') {
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

    return result;
  }
}
