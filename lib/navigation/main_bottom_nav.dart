import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme_extension.dart';
import '../core/widgets/app_widgets.dart';
import '../providers/language_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../screens/home/home_screen.dart';
import '../screens/vending/vending_machine_screen.dart';
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
    with WidgetsBindingObserver {
  late int _currentIndex;
  final Set<int> _visitedScreens = {0};
  final GlobalKey _cartTargetKey = GlobalKey();

  final List<Widget> _screens = const [
    HomeScreen(),
    VendingMachineScreen(),
    CategoriesScreen(),
    SearchScreen(),
    CartScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _visitedScreens.add(_currentIndex);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _currentIndex = index;
      _visitedScreens.add(index);
    });
    if (index == 0 || index == 2 || index == 3) {
      unawaited(context.read<ProductProvider>().refreshCatalogIfStale());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        key: const ValueKey('main-bottom-nav-scaffold'),
        extendBody: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(
              child: AppBackground(child: SizedBox.expand()),
            ),
            Center(
              key: const ValueKey('main-bottom-nav-body'),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: CartFlightTarget(
                  targetKey: _cartTargetKey,
                  child: IndexedStack(
                    key: const ValueKey('main-bottom-nav-pages'),
                    index: _currentIndex,
                    sizing: StackFit.expand,
                    children: [
                      for (var index = 0; index < _screens.length; index++)
                        if (_visitedScreens.contains(index))
                          TickerMode(
                            enabled: index == _currentIndex,
                            child: _KeepAlivePage(
                              key: ValueKey('nav-screen-transition-$index'),
                              child: _screens[index],
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              key: const ValueKey('transparent-nav-area'),
              left: 0,
              right: 0,
              bottom: MediaQuery.paddingOf(context).bottom + 18,
              height: 66,
              child: Center(
                child: _FloatingNavigationBar(
                  selectedIndex: _currentIndex,
                  cartTargetKey: _cartTargetKey,
                  onSelect: _selectTab,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final GlobalKey cartTargetKey;
  final ValueChanged<int> onSelect;

  const _FloatingNavigationBar({
    required this.selectedIndex,
    required this.cartTargetKey,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cartItemCount =
        context.select<CartProvider, int>((cart) => cart.itemCount);
    final navigationWidth =
        (MediaQuery.sizeOf(context).width - 8).clamp(0.0, 360.0).toDouble();
    final tokens = AppThemeExtension.of(context);
    final labels = [
      context.tr('Home'),
      context.tr('Vending'),
      context.tr('Categories'),
      context.tr('Search'),
      context.tr('Cart'),
      context.tr('Profile'),
    ];
    const icons = [
      Icons.home_outlined,
      Icons.local_drink_outlined,
      Icons.grid_view_outlined,
      Icons.search_outlined,
      Icons.shopping_cart_outlined,
      Icons.person_outline,
    ];
    const keyNames = [
      'Home',
      'Vending',
      'Categories',
      'Search',
      'Cart',
      'Profile',
    ];

    return ClipRRect(
      key: const ValueKey('floating-nav-capsule'),
      borderRadius: BorderRadius.circular(40),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 17, sigmaY: 17),
        child: Container(
          width: navigationWidth,
          height: 66,
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: tokens.navBarFill,
            border: Border.all(color: tokens.navBarBorder),
            borderRadius: BorderRadius.circular(40),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const gap = 0.0;
              final tabWidth =
                  (constraints.maxWidth - gap * (labels.length - 1)) /
                      labels.length;
              final indicatorSize = math.min(constraints.maxHeight, tabWidth);
              return SizedBox(
                height: constraints.maxHeight,
                child: Stack(
                  children: [
                    _NavigationIndicator(
                      selectedIndex: selectedIndex,
                      tabWidth: tabWidth,
                      gap: gap,
                      size: indicatorSize,
                      color: tokens.navBarActiveBackground,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var index = 0; index < labels.length; index++)
                          SizedBox(
                            width: tabWidth,
                            child: _NavigationItem(
                              segmentKey:
                                  ValueKey('nav-tab-${keyNames[index]}'),
                              label: labels[index],
                              icon: icons[index],
                              selected: selectedIndex == index,
                              activeIconColor: tokens.navBarActiveIcon,
                              inactiveIconColor: tokens.navBarInactiveIcon,
                              showBadge: index == 4,
                              badgeCount: index == 4 ? cartItemCount : 0,
                              iconTargetKey: index == 4 ? cartTargetKey : null,
                              onTap: () => onSelect(index),
                            ),
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
    );
  }
}

class _NavigationItem extends StatelessWidget {
  final Key? segmentKey;
  final String label;
  final IconData icon;
  final bool selected;
  final bool showBadge;
  final int badgeCount;
  final Color activeIconColor;
  final Color inactiveIconColor;
  final VoidCallback onTap;
  final GlobalKey? iconTargetKey;

  const _NavigationItem({
    this.segmentKey,
    required this.label,
    required this.icon,
    required this.selected,
    this.showBadge = false,
    this.badgeCount = 0,
    required this.activeIconColor,
    required this.inactiveIconColor,
    this.iconTargetKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: badgeCount > 0 ? '$label, $badgeCount' : label,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(25),
          child: SizedBox(
            key: segmentKey,
            height: 48,
            child: Center(
              child: SizedBox(
                key: iconTargetKey,
                width: 48,
                height: 48,
                child: Center(
                  child: AnimatedScale(
                    scale: selected ? 1 : 0.94,
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 150),
                    curve: Curves.easeOutCubic,
                    child: AnimatedSwitcher(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 140),
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: animation,
                        child: child,
                      ),
                      child: showBadge && badgeCount > 0
                          ? Badge(
                              key: ValueKey(
                                '${selected ? 'selected' : 'unselected'}-$badgeCount',
                              ),
                              backgroundColor: const Color(0xFFEF4444),
                              textColor: Colors.white,
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                              label: Text('$badgeCount'),
                              child: Icon(
                                selected ? _selectedIcon(icon) : icon,
                                color: selected
                                    ? activeIconColor
                                    : inactiveIconColor,
                                size: 22,
                              ),
                            )
                          : Icon(
                              selected ? _selectedIcon(icon) : icon,
                              key: ValueKey(selected),
                              color: selected
                                  ? activeIconColor
                                  : inactiveIconColor,
                              size: 22,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _selectedIcon(IconData icon) {
    if (icon == Icons.home_outlined) return Icons.home;
    if (icon == Icons.local_drink_outlined) {
      return Icons.local_drink_rounded;
    }
    if (icon == Icons.grid_view_outlined) return Icons.grid_view_rounded;
    if (icon == Icons.search_outlined) return Icons.search;
    if (icon == Icons.shopping_cart_outlined) {
      return Icons.shopping_cart_rounded;
    }
    if (icon == Icons.person_outline) return Icons.person;
    return icon;
  }
}

class _NavigationIndicator extends StatefulWidget {
  final int selectedIndex;
  final double tabWidth;
  final double gap;
  final double size;
  final Color color;

  const _NavigationIndicator({
    required this.selectedIndex,
    required this.tabWidth,
    required this.gap,
    required this.size,
    required this.color,
  });

  @override
  State<_NavigationIndicator> createState() => _NavigationIndicatorState();
}

class _NavigationIndicatorState extends State<_NavigationIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _position;

  @override
  void initState() {
    super.initState();
    _position = AnimationController.unbounded(
      vsync: this,
      value: widget.selectedIndex.toDouble(),
    );
  }

  @override
  void didUpdateWidget(covariant _NavigationIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex == widget.selectedIndex) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _position.value = widget.selectedIndex.toDouble();
      return;
    }
    _position.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 900, damping: 52),
        _position.value,
        widget.selectedIndex.toDouble(),
        _position.velocity,
      ),
    );
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _position,
        child: IgnorePointer(
          child: DecoratedBox(
            key: const ValueKey('selected-tab-indicator'),
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        ),
        builder: (context, child) => Positioned(
          left: _position.value * (widget.tabWidth + widget.gap) +
              (widget.tabWidth - widget.size) / 2,
          top: (48 - widget.size) / 2,
          width: widget.size,
          height: widget.size,
          child: child!,
        ),
      );
}

class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({super.key, required this.child});

  final Widget child;

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
