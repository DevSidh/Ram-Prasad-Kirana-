import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/responsive_layout.dart';
import '../../providers/product_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/frosted_panel.dart';
import '../../widgets/product_card.dart';

class ProductListScreen extends StatelessWidget {
  final String categoryName;
  final bool favoritesOnly;

  const ProductListScreen({
    super.key,
    required this.categoryName,
    this.favoritesOnly = false,
  });

  void _showFilterModal(BuildContext context) {
    final provider = context.read<ProductProvider>();
    var localMaxPrice = provider.maxPrice.isFinite
        ? provider.maxPrice.clamp(100.0, 5000.0)
        : 5000.0;
    var hasMaximumPrice = provider.maxPrice.isFinite;
    var localMinimumRating = provider.minimumRating;
    var localOrganic = provider.organicOnly;
    var localFavorites = provider.favoritesOnly;
    var localCategory = provider.selectedCategorySlug;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x66142F24),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                child: FrostedPanel(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  borderRadius: const BorderRadius.all(Radius.circular(28)),
                  opacity: 0.94,
                  blur: 20,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.78,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Refine your basket',
                                  style: TextStyle(
                                    color: AppConstants.textDark,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Close filters',
                                onPressed: () => Navigator.pop(sheetContext),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                          const Text(
                            'DEPARTMENT',
                            style: TextStyle(
                              color: AppConstants.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _FilterChip(
                                label: 'All items',
                                selected: localCategory == 'all',
                                onSelected: () =>
                                    setSheetState(() => localCategory = 'all'),
                              ),
                              for (final category in provider.categories)
                                _FilterChip(
                                  label: category.name,
                                  selected: localCategory == category.slug,
                                  onSelected: () => setSheetState(
                                      () => localCategory = category.slug),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Maximum price',
                                  style: TextStyle(
                                    color: AppConstants.textDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                hasMaximumPrice
                                    ? 'Rs. ${localMaxPrice.toInt()}'
                                    : 'Any price',
                                style: const TextStyle(
                                  color: AppConstants.primaryDark,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Slider(
                                  value: localMaxPrice,
                                  min: 100,
                                  max: 5000,
                                  divisions: 49,
                                  activeColor: AppConstants.primary,
                                  onChanged: (value) => setSheetState(() {
                                    localMaxPrice = value;
                                    hasMaximumPrice = true;
                                  }),
                                ),
                              ),
                              TextButton(
                                onPressed: () => setSheetState(
                                    () => hasMaximumPrice = false),
                                child: const Text('Clear'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'CUSTOMER RATING',
                            style: TextStyle(
                              color: AppConstants.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Wrap(
                            spacing: 8,
                            children: [
                              _FilterChip(
                                label: 'Any',
                                selected: localMinimumRating == 0,
                                onSelected: () => setSheetState(
                                    () => localMinimumRating = 0),
                              ),
                              for (final rating in [3.0, 4.0, 4.5])
                                _FilterChip(
                                  label: '${rating.toStringAsFixed(1)}+ ★',
                                  selected: localMinimumRating == rating,
                                  onSelected: () => setSheetState(
                                      () => localMinimumRating = rating),
                                ),
                            ],
                          ),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Organic products'),
                            subtitle:
                                const Text('Show certified organic items'),
                            value: localOrganic,
                            activeTrackColor: AppConstants.primary,
                            onChanged: (value) =>
                                setSheetState(() => localOrganic = value),
                          ),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Saved items only'),
                            subtitle: const Text('Filter to your favorites'),
                            value: localFavorites,
                            activeTrackColor: AppConstants.primary,
                            onChanged: (value) =>
                                setSheetState(() => localFavorites = value),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () {
                                  provider.resetCatalogFilters();
                                  Navigator.pop(sheetContext);
                                },
                                child: const Text('Reset'),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () {
                                    provider.setCatalogFilters(
                                      maxPrice: hasMaximumPrice
                                          ? localMaxPrice
                                          : double.infinity,
                                      minimumRating: localMinimumRating,
                                      organicOnly: localOrganic,
                                      favoritesOnly: localFavorites,
                                      categorySlug: localCategory,
                                    );
                                    Navigator.pop(sheetContext);
                                  },
                                  child: const Text('Show matching items'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSortModal(BuildContext context) {
    final provider = context.read<ProductProvider>();
    const sortOptions = [
      ('popular', 'Most popular', Icons.local_fire_department_outlined),
      ('best_sellers', 'Best sellers', Icons.trending_up_rounded),
      ('rating', 'Top rated', Icons.star_outline_rounded),
      ('price_asc', 'Price: low to high', Icons.arrow_upward_rounded),
      ('price_desc', 'Price: high to low', Icons.arrow_downward_rounded),
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x66142F24),
      builder: (sheetContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: FrostedPanel(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 20),
            opacity: 0.94,
            blur: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Sort the shelf',
                    style: TextStyle(
                      color: AppConstants.textDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                for (final option in sortOptions)
                  ListTile(
                    leading: Icon(option.$3, color: AppConstants.primary),
                    title: Text(option.$2),
                    trailing: provider.sortBy == option.$1
                        ? const Icon(Icons.check_circle,
                            color: AppConstants.primary)
                        : null,
                    onTap: () {
                      provider.setSortBy(option.$1);
                      Navigator.pop(sheetContext);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final products = favoritesOnly
        ? productProvider.favoriteProducts
        : productProvider.products;

    return Scaffold(
      backgroundColor: AppConstants.backgroundLight,
      appBar: AppBar(
        title: Text(categoryName),
        backgroundColor: AppConstants.backgroundLight,
        actions: [
          IconButton(
            tooltip: 'Sort items',
            icon: const Icon(Icons.swap_vert_rounded),
            onPressed: () => _showSortModal(context),
          ),
          IconButton(
            tooltip: 'Filter items',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => _showFilterModal(context),
          ),
        ],
      ),
      body: products.isEmpty
          ? EmptyState(
              icon: productProvider.isLoading
                  ? Icons.hourglass_empty
                  : favoritesOnly
                      ? Icons.favorite_border
                      : Icons.inventory_2_outlined,
              title: productProvider.isLoading
                  ? 'Loading store items'
                  : productProvider.errorMessage != null
                      ? 'Unable to load store items'
                      : favoritesOnly
                          ? 'No saved items yet'
                          : productProvider.allProducts.isEmpty
                              ? 'No items in this store yet'
                              : 'No items match these filters',
              message: productProvider.errorMessage ??
                  (favoritesOnly
                      ? 'Tap the heart on anything you like and it will be waiting here.'
                      : productProvider.allProducts.isEmpty
                          ? 'Items added by the store administrator will appear here.'
                          : 'Try adjusting your filters or choose a different department.'),
              buttonText: productProvider.errorMessage != null
                  ? 'Try again'
                  : favoritesOnly
                      ? null
                      : 'Refresh items',
              onButtonPressed: productProvider.errorMessage != null ||
                      !favoritesOnly
                  ? productProvider.loadCatalog
                  : null,
            )
          : Column(
              children: [
                if (productProvider.favoritesOnly)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Chip(
                        avatar: Icon(Icons.favorite,
                            color: AppConstants.primary, size: 16),
                        label: Text('Saved items'),
                        backgroundColor: AppConstants.primaryLight,
                        side: BorderSide.none,
                      ),
                    ),
                  ),
                Expanded(
                  child: LayoutBuilder(
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
                      itemCount: products.length,
                      itemBuilder: (context, index) =>
                          ProductCard(product: products[index]),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
      selectedColor: AppConstants.primary,
      backgroundColor: Colors.white.withValues(alpha: 0.75),
      side: BorderSide(
        color: selected ? AppConstants.primary : AppConstants.borderLight,
      ),
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppConstants.textDark,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    );
  }
}
