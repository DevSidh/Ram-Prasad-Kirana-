import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants.dart';
import '../../core/responsive_layout.dart';
import '../../core/theme/app_theme_extension.dart';
import '../../core/widgets/app_widgets.dart';
import '../../models/product.dart';
import '../../providers/language_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/product_card.dart';

Future<void> showSearchOverlay(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close search',
    barrierColor: Colors.black.withValues(alpha: 0.24),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, _, __) => const SafeArea(
      child: Material(
        color: Colors.transparent,
        child: SearchScreen(isOverlay: true),
      ),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final eased =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: eased,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.035),
            end: Offset.zero,
          ).animate(eased),
          child: child,
        ),
      );
    },
  );
}

class SearchScreen extends StatefulWidget {
  final bool isOverlay;

  const SearchScreen({super.key, this.isOverlay = false});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _searchHistory = [];
  List<Product> _wholesaleResults = const [];
  Timer? _searchDebounce;
  bool _isDebouncing = false;
  bool _isWholesaleLoading = false;
  int _wholesaleSearchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _searchHistory =
          preferences.getStringList(AppConstants.keySearchHistory) ?? [];
    });
  }

  Future<void> _recordSearch(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;
    final history = [
      query,
      ..._searchHistory.where(
        (item) => item.toLowerCase() != query.toLowerCase(),
      ),
    ].take(10).toList();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(AppConstants.keySearchHistory, history);
      if (mounted) setState(() => _searchHistory = history);
    } catch (error) {
      _showHistoryError(error);
    }
  }

  Future<void> _removeSearchHistoryItem(String query) async {
    final history = _searchHistory.where((item) => item != query).toList();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(AppConstants.keySearchHistory, history);
      if (mounted) setState(() => _searchHistory = history);
    } catch (error) {
      _showHistoryError(error);
    }
  }

  void _showHistoryError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Could not update search history: '
          '${error.toString().replaceFirst('Exception: ', '')}',
        ),
      ),
    );
  }

  void _selectSearch(String query, ProductProvider productProvider) {
    _searchDebounce?.cancel();
    _searchController
      ..text = query
      ..selection = TextSelection.collapsed(offset: query.length);
    productProvider.setSearchQuery(query);
    setState(() => _isDebouncing = false);
    unawaited(_searchWholesaleProducts(query, productProvider));
    _recordSearch(query);
  }

  void _clearSearch(ProductProvider productProvider) {
    _searchDebounce?.cancel();
    _searchController.clear();
    productProvider.setSearchQuery('');
    _wholesaleSearchGeneration++;
    setState(() {
      _isDebouncing = false;
      _isWholesaleLoading = false;
      _wholesaleResults = const [];
    });
  }

  Future<void> _searchWholesaleProducts(
    String query,
    ProductProvider productProvider,
  ) async {
    final normalizedQuery = query.trim();
    final generation = ++_wholesaleSearchGeneration;
    if (normalizedQuery.isEmpty) {
      if (mounted) {
        setState(() {
          _isWholesaleLoading = false;
          _wholesaleResults = const [];
        });
      }
      return;
    }

    setState(() {
      _isWholesaleLoading = true;
      _wholesaleResults = const [];
    });
    try {
      final wholesaleResults =
          await productProvider.searchWholesaleProducts(normalizedQuery);
      if (!mounted || generation != _wholesaleSearchGeneration) return;
      setState(() {
        _wholesaleResults = wholesaleResults;
        _isWholesaleLoading = false;
      });
    } catch (error) {
      if (!mounted || generation != _wholesaleSearchGeneration) return;
      debugPrint('Unable to search wholesale products: $error');
      setState(() {
        _wholesaleResults = const [];
        _isWholesaleLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider?>();
    final productProvider = context.watch<ProductProvider>();
    final theme = Theme.of(context);
    final tokens = AppThemeExtension.of(context);
    final results = [
      ...productProvider.products,
      ..._wholesaleResults,
    ];
    final searchText = _searchController.text.trim();
    final isSearching = searchText.isNotEmpty;
    final suggestions = productProvider.searchSuggestions(searchText);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: widget.isOverlay
            ? IconButton(
                tooltip: context.tr('Close search'),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        title: Container(
          height: 52,
          decoration: BoxDecoration(
            color: tokens.surfaceGlass,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tokens.glassBorder),
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: context.tr('Search store items...'),
              hintStyle: TextStyle(fontSize: 14, color: tokens.textSecondary),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 21,
                color: theme.colorScheme.primary,
              ),
              suffixIcon: isSearching
                  ? IconButton(
                      tooltip: context.tr('Clear Search'),
                      icon: const Icon(Icons.clear, size: 19),
                      onPressed: () => _clearSearch(productProvider),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            autofocus: widget.isOverlay,
            textInputAction: TextInputAction.search,
            onSubmitted: (value) {
              _searchDebounce?.cancel();
              productProvider.setSearchQuery(value);
              setState(() => _isDebouncing = false);
              unawaited(_searchWholesaleProducts(value, productProvider));
              _recordSearch(value);
            },
            onChanged: (value) {
              _searchDebounce?.cancel();
              setState(() => _isDebouncing = value.trim().isNotEmpty);
              _searchDebounce = Timer(const Duration(milliseconds: 350), () {
                if (!mounted) return;
                productProvider.setSearchQuery(value);
                setState(() => _isDebouncing = false);
                unawaited(_searchWholesaleProducts(value, productProvider));
              });
            },
          ),
        ),
      ),
      body: AppBackground(
        child: !isSearching
            ? RefreshIndicator(
                onRefresh: productProvider.loadCatalog,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    if (productProvider.errorMessage != null)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverToBoxAdapter(
                          child: NoticeBanner(
                            message: productProvider.errorMessage!,
                            retryLabel: context.tr('Retry'),
                            onRetry: productProvider.loadCatalog,
                          ),
                        ),
                      ),
                    if (_searchHistory.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 128),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate(
                            [
                              SectionHeader(
                                title: context.tr('Recent searches'),
                              ),
                              for (final query in _searchHistory)
                                Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: const Icon(Icons.history_rounded),
                                    title: Text(query),
                                    onTap: () => _selectSearch(
                                      query,
                                      productProvider,
                                    ),
                                    trailing: IconButton(
                                      tooltip: context.tr(
                                        'Remove from search history',
                                      ),
                                      onPressed: () =>
                                          _removeSearchHistoryItem(query),
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(
                          icon: Icons.history_rounded,
                          title: context.tr('No recent searches'),
                          message: context.tr(
                            'Your searches will appear here.',
                          ),
                        ),
                      ),
                  ],
                ),
              )
            : Column(
                children: [
                  if (_isDebouncing || _isWholesaleLoading)
                    const LinearProgressIndicator(minHeight: 2),
                  if (suggestions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('Suggestions'),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 2,
                            children: suggestions
                                .map(
                                  (suggestion) => ActionChip(
                                    avatar: const Icon(
                                      Icons.search_rounded,
                                      size: 16,
                                    ),
                                    label: Text(suggestion),
                                    onPressed: () => _selectSearch(
                                      suggestion,
                                      productProvider,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: _isDebouncing ||
                            (_isWholesaleLoading && results.isEmpty)
                        ? const Center(child: CircularProgressIndicator())
                        : results.isEmpty
                            ? suggestions.isEmpty
                                ? EmptyState(
                                    icon: Icons.search_off_rounded,
                                    title:
                                        '${context.tr('No items found for')} "$searchText"',
                                    message: context.tr(
                                      'Check for typos or try searching for a product or category.',
                                    ),
                                    buttonText: context.tr('Clear Search'),
                                    onButtonPressed: () =>
                                        _clearSearch(productProvider),
                                  )
                                : Center(
                                    child: Text(
                                      context.tr(
                                        'Choose a suggestion to search the store.',
                                      ),
                                      style: TextStyle(
                                        color: tokens.textSecondary,
                                      ),
                                    ),
                                  )
                            : LayoutBuilder(
                                builder: (context, constraints) =>
                                    GridView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 16, 16, 128),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount:
                                        responsiveGridCrossAxisCount(
                                      availableWidth: constraints.maxWidth,
                                      horizontalPadding: 32,
                                      minTileWidth: 128,
                                    ),
                                    childAspectRatio: 0.58,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                  ),
                                  itemCount: results.length,
                                  itemBuilder: (context, index) =>
                                      ProductCard(product: results[index]),
                                ),
                              ),
                  ),
                ],
              ),
      ),
    );
  }
}
