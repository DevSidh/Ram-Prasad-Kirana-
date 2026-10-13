import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/responsive_layout.dart';
import '../../providers/product_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/product_card.dart';
import '../../widgets/empty_state.dart';

Future<void> showSearchOverlay(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close search',
    barrierColor: Colors.black.withValues(alpha: 0.24),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, _, __) => SafeArea(
      child: Material(
        color: AppConstants.backgroundLight,
        child: const SearchScreen(isOverlay: true),
      ),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final eased = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
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

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
  }

  @override
  void dispose() {
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
    _searchController
      ..text = query
      ..selection = TextSelection.collapsed(offset: query.length);
    productProvider.setSearchQuery(query);
    setState(() {});
    _recordSearch(query);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider?>();
    final productProvider = Provider.of<ProductProvider>(context);
    final results = productProvider.products;
    final isSearching = _searchController.text.trim().isNotEmpty;
    final query = _searchController.text.trim().toLowerCase();
    final suggestions = query.isEmpty
        ? <String>[]
        : productProvider.allProducts
            .expand((product) => [
                  product.name,
                  if (product.brand?.isNotEmpty == true) product.brand!,
                  if (product.categoryName?.isNotEmpty == true)
                    product.categoryName!,
                ])
            .where((keyword) => keyword.toLowerCase().contains(query))
            .toSet()
            .take(6)
            .toList();

    return Scaffold(
      backgroundColor: AppConstants.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppConstants.backgroundLight,
        leading: widget.isOverlay
            ? IconButton(
                tooltip: context.tr('Close search'),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        title: Container(
          height: 44,
          decoration: BoxDecoration(
            color: AppConstants.surfaceLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: context.tr('Search store items...'),
              hintStyle: TextStyle(fontSize: 13, color: AppConstants.textMuted),
              prefixIcon:
                  Icon(Icons.search, size: 20, color: AppConstants.primaryDark),
              suffixIcon: isSearching
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        productProvider.setSearchQuery('');
                        setState(() {});
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            autofocus: widget.isOverlay,
            textInputAction: TextInputAction.search,
            onSubmitted: _recordSearch,
            onChanged: (val) {
              setState(() {});
              productProvider.setSearchQuery(val);
            },
          ),
        ),
      ),
      body: !isSearching
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _searchHistory.isEmpty
                        ? context.tr('Search the store')
                        : context.tr('Recent searches'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppConstants.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_searchHistory.isEmpty)
                    Text(
                      context.tr(
                        'Search products added by the store administrator.',
                      ),
                      style: TextStyle(
                        color: AppConstants.textMuted,
                        fontSize: 13,
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: _searchHistory.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final query = _searchHistory[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.history_rounded,
                              color: AppConstants.textMuted,
                            ),
                            title: Text(query),
                            onTap: () => _selectSearch(query, productProvider),
                            trailing: IconButton(
                              tooltip: 'Remove $query from search history',
                              icon: const Icon(Icons.close_rounded, size: 19),
                              onPressed: () => _removeSearchHistoryItem(query),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            )
          : Column(
              children: [
                if (suggestions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            context.tr('Suggestions'),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppConstants.textDark,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 2,
                          children: suggestions
                              .map(
                                (suggestion) => ActionChip(
                                  avatar: const Icon(Icons.search, size: 16),
                                  label: Text(suggestion),
                                  onPressed: () => _selectSearch(
                                      suggestion, productProvider),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: results.isEmpty
                      ? suggestions.isEmpty
                          ? EmptyState(
                              icon: Icons.search_off,
                              title:
                                  '${context.tr('No items found for')} "${_searchController.text}"',
                              message: context.tr(
                                'Check for typos or try searching for a product or category.',
                              ),
                              buttonText: context.tr('Clear Search'),
                              onButtonPressed: () {
                                _searchController.clear();
                                productProvider.setSearchQuery('');
                                setState(() {});
                              },
                            )
                          : Center(
                              child: Text(
                                context.tr(
                                  'Choose a suggestion to search the store.',
                                ),
                                style: TextStyle(
                                  color: AppConstants.textMuted,
                                ),
                              ),
                            )
                      : LayoutBuilder(
                          builder: (context, constraints) => GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: responsiveGridCrossAxisCount(
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
    );
  }
}
