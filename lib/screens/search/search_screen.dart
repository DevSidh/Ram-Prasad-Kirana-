import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/responsive_layout.dart';
import '../../providers/product_provider.dart';
import '../../widgets/product_card.dart';
import '../../widgets/empty_state.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        title: Container(
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF1EB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search store items...',
              hintStyle:
                  const TextStyle(fontSize: 13, color: AppConstants.textMuted),
              prefixIcon: const Icon(Icons.search,
                  size: 20, color: AppConstants.primaryDark),
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
            onChanged: (val) {
              setState(() {});
              productProvider.setSearchQuery(val);
            },
          ),
        ),
      ),
      body: !isSearching
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Search the store',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppConstants.textDark,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Search products added by the store administrator.',
                    style: TextStyle(
                      color: AppConstants.textMuted,
                      fontSize: 13,
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
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Suggestions',
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
                                  onPressed: () {
                                    _searchController.text = suggestion;
                                    _searchController.selection =
                                        TextSelection.collapsed(
                                      offset: suggestion.length,
                                    );
                                    productProvider
                                        .setSearchQuery(suggestion);
                                    setState(() {});
                                  },
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
                                  'No items found for "${_searchController.text}"',
                              message:
                                  'Check for typos or try searching for a product or category.',
                              buttonText: 'Clear Search',
                              onButtonPressed: () {
                                _searchController.clear();
                                productProvider.setSearchQuery('');
                                setState(() {});
                              },
                            )
                          : const Center(
                              child: Text(
                                'Choose a suggestion to search the store.',
                                style: TextStyle(
                                  color: AppConstants.textMuted,
                                ),
                              ),
                            )
                      : LayoutBuilder(
                          builder: (context, constraints) =>
                              GridView.builder(
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
