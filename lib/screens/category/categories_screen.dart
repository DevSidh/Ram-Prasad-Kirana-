import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/responsive_layout.dart';
import '../../providers/product_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/language_provider.dart';
import '../product/product_list_screen.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider?>();
    final productProvider = Provider.of<ProductProvider>(context);
    final categories = productProvider.categories;

    return Scaffold(
      backgroundColor: AppConstants.backgroundLight,
      appBar: AppBar(
        title: Text(context.tr('All Grocery Aisles')),
        backgroundColor: AppConstants.backgroundLight,
      ),
      body: productProvider.isLoading && categories.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : categories.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.category_outlined,
                          color: AppConstants.primary,
                          size: 42,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          productProvider.errorMessage ??
                              'Store departments added by the administrator will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppConstants.textMuted,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: productProvider.loadCatalog,
                          child: Text(context.tr('Refresh')),
                        ),
                      ],
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) => GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: responsiveGridCrossAxisCount(
                        availableWidth: constraints.maxWidth,
                        horizontalPadding: 32,
                        minTileWidth: 136,
                      ),
                      childAspectRatio: 1.15,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return InkWell(
                        onTap: () {
                          productProvider.selectCategory(category.slug);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductListScreen(
                                  categoryName: category.name),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppConstants.surfaceLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppConstants.borderLight),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppConstants.primaryLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.storefront_outlined,
                                  color: AppConstants.primary,
                                  size: 24,
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    category.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppConstants.textDark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${category.itemCount} items',
                                    style: TextStyle(
                                      color: AppConstants.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
