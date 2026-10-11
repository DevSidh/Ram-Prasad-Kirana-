import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/responsive_layout.dart';
import '../../models/address.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/address_service.dart';
import '../../services/api_service.dart';
import '../../widgets/product_card.dart';
import '../../widgets/frosted_panel.dart';
import '../../widgets/product_thumbnail.dart';
import '../../widgets/product_quick_view.dart';
import '../../widgets/cart_flight_overlay.dart';
import '../product/product_list_screen.dart';
import '../search/search_screen.dart';
import '../profile/address_book_screen.dart';
import '../notifications/notifications_screen.dart';
import '../auth/login_screen.dart';
import '../cart/cart_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _locationTitle = 'Delivery to Home';
  String _locationSubtitle = 'Janakpur, Madhesh Province';

  Future<void> _showLocationOptions() async {
    final action = await showModalBottomSheet<_LocationAction>(
      context: context,
      showDragHandle: true,
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 360),
        reverseDuration: Duration(milliseconds: 300),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.location_on_outlined,
                  color: AppConstants.primary),
              title: const Text('Choose a saved address'),
              onTap: () => Navigator.pop(sheetContext, _LocationAction.saved),
            ),
            ListTile(
              leading: const Icon(Icons.add_location_alt_outlined,
                  color: AppConstants.primary),
              title: const Text('Add another address'),
              onTap: () =>
                  Navigator.pop(sheetContext, _LocationAction.addAddress),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case _LocationAction.saved:
        await _chooseSavedAddress();
      case _LocationAction.addAddress:
        await _addAddress();
      case null:
        break;
    }
  }

  Future<void> _chooseSavedAddress() async {
    if (context.read<AuthProvider>().currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to choose a saved address.')),
      );
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    try {
      final addresses =
          await AddressService(context.read<ApiService>()).getAddresses();
      if (!mounted) return;
      if (addresses.isEmpty) {
        await _addAddress();
        return;
      }
      final selected = await showModalBottomSheet<Object>(
        context: context,
        showDragHandle: true,
        sheetAnimationStyle: const AnimationStyle(
          duration: Duration(milliseconds: 360),
          reverseDuration: Duration(milliseconds: 300),
        ),
        builder: (sheetContext) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final address in addresses)
                ListTile(
                  leading: const Icon(Icons.location_on_outlined,
                      color: AppConstants.primary),
                  title: Text(address.title),
                  subtitle: Text(
                    '${address.street}, ${address.city}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: address.isDefault
                      ? const Icon(Icons.check_circle,
                          color: AppConstants.primary)
                      : null,
                  onTap: () => Navigator.pop(sheetContext, address),
                ),
              ListTile(
                leading: const Icon(Icons.add_location_alt_outlined),
                title: const Text('Add another address'),
                onTap: () => Navigator.pop(
                  sheetContext,
                  _LocationAction.addAddress,
                ),
              ),
            ],
          ),
        ),
      );
      if (selected is Address && mounted) {
        final preferences = await SharedPreferences.getInstance();
        await preferences.setString(
          'selected_delivery_address_id',
          selected.id,
        );
        setState(() {
          _locationTitle = 'Delivery to ${selected.title}';
          _locationSubtitle =
              '${selected.street}, ${selected.city}, ${selected.province}';
        });
      } else if (selected == _LocationAction.addAddress && mounted) {
        await _addAddress();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _addAddress() async {
    if (context.read<AuthProvider>().currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to add a delivery address.')),
      );
      return;
    }
    final address = await Navigator.push<Address>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddressBookScreen(selectionMode: true),
      ),
    );
    if (address == null || !mounted) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      'selected_delivery_address_id',
      address.id,
    );
    setState(() {
      _locationTitle = 'Delivery to ${address.title}';
      _locationSubtitle =
          '${address.street}, ${address.city}, ${address.province}';
    });
  }

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    final products = productProvider.allProducts;
    final fullName =
        context.watch<AuthProvider>().currentUser?.fullName.trim() ?? '';
    final userName = fullName.isEmpty ? 'there' : fullName.split(' ').first;
    final greeting = _timeGreeting();

    return Scaffold(
      backgroundColor: AppConstants.backgroundLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: productProvider.loadCatalog,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppConstants.primaryLight,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(
                              Icons.eco_rounded,
                              color: AppConstants.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$greeting,',
                                  style: const TextStyle(
                                    color: AppConstants.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  userName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppConstants.textDark,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    height: 1.15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            tooltip: 'Shopping basket',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppConstants.textDark,
                            ),
                            icon: Consumer<CartProvider>(
                              builder: (context, cart, _) => Badge(
                                isLabelVisible: cart.itemCount > 0,
                                label: Text('${cart.itemCount}'),
                                child:
                                    const Icon(Icons.shopping_basket_outlined),
                              ),
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CartScreen(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          IconButton.filledTonal(
                            tooltip: 'Notifications',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppConstants.textDark,
                            ),
                            icon: const Icon(Icons.notifications_none_outlined),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NotificationsScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 11),
                      InkWell(
                        onTap: _showLocationOptions,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppConstants.borderLight
                                  .withValues(alpha: 0.8),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                color: AppConstants.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _locationTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppConstants.textDark,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      _locationSubtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppConstants.textMuted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppConstants.textMuted,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Search Bar Trigger
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SearchScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: FrostedPanel(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      borderRadius: BorderRadius.circular(16),
                      opacity: 0.76,
                      blur: 16,
                      child: const Row(
                        children: [
                          Icon(Icons.search,
                              color: AppConstants.primaryDark, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Find something fresh...',
                              style: TextStyle(
                                  color: AppConstants.textMuted, fontSize: 13),
                            ),
                          ),
                          Icon(Icons.tune_rounded,
                              color: AppConstants.primary, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                if (productProvider.categories.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Shop by categories',
                            style: TextStyle(
                              color: AppConstants.textDark,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            productProvider.selectCategory('all');
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ProductListScreen(
                                  categoryName: 'All products',
                                ),
                              ),
                            );
                          },
                          child: const Text('All items'),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 54,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: productProvider.categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final category = productProvider.categories[index];
                        return ActionChip(
                          key: ValueKey(category.id),
                          avatar: const Icon(
                            Icons.storefront_outlined,
                            size: 16,
                            color: AppConstants.primary,
                          ),
                          label: Text(category.name),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          onPressed: () {
                            productProvider.selectCategory(category.slug);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProductListScreen(
                                  categoryName: category.name,
                                ),
                              ),
                            );
                          },
                          backgroundColor: Colors.white,
                          side: const BorderSide(
                            color: AppConstants.borderLight,
                          ),
                          labelStyle: const TextStyle(
                            color: AppConstants.textDark,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _FeaturedProductCarousel(
                    products: productProvider.featuredProducts,
                    isLoading: productProvider.isLoading,
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _HomeShortcut(
                        icon: Icons.favorite_rounded,
                        label: 'Saved ${productProvider.favoriteCount}',
                        onTap: () {
                          productProvider.resetCatalogFilters();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProductListScreen(
                                categoryName: 'Saved items',
                                favoritesOnly: true,
                              ),
                            ),
                          );
                        },
                      ),
                      _HomeShortcut(
                        icon: Icons.trending_up_rounded,
                        label: 'Best sellers',
                        onTap: () {
                          productProvider.resetCatalogFilters();
                          productProvider.setSortBy('best_sellers');
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProductListScreen(
                                  categoryName: 'Best sellers'),
                            ),
                          );
                        },
                      ),
                      _HomeShortcut(
                        icon: Icons.sell_outlined,
                        label: 'Cheap',
                        onTap: () {
                          productProvider.resetCatalogFilters();
                          productProvider.setSortBy('price_asc');
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProductListScreen(
                                  categoryName: 'Cheap'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    products.isEmpty ? 'Store items' : 'Available in the store',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.textDark,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (productProvider.isLoading && products.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (productProvider.errorMessage != null &&
                    products.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _CatalogMessage(
                      icon: Icons.cloud_off_outlined,
                      message: productProvider.errorMessage!,
                      action: TextButton(
                        onPressed: productProvider.loadCatalog,
                        child: const Text('Try again'),
                      ),
                    ),
                  )
                else if (products.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: _CatalogMessage(
                      icon: Icons.inventory_2_outlined,
                      message:
                          'No items yet. Products added by the administrator will appear here.',
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: LayoutBuilder(
                      builder: (context, constraints) => GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: responsiveGridCrossAxisCount(
                            availableWidth: constraints.maxWidth,
                            minTileWidth: 128,
                          ),
                          childAspectRatio: 0.58,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: products.length,
                        itemBuilder: (context, index) => ProductCard(
                          key: ValueKey(products[index].id),
                          product: products[index],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _LocationAction { saved, addAddress }

class _FeaturedProductCarousel extends StatefulWidget {
  final List<Product> products;
  final bool isLoading;

  const _FeaturedProductCarousel({
    required this.products,
    required this.isLoading,
  });

  @override
  State<_FeaturedProductCarousel> createState() =>
      _FeaturedProductCarouselState();
}

class _FeaturedProductCarouselState extends State<_FeaturedProductCarousel> {
  static const _autoAdvanceInterval = Duration(seconds: 4);

  final PageController _pageController = PageController();
  Timer? _autoAdvanceTimer;
  int _currentPage = 0;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _startAutoAdvance();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion == reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (_reduceMotion) {
      _autoAdvanceTimer?.cancel();
    } else {
      _startAutoAdvance();
    }
  }

  @override
  void didUpdateWidget(covariant _FeaturedProductCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIds = oldWidget.products.map((product) => product.id).join('|');
    final newIds = widget.products.map((product) => product.id).join('|');
    if (oldIds != newIds) {
      _currentPage = 0;
      if (_pageController.hasClients) _pageController.jumpToPage(0);
      _startAutoAdvance();
    }
  }

  void _startAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    if (widget.products.length < 2) return;
    _autoAdvanceTimer = Timer.periodic(_autoAdvanceInterval, (_) {
      _advanceToNextPage();
    });
  }

  void _advanceToNextPage() {
    if (!mounted || widget.products.length < 2 || !_pageController.hasClients) {
      return;
    }
    final current = _pageController.page?.round() ?? _currentPage;
    _showPage((current + 1) % widget.products.length);
  }

  void _showPage(int page) {
    _moveToPage(page, const Duration(milliseconds: 320), Curves.easeOutCubic);
    _startAutoAdvance();
  }

  void _moveToPage(int page, Duration duration, Curve curve) {
    if (_reduceMotion) {
      _pageController.jumpToPage(page);
    } else {
      _pageController.animateToPage(page, duration: duration, curve: curve);
    }
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 9, left: 2, right: 2),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Featured for Janakpur',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppConstants.textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (widget.products.length > 1)
                const Text(
                  'SWIPE TO EXPLORE',
                  style: TextStyle(
                    color: AppConstants.textMuted,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
            ],
          ),
        ),
        if (widget.products.isEmpty)
          _EmptyFeaturedProducts(isLoading: widget.isLoading)
        else ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final slideHeight =
                  (constraints.maxWidth * 0.54).clamp(180.0, 224.0);
              return SizedBox(
                height: slideHeight,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.products.length,
                  findChildIndexCallback: (key) {
                    if (key is! ValueKey<String>) return null;
                    final index = widget.products.indexWhere(
                      (product) => product.id == key.value,
                    );
                    return index < 0 ? null : index;
                  },
                  onPageChanged: (page) {
                    setState(() => _currentPage = page);
                    _startAutoAdvance();
                  },
                  itemBuilder: (context, index) => AnimatedBuilder(
                    key: ValueKey(widget.products[index].id),
                    animation: _pageController,
                    child: _FeaturedProductSlide(
                      product: widget.products[index],
                      onTap: () => showProductQuickView(
                        context,
                        widget.products[index],
                        cartTargetKey: CartFlightTarget.maybeOf(context),
                      ),
                      onNext: _advanceToNextPage,
                    ),
                    builder: (context, child) {
                      if (_reduceMotion) return child!;
                      final page = _pageController.hasClients
                          ? (_pageController.page ?? _currentPage.toDouble())
                          : index.toDouble();
                      final distance = (page - index).abs().clamp(0.0, 1.0);
                      return Opacity(
                        opacity: 1 - distance * 0.16,
                        child: Transform.scale(
                          scale: 1 - distance * 0.025,
                          child: child,
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          if (widget.products.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.products.length, (index) {
                  final selected = index == _currentPage;
                  return InkWell(
                    onTap: () => _showPage(index),
                    borderRadius: BorderRadius.circular(24),
                    child: SizedBox(
                      width: 32,
                      height: 40,
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: selected ? 20 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppConstants.primary
                                : AppConstants.primary.withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
        ],
      ],
    );
  }
}

class _FeaturedProductSlide extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback onNext;

  const _FeaturedProductSlide({
    required this.product,
    required this.onTap,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const baseColor = Color(0xFF15563F);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Material(
              color: baseColor,
              child: InkWell(
                onTap: onTap,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF217954), Color(0xFF0E392D)],
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: constraints.maxWidth * 0.46,
                      child: ClipRect(
                        child: ProductThumbnail(
                          imageUrl: product.imageUrl,
                          size: constraints.maxWidth * 0.46,
                          width: constraints.maxWidth * 0.46,
                          height: constraints.maxHeight,
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                    ),
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            stops: [0, 0.53, 1],
                            colors: [
                              Color(0xFF15563F),
                              Color(0xF215563F),
                              Color(0x0015563F),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 17,
                      top: 16,
                      bottom: 15,
                      width: constraints.maxWidth * 0.53,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (product.categoryName ?? 'FEATURED PICK')
                                .toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFFFD787),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              height: 1.08,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            product.weight,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 10,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Text(
                                '${AppConstants.currencySymbol}${product.price.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Material(
                        color: const Color(0xFFF4B942),
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Next featured product',
                          onPressed: onNext,
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Color(0xFF39250A),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyFeaturedProducts extends StatelessWidget {
  final bool isLoading;

  const _EmptyFeaturedProducts({required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 174,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF217954), Color(0xFF0E392D)],
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_florist_rounded,
              color: Color(0xFFFFD787), size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLoading
                      ? 'Finding today’s picks'
                      : 'Fresh picks are on their way',
                  maxLines: 2,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  isLoading
                      ? 'Loading featured products for Janakpur.'
                      : 'The store’s featured products will appear here.',
                  maxLines: 2,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeShortcut extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HomeShortcut({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: FrostedPanel(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          opacity: 0.84,
          blur: 14,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppConstants.primaryDark),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppConstants.textDark,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;

  const _CatalogMessage({
    required this.icon,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppConstants.borderLight),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppConstants.primary, size: 26),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppConstants.textMuted,
              fontSize: 12,
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
