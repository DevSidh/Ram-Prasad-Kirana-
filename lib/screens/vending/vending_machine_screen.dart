import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/responsive_layout.dart';
import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../services/api_service.dart';
import '../../screens/product/product_details_screen.dart';
import '../../widgets/product_card.dart';
import 'drinks_menu_section.dart'
    show CategoryChips, Drink, DrinkCard, drinkCategoryFor;

class VendingMachineScreen extends StatefulWidget {
  const VendingMachineScreen({super.key});

  @override
  State<VendingMachineScreen> createState() => _VendingMachineScreenState();
}

class _VendingMachineScreenState extends State<VendingMachineScreen> {
  static const _categories = <String>[
    'All',
    'Soda',
    'Tea & Coffee',
    'Energy',
  ];

  final _scrollController = ScrollController();
  List<Product> _drinks = const [];
  String _selectedCategory = 'All';
  String? _error;
  bool _loading = true;
  bool _requestInFlight = false;
  bool _observedTabVisibility = false;
  bool _wasTabVisible = true;
  DateTime? _lastLoadedAt;
  Timer? _periodicRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadDrinks();
    _periodicRefreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) {
        if (!mounted ||
            !TickerMode.valuesOf(context).enabled ||
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed) {
          return;
        }
        unawaited(_refreshIfStale());
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isVisible = TickerMode.valuesOf(context).enabled;
    if (_observedTabVisibility && isVisible && !_wasTabVisible) {
      unawaited(_loadDrinks(showLoading: false, force: true));
    } else if (isVisible && !_loading) {
      unawaited(_refreshIfStale());
    }
    _observedTabVisibility = true;
    _wasTabVisible = isVisible;
  }

  Future<void> _refreshIfStale() async {
    if (!mounted ||
        (_lastLoadedAt != null &&
            DateTime.now().difference(_lastLoadedAt!) <
                const Duration(seconds: 45))) {
      return;
    }
    await _loadDrinks(showLoading: false);
  }

  Future<void> _loadDrinks({
    bool showLoading = true,
    bool force = false,
  }) async {
    if (_requestInFlight) return;
    if (!force &&
        _lastLoadedAt != null &&
        DateTime.now().difference(_lastLoadedAt!) <
            const Duration(seconds: 45)) {
      return;
    }
    _requestInFlight = true;
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final response = await context.read<ApiService>().get(
        '/products',
        queryParams: const {
          'vendingDrink': 'true',
          'page': '1',
          'limit': '100',
        },
      );
      if (response is! Map<String, dynamic> || response['data'] is! List) {
        throw const FormatException(
          'The server returned an invalid vending drink list.',
        );
      }
      final products = (response['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map(Product.fromJson)
          .where((product) => product.isVendingDrink)
          .where((product) => drinkCategoryFor(product) != 'Hidden')
          .toList();
      if (!mounted) return;
      setState(() {
        _drinks = products.take(18).toList(growable: false);
        _loading = false;
        _error = null;
      });
      _lastLoadedAt = DateTime.now();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      _requestInFlight = false;
    }
  }

  List<Product> get _visibleDrinks {
    return _drinks
        .where(
          (product) =>
              _selectedCategory == 'All' ||
              drinkCategoryFor(product) == _selectedCategory,
        )
        .toList(growable: false);
  }

  void _openDrink(Product product) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailsScreen(product: product),
      ),
    );
  }

  @override
  void dispose() {
    _periodicRefreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drinks = _visibleDrinks;
    Product? featuredDrink;
    for (final drink in drinks) {
      if (drink.isBestSeller) {
        featuredDrink = drink;
        break;
      }
    }
    final gridDrinks = drinks;
    final media = MediaQuery.of(context);
    final textScale = media.textScaler.scale(1).clamp(1.0, 1.2).toDouble();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF101316) : Colors.white,
        body: SafeArea(
          child: CustomScrollView(
            key: const ValueKey('drinks-menu-scroll'),
            controller: _scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Drinks menu',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '${_loading && _drinks.isEmpty ? '…' : drinks.length} drinks',
                        key: const ValueKey('drinks-menu-count'),
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        key: const ValueKey('refresh-vending-drinks'),
                        tooltip: 'Refresh drinks',
                        onPressed:
                            _loading ? null : () => _loadDrinks(force: true),
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.refresh_rounded,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: CategoryChips(
                  categories: _categories,
                  selected: _selectedCategory,
                  onSelected: (category) {
                    setState(() => _selectedCategory = category);
                  },
                ),
              ),
              if (_error != null && _drinks.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _MenuMessage(
                      message: _error!,
                      actionLabel: 'Retry',
                      onAction: _loading ? null : _loadDrinks,
                    ),
                  ),
                ),
              if (_loading && _drinks.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: isDark
                          ? const Color(0xFF37DC86)
                          : const Color(0xFF176B42),
                    ),
                  ),
                )
              else if (drinks.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _MenuMessage(
                    message: _error ??
                        (_drinks.isNotEmpty
                            ? 'No drinks match this category.'
                            : 'No drinks in this category yet.'),
                    actionLabel: _error == null ? null : 'Retry',
                    onAction: _error == null ? null : _loadDrinks,
                  ),
                )
              else ...[
                if (featuredDrink != null)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(bottom: 9),
                            child: Text(
                              'Featured drink',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          DrinkCard(
                            key: ValueKey('featured-drink-${featuredDrink.id}'),
                            drink: Drink.fromProduct(featuredDrink, 0),
                            featured: true,
                            selected: false,
                            onSelect: _openDrink,
                            onAdd: (product) =>
                                context.read<CartProvider>().addItem(product),
                          ),
                        ],
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) => SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: responsiveGridCrossAxisCount(
                          availableWidth: constraints.crossAxisExtent,
                          minTileWidth: 128,
                        ),
                        mainAxisExtent: 220 * textScale,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: gridDrinks.length,
                      itemBuilder: (context, index) {
                        final product = gridDrinks[index];
                        return Stack(
                          key: ValueKey(product.id),
                          children: [
                            Positioned.fill(
                              child: ProductCard(
                                product: product,
                                compact: true,
                              ),
                            ),
                            if (product.isBestSeller)
                              Positioned(
                                top: 7,
                                left: 7,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF9A4D13),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      'FEATURED',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: .4,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuMessage extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MenuMessage({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: textColor),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
