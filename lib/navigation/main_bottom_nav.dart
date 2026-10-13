import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../providers/language_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/home/home_screen.dart';
import '../screens/category/categories_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/cart/cart_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../widgets/cart_flight_overlay.dart';

class MainBottomNav extends StatefulWidget {
  final int initialIndex;
  const MainBottomNav({super.key, this.initialIndex = 0});

  @override
  State<MainBottomNav> createState() => _MainBottomNavState();
}

class _MainBottomNavState extends State<MainBottomNav>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late int _currentIndex;
  late final AnimationController _tabTransition;
  final Set<int> _visitedScreens = {0};
  bool _navVisible = true;
  Timer? _navIdleTimer;
  int _transitionFrom = 0;
  final GlobalKey _cartTargetKey = GlobalKey();

  final List<Widget> _screens = const [
    HomeScreen(),
    CategoriesScreen(),
    SearchScreen(),
    CartScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _transitionFrom = _currentIndex;
    _visitedScreens.add(_currentIndex);
    _tabTransition = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      value: 1,
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabTransition.dispose();
    _navIdleTimer?.cancel();
    super.dispose();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification is ScrollStartNotification) {
      _navIdleTimer?.cancel();
    } else if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      if (delta > 1) {
        _hideNavigationUntilIdle();
      } else if (delta < -1) {
        _showNavigation();
      }
    } else if (notification is ScrollEndNotification && !_navVisible) {
      _navIdleTimer?.cancel();
      _navIdleTimer = Timer(const Duration(milliseconds: 600), _showNavigation);
    }
    return false;
  }

  void _hideNavigationUntilIdle() {
    _navIdleTimer?.cancel();
    if (_navVisible) setState(() => _navVisible = false);
    _navIdleTimer = Timer(const Duration(milliseconds: 600), _showNavigation);
  }

  void _showNavigation() {
    _navIdleTimer?.cancel();
    if (mounted && !_navVisible) setState(() => _navVisible = true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted && state == AppLifecycleState.resumed) {
      unawaited(context.read<ProductProvider>().refreshCatalogIfStale());
    }
  }

  void _selectTab(int index) {
    if (index == _currentIndex || index < 0 || index >= _screens.length) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    setState(() {
      _transitionFrom = _currentIndex;
      _currentIndex = index;
      _visitedScreens.add(index);
    });
    if (reducedMotion) {
      _tabTransition.value = 1;
      _transitionFrom = index;
    } else {
      _tabTransition.forward(from: 0);
    }
    if (index == 0 || index == 1 || index == 2) {
      unawaited(context.read<ProductProvider>().refreshCatalogIfStale());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartItemCount = context.watch<CartProvider>().itemCount;
    final themeProvider = context.watch<ThemeProvider?>();
    final isDark = themeProvider?.isDarkMode ?? AppConstants.isDarkTheme;

    return Scaffold(
      key: const ValueKey('main-bottom-nav-scaffold'),
      extendBody: true,
      backgroundColor: AppConstants.backgroundLight,
      body: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: CartFlightTarget(
              targetKey: _cartTargetKey,
              child: AnimatedBuilder(
                animation: _tabTransition,
                builder: (context, _) => LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final progress =
                        Curves.easeInOutCubic.transform(_tabTransition.value);
                    return ClipRect(
                      child: Stack(
                        children: [
                          for (final index in _visitedScreens)
                            Positioned(
                              left: _screenOffset(index, width, progress),
                              top: 0,
                              bottom: 0,
                              width: width,
                              child: TickerMode(
                                enabled: index == _currentIndex ||
                                    (index == _transitionFrom &&
                                        _tabTransition.isAnimating),
                                child: _KeepAlivePage(child: _screens[index]),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarContrastEnforced: false,
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              );
              return FadeTransition(
                opacity: curved,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.08),
                    end: Offset.zero,
                  ).animate(curved),
                  child: child,
                ),
              );
            },
            child: _navVisible
                ? SafeArea(
                    key: const ValueKey('floating-nav-visible'),
                    top: false,
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xF2171A18)
                                : const Color(0xF2F9FBF9),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: .18)
                                  : AppConstants.borderLight
                                      .withValues(alpha: .72),
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                                final tabWidth = constraints.maxWidth / 5;
                                return SizedBox(
                                  height: 52,
                                  child: Stack(
                                    children: [
                                      AnimatedPositioned(
                                        duration:
                                            const Duration(milliseconds: 240),
                                        curve: Curves.easeOutCubic,
                                        left: _currentIndex * tabWidth + 2,
                                        top: 0,
                                        bottom: 0,
                                        width: tabWidth - 4,
                                        child: IgnorePointer(
                                          child: DecoratedBox(
                                            key: const ValueKey(
                                              'selected-tab-indicator',
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppConstants.primary,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          _NavigationItem(
                                            segmentKey:
                                                const ValueKey('nav-tab-Home'),
                                            label: context.tr('Home'),
                                            icon: Icons.home_outlined,
                                            selected: _currentIndex == 0,
                                            onTap: () => _selectTab(0),
                                          ),
                                          _NavigationItem(
                                            segmentKey: const ValueKey(
                                              'nav-tab-Categories',
                                            ),
                                            label: context.tr('Categories'),
                                            icon: Icons.grid_view_outlined,
                                            selected: _currentIndex == 1,
                                            onTap: () => _selectTab(1),
                                          ),
                                          _NavigationItem(
                                            segmentKey: const ValueKey(
                                                'nav-tab-Search'),
                                            label: context.tr('Search'),
                                            icon: Icons.search_outlined,
                                            selected: _currentIndex == 2,
                                            onTap: () => _selectTab(2),
                                          ),
                                          _NavigationItem(
                                            segmentKey:
                                                const ValueKey('nav-tab-Cart'),
                                            label: context.tr('Cart'),
                                            icon: Icons.shopping_cart_outlined,
                                            selected: _currentIndex == 3,
                                            badgeCount: cartItemCount,
                                            iconTargetKey: _cartTargetKey,
                                            onTap: () => _selectTab(3),
                                          ),
                                          _NavigationItem(
                                            segmentKey: const ValueKey(
                                              'nav-tab-Profile',
                                            ),
                                            label: context.tr('Profile'),
                                            icon: Icons.person_outline,
                                            selected: _currentIndex == 4,
                                            onTap: () => _selectTab(4),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                            },
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(
                    key: ValueKey('floating-nav-hidden'),
                  ),
          ),
        ),
      ),
    );
  }

  double _screenOffset(int index, double width, double progress) {
    if (_transitionFrom == _currentIndex) {
      if (index == _currentIndex) return 0;
      return index < _currentIndex ? -width : width;
    }

    final direction = _currentIndex > _transitionFrom ? 1.0 : -1.0;
    if (index == _transitionFrom) return -direction * width * progress;
    if (index == _currentIndex) return direction * width * (1 - progress);
    return index < _currentIndex ? -width : width;
  }
}

class _NavigationItem extends StatelessWidget {
  final Key? segmentKey;
  final String label;
  final IconData icon;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;
  final GlobalKey? iconTargetKey;

  const _NavigationItem({
    this.segmentKey,
    required this.label,
    required this.icon,
    required this.selected,
    this.badgeCount = 0,
    this.iconTargetKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: badgeCount > 0 ? '$label, $badgeCount items' : label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            key: segmentKey,
            height: 52,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 22,
                    key: iconTargetKey,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 180),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(
                          scale: animation,
                          child: child,
                        ),
                        child: badgeCount > 0 && label == 'Cart'
                            ? Badge(
                                key: ValueKey(
                                  '${selected ? 'selected' : 'unselected'}-$badgeCount',
                                ),
                                label: Text('$badgeCount'),
                                child: Icon(
                                  selected ? _selectedIcon(icon) : icon,
                                  color: selected
                                      ? AppConstants.primaryForeground
                                      : AppConstants.textMuted,
                                  size: 22,
                                ),
                              )
                            : Icon(
                                selected ? _selectedIcon(icon) : icon,
                                key: ValueKey(selected),
                                color: selected
                                    ? Colors.white
                                    : AppConstants.textMuted,
                                size: 22,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? AppConstants.primaryForeground
                          : AppConstants.textMuted,
                      fontSize: 9,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _selectedIcon(IconData icon) {
    if (icon == Icons.home_outlined) return Icons.home;
    if (icon == Icons.grid_view_outlined) return Icons.grid_view_rounded;
    if (icon == Icons.search_outlined) return Icons.search;
    if (icon == Icons.shopping_cart_outlined) {
      return Icons.shopping_cart_rounded;
    }
    if (icon == Icons.person_outline) return Icons.person;
    return icon;
  }
}

class _KeepAlivePage extends StatefulWidget {
  final Widget child;

  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
