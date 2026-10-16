import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/responsive_layout.dart';
import '../../core/theme/app_theme_extension.dart';
import '../../core/widgets/app_widgets.dart';
import '../../models/category.dart';
import '../../providers/language_provider.dart';
import '../../providers/product_provider.dart';
import '../../screens/product/product_list_screen.dart';
import '../search/search_screen.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final categories = provider.categories;
    final tokens = AppThemeExtension.of(context);
    final totalItems =
        categories.fold<int>(0, (total, category) => total + category.itemCount);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: provider.loadCatalog,
            child: CustomScrollView(
              key: const ValueKey('categories-screen-scroll'),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('Shop by department'),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: tokens.textSecondary,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: .6,
                                    ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                context.tr('All Grocery Aisles'),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleIconButton(
                          tooltip: context.tr('Search'),
                          icon: Icons.search_rounded,
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const SearchScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      '${categories.length} ${context.tr('aisles')}  ·  $totalItems ${context.tr('items')}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: tokens.textSecondary,
                          ),
                    ),
                  ),
                ),
                if (provider.errorMessage != null && categories.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: NoticeBanner(
                        message: provider.errorMessage!,
                        retryLabel: context.tr('Retry'),
                        onRetry: provider.loadCatalog,
                        isError: true,
                      ),
                    ),
                  ),
                if (provider.isLoading && categories.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (categories.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyCategories(
                      errorMessage: provider.errorMessage,
                      onRetry: provider.loadCatalog,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 148),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final columns = responsiveGridCrossAxisCount(
                          availableWidth: constraints.crossAxisExtent,
                          horizontalPadding: 0,
                          minTileWidth: 158,
                        );
                        return SliverGrid.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            childAspectRatio: 1.02,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final category = categories[index];
                            final available = category.itemCount > 0;
                            return _CategoryCard(
                              category: category,
                              enabled: available,
                              onTap: available
                                  ? () {
                                      provider.selectCategory(category.slug);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (_) => ProductListScreen(
                                            categoryName: category.name,
                                          ),
                                        ),
                                      );
                                    }
                                  : null,
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.enabled,
    required this.onTap,
  });

  final Category category;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppThemeExtension.of(context);
    return Material(
      color: tokens.surfaceGlass,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: category.imageUrl?.isNotEmpty == true
                            ? CachedNetworkImage(
                                imageUrl: category.imageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => _CategoryIcon(
                                  category: category,
                                ),
                                errorWidget: (_, __, ___) => _CategoryIcon(
                                  category: category,
                                ),
                              )
                            : _CategoryIcon(category: category),
                      ),
                    ),
                    if (!enabled)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withValues(
                              alpha: .9,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            context.tr('Coming soon'),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: tokens.textSecondary,
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '${category.itemCount} ${context.tr(category.itemCount == 1 ? 'item' : 'items')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeExtension.of(context);
    final (icon, color) = _categoryStyle(category.name, category.slug);
    return ColoredBox(
      color: tokens.surfaceBorder.withValues(alpha: .45),
      child: Center(
        child: Icon(icon, size: 42, color: color),
      ),
    );
  }
}

class _EmptyCategories extends StatelessWidget {
  const _EmptyCategories({
    required this.errorMessage,
    required this.onRetry,
  });

  final String? errorMessage;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_outlined, size: 42),
            const SizedBox(height: 12),
            Text(
              errorMessage ??
                  context.tr(
                    'Store departments added by the administrator will appear here.',
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              child: Text(context.tr('Retry')),
            ),
          ],
        ),
      ),
    );
  }
}

(IconData, Color) _categoryStyle(String name, String slug) {
  final value = '$name $slug'.toLowerCase();
  if (value.contains('fruit') || value.contains('vegetable')) {
    return (Icons.eco_rounded, const Color(0xFF2F9E62));
  }
  if (value.contains('dairy') || value.contains('milk')) {
    return (Icons.local_drink_rounded, const Color(0xFF4C93C3));
  }
  if (value.contains('rice') ||
      value.contains('grain') ||
      value.contains('atta') ||
      value.contains('pantry')) {
    return (Icons.grain_rounded, const Color(0xFFC28A3B));
  }
  if (value.contains('masala') || value.contains('spice')) {
    return (Icons.local_fire_department_rounded, const Color(0xFFC65D42));
  }
  if (value.contains('oil') || value.contains('ghee')) {
    return (Icons.water_drop_rounded, const Color(0xFFBF9735));
  }
  if (value.contains('clean') || value.contains('detergent')) {
    return (Icons.cleaning_services_rounded, const Color(0xFF568AA5));
  }
  if (value.contains('drink') || value.contains('beverage')) {
    return (Icons.local_cafe_rounded, const Color(0xFF9270B4));
  }
  if (value.contains('snack') || value.contains('biscuit')) {
    return (Icons.bakery_dining_rounded, const Color(0xFFBD7950));
  }
  return (Icons.shopping_bag_rounded, AppConstants.primary);
}
