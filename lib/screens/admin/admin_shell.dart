import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';
import 'admin_categories_screen.dart';
import 'admin_announcements_screen.dart';
import 'admin_coupons_screen.dart';
import 'admin_customers_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_delivery_people_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_products_screen.dart';
import 'admin_restock_screen.dart';
import 'admin_showcase_screen.dart';
import 'admin_skus_screen.dart';
import 'admin_store_hours_screen.dart';
import 'admin_wholesale_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;
  late final List<Widget> _screens;

  static const _titles = [
    'Dashboard',
    'Orders',
    'Delivery',
    'Customers',
    'Announcements',
    'Products',
    'Vending drinks',
    'Wholesale',
    'Restock',
    'Categories',
    'Showcase',
    'Product SKUs',
    'Store hours',
    'Promotions',
  ];

  @override
  void initState() {
    super.initState();
    final api = context.read<ApiService>();
    _screens = [
      AdminDashboardScreen(
        api: api,
        onOrdersRequested: () {
          if (mounted) setState(() => _selectedIndex = 1);
        },
      ),
      AdminOrdersScreen(api: api),
      AdminDeliveryPeopleScreen(api: api),
      AdminCustomersScreen(api: api),
      AdminAnnouncementsScreen(api: api),
      AdminProductsScreen(api: api),
      AdminProductsScreen(api: api, vendingOnly: true),
      AdminWholesaleScreen(api: api),
      AdminRestockScreen(api: api),
      AdminCategoriesScreen(api: api),
      AdminShowcaseScreen(
        api: api,
        onFeaturedChanged: context.read<ProductProvider>().setFeaturedLocally,
        onProductImageChanged:
            context.read<ProductProvider>().setProductImageLocally,
      ),
      AdminSkusScreen(api: api),
      const AdminStoreHoursScreen(),
      AdminCouponsScreen(api: api),
    ];
  }

  Future<void> _signOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out of admin?'),
        content:
            const Text('You will need to sign in again to manage the store.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (shouldSignOut != true || !mounted) return;

    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final showSidebar = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_titles[_selectedIndex]),
            Text(
              'STORE ADMIN',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.3,
                color: AppConstants.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: showSidebar ? null : _buildAdminDrawer(),
      body: SafeArea(
        top: false,
        child: Row(
          children: [
            if (showSidebar) ...[
              NavigationRail(
                extended: true,
                minExtendedWidth: 210,
                groupAlignment: -1,
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) =>
                    setState(() => _selectedIndex = index),
                leading: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 12, 24),
                  child: Row(
                    children: [
                      const Icon(Icons.storefront_rounded,
                          color: AppConstants.primary),
                      const SizedBox(width: 10),
                      Text(
                        'STORE ADMIN',
                        style: TextStyle(
                          color: AppConstants.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                destinations: _destinations,
              ),
              const VerticalDivider(width: 1, thickness: 1),
            ],
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: [
                      for (var index = 0; index < _screens.length; index++)
                        TickerMode(
                          enabled: index == _selectedIndex,
                          child: _screens[index],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Row(
                children: [
                  const Icon(Icons.storefront_rounded,
                      color: AppConstants.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STORE ADMIN',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppConstants.textDark,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Ram Prasad General Store',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppConstants.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 10),
                itemCount: _titles.length,
                itemBuilder: (context, index) => ListTile(
                  leading: Icon(
                    index == _selectedIndex
                        ? _selectedIcons[index]
                        : _unselectedIcons[index],
                    color: index == _selectedIndex
                        ? AppConstants.primaryDark
                        : AppConstants.textMuted,
                  ),
                  title: Text(_titles[index]),
                  selected: index == _selectedIndex,
                  selectedColor: AppConstants.primaryDark,
                  selectedTileColor: AppConstants.primaryLight,
                  onTap: () {
                    setState(() => _selectedIndex = index);
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _destinations = [
    NavigationRailDestination(
      icon: Icon(Icons.space_dashboard_outlined),
      selectedIcon: Icon(Icons.space_dashboard_rounded),
      label: Text('Dashboard'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long_rounded),
      label: Text('Orders'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.local_shipping_outlined),
      selectedIcon: Icon(Icons.local_shipping_rounded),
      label: Text('Delivery'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.people_outline_rounded),
      selectedIcon: Icon(Icons.people_rounded),
      label: Text('Customers'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.campaign_outlined),
      selectedIcon: Icon(Icons.campaign_rounded),
      label: Text('Announcements'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.inventory_2_outlined),
      selectedIcon: Icon(Icons.inventory_2_rounded),
      label: Text('Products'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.local_drink_outlined),
      selectedIcon: Icon(Icons.local_drink_rounded),
      label: Text('Vending drinks'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.storefront_outlined),
      selectedIcon: Icon(Icons.storefront_rounded),
      label: Text('Wholesale'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.add_box_outlined),
      selectedIcon: Icon(Icons.add_box_rounded),
      label: Text('Restock'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.category_outlined),
      selectedIcon: Icon(Icons.category_rounded),
      label: Text('Categories'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.view_carousel_outlined),
      selectedIcon: Icon(Icons.view_carousel_rounded),
      label: Text('Showcase'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.qr_code_2_outlined),
      selectedIcon: Icon(Icons.qr_code_2_rounded),
      label: Text('Product SKUs'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.schedule_outlined),
      selectedIcon: Icon(Icons.schedule_rounded),
      label: Text('Store hours'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.local_offer_outlined),
      selectedIcon: Icon(Icons.local_offer_rounded),
      label: Text('Promotions'),
    ),
  ];

  static const _unselectedIcons = [
    Icons.space_dashboard_outlined,
    Icons.receipt_long_outlined,
    Icons.local_shipping_outlined,
    Icons.people_outline_rounded,
    Icons.campaign_outlined,
    Icons.inventory_2_outlined,
    Icons.local_drink_outlined,
    Icons.storefront_outlined,
    Icons.add_box_outlined,
    Icons.category_outlined,
    Icons.view_carousel_outlined,
    Icons.qr_code_2_outlined,
    Icons.schedule_outlined,
    Icons.local_offer_outlined,
  ];

  static const _selectedIcons = [
    Icons.space_dashboard_rounded,
    Icons.receipt_long_rounded,
    Icons.local_shipping_rounded,
    Icons.people_rounded,
    Icons.campaign_rounded,
    Icons.inventory_2_rounded,
    Icons.local_drink_rounded,
    Icons.storefront_rounded,
    Icons.add_box_rounded,
    Icons.category_rounded,
    Icons.view_carousel_rounded,
    Icons.qr_code_2_rounded,
    Icons.schedule_rounded,
    Icons.local_offer_rounded,
  ];
}
