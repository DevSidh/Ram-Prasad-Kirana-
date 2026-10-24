import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';
import 'admin_categories_screen.dart';
import 'admin_announcements_screen.dart';
import 'admin_billing_screen.dart';
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
import 'admin_streak_screen.dart';
import 'admin_wholesale_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, this.isBillingStaff = false});

  final bool isBillingStaff;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

enum _BillingAction { section, newBill, barcode, profile }

class _BillingModule {
  const _BillingModule(
    this.title,
    this.icon,
    this.selectedIcon, {
    this.action = _BillingAction.section,
    this.section,
  });

  final String title;
  final IconData icon;
  final IconData selectedIcon;
  final _BillingAction action;
  final AdminBillingSection? section;
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;
  late final List<Widget> _screens;
  final _billingKey = GlobalKey<AdminBillingScreenState>();

  static const _titles = [
    'Dashboard',
    'Orders',
    'Delivery',
    'Customers',
    'Announcements',
    'Products',
    'Drinks',
    'Wholesale',
    'Restock',
    'Categories',
    'Showcase',
    'Product SKUs',
    'Store hours',
    'Buying streak',
    'Promotions',
    'Billing',
  ];

  @override
  void initState() {
    super.initState();
    final api = context.read<ApiService>();
    _screens = widget.isBillingStaff
        ? [
            AdminBillingScreen(
              key: _billingKey,
              api: api,
              isBillingStaff: true,
            ),
          ]
        : [
            AdminDashboardScreen(
              api: api,
              onOrdersRequested: () {
                if (mounted) _selectIndex(1);
              },
            ),
            AdminOrdersScreen(api: api, isActive: true),
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
              onFeaturedChanged:
                  context.read<ProductProvider>().setFeaturedLocally,
              onProductImageChanged:
                  context.read<ProductProvider>().setProductImageLocally,
            ),
            AdminSkusScreen(api: api),
            const AdminStoreHoursScreen(),
            AdminStreakScreen(api: api),
            AdminCouponsScreen(api: api),
            AdminBillingScreen(key: _billingKey, api: api),
          ];
  }

  void _selectIndex(int index) {
    setState(() {
      _selectedIndex = index;
    });
    final moduleIndex = widget.isBillingStaff
        ? index
        : index >= _titles.length
            ? index - _titles.length + 1
            : null;
    if (moduleIndex == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final modules =
          widget.isBillingStaff ? _billingStaffModules : _billingModules;
      final module = modules[moduleIndex];
      switch (module.action) {
        case _BillingAction.newBill:
          _billingKey.currentState?.startNewBill();
          break;
        case _BillingAction.barcode:
          _billingKey.currentState?.openBarcodeScanner();
          break;
        case _BillingAction.profile:
          _showProfile();
          break;
        case _BillingAction.section:
          final section = module.section;
          if (section != null) {
            _billingKey.currentState?.activateSection(section);
          }
          break;
      }
    });
  }

  Future<void> _showProfile() async {
    final user = context.read<AuthProvider>().currentUser;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('My profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user?.fullName ?? 'Store staff',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (user?.email.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(user!.email),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _signOut();
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          widget.isBillingStaff
              ? 'Sign out of the billing counter?'
              : 'Sign out of admin?',
        ),
        content: Text(
          widget.isBillingStaff
              ? 'You will need to sign in again to continue billing.'
              : 'You will need to sign in again to manage the store.',
        ),
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
      MaterialPageRoute(
        builder: (_) => widget.isBillingStaff
            ? const LoginScreen(isWindowsStaffLogin: true)
            : const LoginScreen(),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final showSidebar = MediaQuery.sizeOf(context).width >= 900;
    final colors = Theme.of(context).colorScheme.copyWith(
          primary: const Color(0xFF25372B),
          secondary: const Color(0xFFC7EF69),
          secondaryContainer: const Color(0xFFE4F4C4),
          surface: const Color(0xFFF8F9F4),
          onSurface: const Color(0xFF172019),
          onSurfaceVariant: const Color(0xFF667267),
          outlineVariant: const Color(0xFFD8E0D6),
        );
    final adminTheme = Theme.of(context).copyWith(
      colorScheme: colors,
      scaffoldBackgroundColor: const Color(0xFFEAF0E8),
      appBarTheme: Theme.of(context).appBarTheme.copyWith(
            backgroundColor: const Color(0xFFEAF0E8),
            foregroundColor: const Color(0xFF172019),
            elevation: 0,
            surfaceTintColor: Colors.transparent,
          ),
      cardTheme: Theme.of(context).cardTheme.copyWith(
            color: const Color(0xFFF8F9F4),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xFFD8E0D6)),
            ),
          ),
      navigationRailTheme: Theme.of(context).navigationRailTheme.copyWith(
            backgroundColor: const Color(0xFFEAF0E8),
            indicatorColor: const Color(0xFFC7EF69),
            selectedIconTheme: const IconThemeData(
              color: Color(0xFF25372B),
            ),
            selectedLabelTextStyle: const TextStyle(
              color: Color(0xFF25372B),
              fontWeight: FontWeight.w800,
            ),
          ),
      inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
            filled: true,
            fillColor: const Color(0xFFF8F9F4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFD8E0D6)),
            ),
          ),
    );
    final activeScreenIndex = widget.isBillingStaff
        ? 0
        : _selectedIndex >= _screens.length
            ? _screens.length - 1
            : _selectedIndex;
    final title = widget.isBillingStaff
        ? _billingStaffModules[_selectedIndex].title
        : _selectedIndex < _titles.length
            ? _titles[_selectedIndex]
            : _billingModules[_selectedIndex - _titles.length + 1].title;
    final destinations = widget.isBillingStaff
        ? _billingStaffDestinations
        : [..._destinations, ..._billingDestinations.skip(1)];

    return Theme(
      data: adminTheme,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title),
              Text(
                widget.isBillingStaff ? 'STORE STAFF' : 'STORE ADMIN',
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
                SizedBox(
                  width: 276,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
                        child: Row(
                          children: [
                            const Icon(Icons.storefront_rounded,
                                color: Color(0xFF25372B)),
                            const SizedBox(width: 10),
                            Text(
                              widget.isBillingStaff
                                  ? 'STORE STAFF'
                                  : 'STORE ADMIN',
                              style: const TextStyle(
                                color: Color(0xFF667267),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView(
                          key: const ValueKey('admin-navigation-list'),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          children: _buildNavigationItems(destinations),
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1),
              ],
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: IndexedStack(
                      index: activeScreenIndex,
                      children: [
                        for (var index = 0; index < _screens.length; index++)
                          TickerMode(
                            enabled: index == activeScreenIndex,
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
      ),
    );
  }

  Widget _buildAdminDrawer() {
    final destinations = widget.isBillingStaff
        ? _billingStaffDestinations
        : [..._destinations, ..._billingDestinations.skip(1)];
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
                          widget.isBillingStaff ? 'STORE STAFF' : 'STORE ADMIN',
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
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                children: _buildNavigationItems(destinations),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildNavigationItems(
    List<NavigationRailDestination> destinations,
  ) {
    return List<Widget>.generate(destinations.length, (index) {
      final moduleIndex = widget.isBillingStaff
          ? index
          : index < _titles.length
              ? null
              : index - _titles.length + 1;
      final title = moduleIndex == null
          ? _titles[index]
          : (widget.isBillingStaff
              ? _billingStaffModules[moduleIndex].title
              : _billingModules[moduleIndex].title);
      final destination = destinations[index];
      final selected = index == _selectedIndex;
      return ListTile(
        minLeadingWidth: 28,
        leading: Icon(
          selected
              ? (destination.selectedIcon as Icon).icon
              : (destination.icon as Icon).icon,
          color: selected ? const Color(0xFFC7EF69) : const Color(0xFF667267),
        ),
        title: Text(title),
        selected: selected,
        selectedTileColor: const Color(0xFF25372B),
        selectedColor: const Color(0xFFC7EF69),
        onTap: () {
          _selectIndex(index);
          if (MediaQuery.sizeOf(context).width < 900) {
            Navigator.pop(context);
          }
        },
      );
    });
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
      label: Text('Drinks'),
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
      icon: Icon(Icons.local_fire_department_outlined),
      selectedIcon: Icon(Icons.local_fire_department_rounded),
      label: Text('Buying streak'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.local_offer_outlined),
      selectedIcon: Icon(Icons.local_offer_rounded),
      label: Text('Promotions'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.point_of_sale_outlined),
      selectedIcon: Icon(Icons.point_of_sale_rounded),
      label: Text('Billing'),
    ),
  ];

  static const _billingModules = <_BillingModule>[
    _BillingModule(
      'Dashboard',
      Icons.space_dashboard_outlined,
      Icons.space_dashboard_rounded,
      section: AdminBillingSection.dashboard,
    ),
    _BillingModule(
      'New Bill / POS',
      Icons.add_shopping_cart_outlined,
      Icons.add_shopping_cart_rounded,
      action: _BillingAction.newBill,
    ),
    _BillingModule(
      'Essential',
      Icons.bolt_outlined,
      Icons.bolt_rounded,
      section: AdminBillingSection.essential,
    ),
    _BillingModule(
      'Barcode Scanner',
      Icons.qr_code_scanner_outlined,
      Icons.qr_code_scanner_rounded,
      action: _BillingAction.barcode,
    ),
    _BillingModule(
      'Held / Suspended Bills',
      Icons.pause_circle_outline_rounded,
      Icons.pause_circle_rounded,
      section: AdminBillingSection.heldBills,
    ),
    _BillingModule(
      'Bill History / Invoices',
      Icons.receipt_long_outlined,
      Icons.receipt_long_rounded,
      section: AdminBillingSection.billHistory,
    ),
    _BillingModule(
      'Payments & Refunds',
      Icons.payments_outlined,
      Icons.payments_rounded,
      section: AdminBillingSection.payments,
    ),
    _BillingModule(
      'Cash Register',
      Icons.point_of_sale_outlined,
      Icons.point_of_sale_rounded,
      section: AdminBillingSection.cashRegister,
    ),
    _BillingModule(
      'Customers',
      Icons.people_outline_rounded,
      Icons.people_rounded,
      section: AdminBillingSection.customers,
    ),
    _BillingModule(
      'Returns & Exchanges',
      Icons.swap_horiz_rounded,
      Icons.swap_horiz_rounded,
      section: AdminBillingSection.returns,
    ),
    _BillingModule(
      'Sales Reports',
      Icons.analytics_outlined,
      Icons.analytics_rounded,
      section: AdminBillingSection.reports,
    ),
    _BillingModule(
      'Receipt & Printer Settings',
      Icons.print_outlined,
      Icons.print_rounded,
      section: AdminBillingSection.printer,
    ),
    _BillingModule(
      'Notifications',
      Icons.notifications_outlined,
      Icons.notifications_rounded,
      section: AdminBillingSection.notifications,
    ),
    _BillingModule(
      'My Profile / Logout',
      Icons.account_circle_outlined,
      Icons.account_circle_rounded,
      action: _BillingAction.profile,
    ),
  ];

  static final _billingDestinations = _billingModules
      .map((module) => NavigationRailDestination(
            icon: Icon(module.icon),
            selectedIcon: Icon(module.selectedIcon),
            label: Text(module.title),
          ))
      .toList(growable: false);

  static final _billingStaffModules = _billingModules.toList(growable: false);

  static final _billingStaffDestinations = _billingStaffModules
      .map((module) => NavigationRailDestination(
            icon: Icon(module.icon),
            selectedIcon: Icon(module.selectedIcon),
            label: Text(module.title),
          ))
      .toList(growable: false);
}
