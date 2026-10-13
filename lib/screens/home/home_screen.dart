import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
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
import '../../providers/theme_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/address_service.dart';
import '../../services/api_service.dart';
import '../../widgets/product_card.dart';
import '../../widgets/frosted_panel.dart';
import '../../widgets/product_thumbnail.dart';
import '../../widgets/product_quick_view.dart';
import '../../widgets/cart_flight_overlay.dart';
import '../product/product_list_screen.dart';
import '../search/search_screen.dart' show showSearchOverlay;
import '../profile/address_book_screen.dart';
import '../notifications/notifications_screen.dart';
import '../auth/login_screen.dart';
import '../cart/cart_screen.dart';
import '../wholesale/wholesale_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffset = ValueNotifier(0);
  final Map<String, GlobalKey> _categoryChipKeys = {};

  String _locationTitle = 'Delivery to Home';
  String _locationSubtitle = 'Janakpur, Madhesh Province';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    final double offset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;
    if ((offset - _scrollOffset.value).abs() >= 1) {
      _scrollOffset.value = offset;
    }
  }

  bool _snapCategoryChips(ScrollNotification notification) {
    if (notification is! ScrollEndNotification ||
        notification.metrics.axis != Axis.horizontal) {
      return false;
    }

    final viewportCenter = MediaQuery.sizeOf(context).width / 2;
    BuildContext? closestContext;
    var closestDistance = double.infinity;
    for (final key in _categoryChipKeys.values) {
      final chipContext = key.currentContext;
      final renderObject = chipContext?.findRenderObject();
      if (chipContext == null ||
          renderObject is! RenderBox ||
          !renderObject.hasSize) {
        continue;
      }
      final center = renderObject.localToGlobal(
        Offset(renderObject.size.width / 2, renderObject.size.height / 2),
      );
      final distance = (center.dx - viewportCenter).abs();
      if (distance < closestDistance) {
        closestDistance = distance;
        closestContext = chipContext;
      }
    }
    if (closestContext != null && closestDistance > 4) {
      unawaited(
        Scrollable.ensureVisible(
          closestContext,
          alignment: 0.5,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        ),
      );
    }
    return false;
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

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
        setState(() {
          _locationTitle = 'Delivery to ${selected.title}';
          _locationSubtitle =
              '${selected.street}, ${selected.city}, ${selected.province}';
        });
        final preferences = await SharedPreferences.getInstance();
        await preferences.setString(
          'selected_delivery_address_id',
          selected.id,
        );
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
    setState(() {
      _locationTitle = 'Delivery to ${address.title}';
      _locationSubtitle =
          '${address.street}, ${address.city}, ${address.province}';
    });
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      'selected_delivery_address_id',
      address.id,
    );
  }

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return context.tr('Good morning');
    if (hour < 17) return context.tr('Good afternoon');
    return context.tr('Good evening');
  }

  Widget _buildCollapsingHeader(
    String greeting,
    String userName,
    String? avatarUrl,
    String? authToken,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: ValueListenableBuilder<double>(
        valueListenable: _scrollOffset,
        builder: (context, offset, _) {
          final collapse = (offset / 80).clamp(0.0, 1.0);
          final availableWidth = MediaQuery.sizeOf(context).width - 32;
          return Column(
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: avatarUrl == null
                          ? const Icon(
                              Icons.person_rounded,
                              color: AppConstants.primary,
                              size: 24,
                            )
                          : CachedNetworkImage(
                              key: ValueKey(avatarUrl),
                              imageUrl: avatarUrl,
                              httpHeaders: {
                                if (authToken != null)
                                  'Authorization': 'Bearer $authToken',
                              },
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              memCacheWidth: 132,
                              memCacheHeight: 132,
                              placeholder: (_, __) => const Icon(
                                Icons.person_rounded,
                                color: AppConstants.primary,
                                size: 24,
                              ),
                              errorWidget: (_, __, ___) => const Icon(
                                Icons.person_rounded,
                                color: AppConstants.primary,
                                size: 24,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Opacity(
                      opacity: 1 - collapse,
                      child: Transform.translate(
                        offset: Offset(0, -12 * collapse),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$greeting,',
                              style: TextStyle(
                                color: AppConstants.textMuted,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppConstants.textDark,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Shopping basket',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      foregroundColor: AppConstants.textDark,
                    ),
                    icon: Consumer<CartProvider>(
                      builder: (context, cart, _) => Badge(
                        isLabelVisible: cart.itemCount > 0,
                        label: Text('${cart.itemCount}'),
                        child: const Icon(Icons.shopping_basket_outlined),
                      ),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CartScreen()),
                    ),
                  ),
                  const SizedBox(width: 5),
                  IconButton.filledTonal(
                    tooltip: 'Notifications',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
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
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: availableWidth * (1 - collapse * 0.22),
                  padding: EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 9 - collapse * 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: 0.07 + collapse * 0.07,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: InkWell(
                    onTap: _showLocationOptions,
                    borderRadius: BorderRadius.circular(24),
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
                                style: TextStyle(
                                  color: AppConstants.textDark,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              ClipRect(
                                child: Align(
                                  alignment: Alignment.topLeft,
                                  heightFactor: 1 - collapse,
                                  child: Opacity(
                                    opacity: 1 - collapse,
                                    child: Text(
                                      _locationSubtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppConstants.textMuted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppConstants.textMuted,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider?>();
    final productProvider = Provider.of<ProductProvider>(context);
    final products = productProvider.homeProducts;
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final fullName = user?.fullName.trim() ?? '';
    final userName = fullName.isEmpty ? 'there' : fullName.split(' ').first;
    final greeting = _timeGreeting();
    final isDarkTheme = AppConstants.isDarkTheme;

    return Scaffold(
      backgroundColor: AppConstants.homeBackgroundFor(isDarkTheme),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.3,
            colors: [
              AppConstants.homeGlowFor(isDarkTheme),
              AppConstants.homeBackgroundFor(isDarkTheme),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              RefreshIndicator(
                onRefresh: productProvider.loadCatalog,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCollapsingHeader(
                            greeting,
                            userName,
                            user?.avatarUrl,
                            auth.authToken,
                          ),

                          // Search Bar Trigger
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: InkWell(
                              onTap: () {
                                showSearchOverlay(context);
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: FrostedPanel(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                borderRadius: BorderRadius.circular(16),
                                opacity: 0.84,
                                blur: 0,
                                child: Row(
                                  children: [
                                    const Icon(Icons.search,
                                        color: AppConstants.primary, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        context.tr('Find something fresh...'),
                                        style: TextStyle(
                                            color: AppConstants.textMuted,
                                            fontSize: 13),
                                      ),
                                    ),
                                    const Icon(Icons.tune_rounded,
                                        color: AppConstants.primary, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          if (productProvider.categories.isNotEmpty) ...[
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      context.tr('Shop by categories'),
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
                                          builder: (_) =>
                                              const ProductListScreen(
                                            categoryName: 'All products',
                                          ),
                                        ),
                                      );
                                    },
                                    child: Text(context.tr('All items')),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              height: 104,
                              child: NotificationListener<ScrollNotification>(
                                onNotification: _snapCategoryChips,
                                child: ListView.separated(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: productProvider.categories.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 10),
                                  itemBuilder: (context, index) {
                                    final category =
                                        productProvider.categories[index];
                                    final selected =
                                        productProvider.selectedCategorySlug ==
                                            category.slug;
                                    final chipKey =
                                        _categoryChipKeys.putIfAbsent(
                                      category.id,
                                      GlobalKey.new,
                                    );
                                    return SizedBox(
                                      key: chipKey,
                                      width: 138,
                                      child: Material(
                                        color: selected
                                            ? AppConstants.primaryLight
                                            : AppConstants.surfaceLight,
                                        borderRadius: BorderRadius.circular(18),
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          onTap: () {
                                            productProvider
                                                .selectCategory(category.slug);
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    ProductListScreen(
                                                  categoryName: category.name,
                                                ),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              border: Border.all(
                                                color: selected
                                                    ? AppConstants.primary
                                                    : AppConstants.borderLight,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: SizedBox(
                                                    width: 56,
                                                    height: 68,
                                                    child: category.imageUrl ==
                                                                null ||
                                                            category.imageUrl!
                                                                .isEmpty
                                                        ? const ColoredBox(
                                                            color: Color(
                                                                0xFFE7EFE8),
                                                            child: Icon(
                                                              Icons
                                                                  .storefront_outlined,
                                                              color:
                                                                  AppConstants
                                                                      .primary,
                                                            ),
                                                          )
                                                        : ProductThumbnail(
                                                            imageUrl: category
                                                                .imageUrl!,
                                                            size: 56,
                                                            width: 56,
                                                            height: 68,
                                                            fit: BoxFit.cover,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .zero,
                                                          ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    category.name,
                                                    maxLines: 3,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color:
                                                          AppConstants.textDark,
                                                      fontSize: 11,
                                                      height: 1.15,
                                                      fontWeight:
                                                          FontWeight.w700,
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
                                ),
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
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _HomeShortcut(
                                    icon: Icons.favorite_rounded,
                                    label:
                                        'Saved ${productProvider.favoriteCount}',
                                    selected: productProvider.favoritesOnly,
                                    onTap: () {
                                      productProvider.setHomeFilters(
                                        savedOnly:
                                            !productProvider.favoritesOnly,
                                        bestSellersOnly:
                                            productProvider.homeBestSellersOnly,
                                        cheapOnly:
                                            productProvider.homeCheapOnly,
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _HomeShortcut(
                                    icon: Icons.trending_up_rounded,
                                    label: context.tr('Best sellers'),
                                    selected:
                                        productProvider.homeBestSellersOnly,
                                    onTap: () {
                                      productProvider.setHomeFilters(
                                        savedOnly:
                                            productProvider.favoritesOnly,
                                        bestSellersOnly: !productProvider
                                            .homeBestSellersOnly,
                                        cheapOnly: false,
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _HomeShortcut(
                                    icon: Icons.sell_outlined,
                                    label: context.tr('Cheap'),
                                    selected: productProvider.homeCheapOnly,
                                    onTap: () {
                                      productProvider.setHomeFilters(
                                        savedOnly:
                                            productProvider.favoritesOnly,
                                        bestSellersOnly: false,
                                        cheapOnly:
                                            !productProvider.homeCheapOnly,
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _HomeShortcut(
                                    icon: Icons.inventory_2_outlined,
                                    label: context.tr('Wholesale'),
                                    selected: false,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const WholesaleScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              products.isEmpty
                                  ? context.tr('Store items')
                                  : productProvider.homeCheapOnly
                                      ? context.tr('Cheap picks')
                                      : productProvider.homeBestSellersOnly
                                          ? context.tr('Best seller picks')
                                          : context
                                              .tr('Available in the store'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppConstants.textDark,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                    if (productProvider.isLoading && products.isEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(28),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      )
                    else if (productProvider.errorMessage != null &&
                        products.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _CatalogMessage(
                            icon: Icons.cloud_off_outlined,
                            message: productProvider.errorMessage!,
                            action: TextButton(
                              onPressed: productProvider.loadCatalog,
                              child: Text(context.tr('Try again')),
                            ),
                          ),
                        ),
                      )
                    else if (products.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _CatalogMessage(
                            icon: Icons.inventory_2_outlined,
                            message: context.tr(
                              'No items yet. Products added by the administrator will appear here.',
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverLayoutBuilder(
                          builder: (context, constraints) => SliverGrid.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: responsiveGridCrossAxisCount(
                                availableWidth: constraints.crossAxisExtent,
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
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 32),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 4,
                left: 16,
                right: 16,
                child: ValueListenableBuilder<double>(
                  valueListenable: _scrollOffset,
                  child: InkWell(
                    onTap: () => showSearchOverlay(context),
                    borderRadius: BorderRadius.circular(24),
                    child: FrostedPanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      borderRadius: const BorderRadius.all(Radius.circular(24)),
                      tint: Colors.white,
                      opacity: 0.94,
                      blur: 0,
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: AppConstants.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              context.tr('Find something fresh...'),
                              style: TextStyle(
                                color: AppConstants.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const Icon(Icons.tune_rounded,
                              color: AppConstants.primary, size: 18),
                        ],
                      ),
                    ),
                  ),
                  builder: (context, offset, child) {
                    final progress = ((offset - 45) / 30).clamp(0.0, 1.0);
                    return IgnorePointer(
                      ignoring: progress < 0.9,
                      child: Opacity(
                        opacity: progress,
                        child: Transform.translate(
                          offset: Offset(0, -10 * (1 - progress)),
                          child: child,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
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
  bool _tickerModeEnabled = true;

  @override
  void initState() {
    super.initState();
    _startAutoAdvance();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final tickerModeEnabled = TickerMode.valuesOf(context).enabled;
    if (_reduceMotion == reduceMotion &&
        _tickerModeEnabled == tickerModeEnabled) {
      return;
    }
    _reduceMotion = reduceMotion;
    _tickerModeEnabled = tickerModeEnabled;
    if (_reduceMotion || !_tickerModeEnabled) {
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
    if (_reduceMotion || !_tickerModeEnabled || widget.products.length < 2) {
      return;
    }
    _autoAdvanceTimer = Timer.periodic(_autoAdvanceInterval, (_) {
      _advanceToNextPage();
    });
  }

  void _advanceToNextPage() {
    if (!mounted ||
        !_tickerModeEnabled ||
        widget.products.length < 2 ||
        !_pageController.hasClients) {
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
              Expanded(
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
                Text(
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
                child: Listener(
                  onPointerDown: (_) => _autoAdvanceTimer?.cancel(),
                  onPointerUp: (_) => _startAutoAdvance(),
                  onPointerCancel: (_) => _startAutoAdvance(),
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
                    itemBuilder: (context, index) => _FeaturedProductSlide(
                      key: ValueKey(widget.products[index].id),
                      product: widget.products[index],
                      onTap: () => showProductQuickView(
                        context,
                        widget.products[index],
                        cartTargetKey: CartFlightTarget.maybeOf(context),
                      ),
                      onNext: _advanceToNextPage,
                    ),
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
                          width: selected ? 28 : 8,
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
    super.key,
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
                        child: Transform.translate(
                          offset: Offset.zero,
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
                              if (product.originalPrice != null &&
                                  product.originalPrice! > product.price) ...[
                                Text(
                                  '${AppConstants.currencySymbol}${product.originalPrice!.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.78),
                                    fontSize: 11,
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 7),
                              ],
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
  final bool selected;
  final VoidCallback onTap;

  const _HomeShortcut({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppConstants.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
          child: FrostedPanel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            borderRadius: const BorderRadius.all(Radius.circular(24)),
            tint: selected ? AppConstants.primary : Colors.white,
            opacity: selected ? 0.95 : 0.07,
            blur: 18,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  key: ValueKey(selected),
                  tween: Tween(begin: selected ? 0.72 : 1, end: 1),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) => Transform.scale(
                    scale: scale,
                    child: child,
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: selected
                        ? AppConstants.primaryForeground
                        : AppConstants.textMuted,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? AppConstants.primaryForeground
                        : AppConstants.textDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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
        color: AppConstants.surfaceLight,
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
            style: TextStyle(
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
