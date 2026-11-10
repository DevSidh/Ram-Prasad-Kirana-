import '../../widgets/billing_localized_widgets.dart';
import 'dart:io';
import '../../core/billing_strings.dart';
import 'package:flutter/foundation.dart';
import '../../widgets/billing_language_switch.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/api_service.dart';
import '../../services/admin_api_service.dart';
import '../../services/catalogue_excel_sync.dart';
import '../../services/offline_pos_store.dart';
import '../../theme/admin_widgets.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import 'admin_categories_screen.dart';
import 'admin_announcements_screen.dart';
import 'admin_billing_screen.dart';
import 'admin_coupons_screen.dart';
import 'admin_customers_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_delivery_people_screen.dart';
import 'admin_inventory_expiry_screen.dart';
import 'admin_room_inventory_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_products_screen.dart';
import 'admin_restock_screen.dart';
import 'admin_showcase_screen.dart';
import 'admin_skus_screen.dart';
import 'admin_store_hours_screen.dart';
import 'admin_streak_screen.dart';
import 'admin_wholesale_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell(
      {super.key,
      this.isBillingStaff = false,
      this.offlineStore = const OfflinePosStore()});

  final bool isBillingStaff;
  final OfflinePosStore offlineStore;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

enum _BillingAction { section, newBill, barcode, expiry, profile, inventory }

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
  CatalogueExcelSync? _priceExcel;
  static const _windowsThemePreferenceKey = 'windows_admin_dark_theme';

  int _selectedIndex = 0;
  final _openedScreens = <int>{};
  Widget _rememberScreen(int index) {
    _openedScreens.add(index);
    return _screens[index];
  }

  late final List<Widget> _screens;
  final _billingKey = GlobalKey<AdminBillingScreenState>();
  final _ordersKey = GlobalKey<AdminOrdersScreenState>();
  int _unreadDeliveryCount = 0;

  static const _windowsOperatorOrder = [
    0,
    1,
    2,
    15,
    3,
    5,
    8,
    7,
    6,
    9,
    10,
    11,
    12,
    14,
    4,
    13,
  ];
  static const _primaryNavigationIndices = [
    0,
    3,
    20,
    22,
    26,
    21,
    23,
    27,
    31,
    24,
  ];
  static const _onlineDeliveryDestinationIndices = [1, 2, 4, 12, 13, 14, 15];

  bool _billingToolsExpanded = false;
  bool _onlineDeliveryExpanded = false;
  bool _managementExpanded = false;
  bool _useDarkWindowsTheme = false;
  bool _recoveringSession = false;

  bool get _isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  List<int> get _adminScreenOrder => _windowsOperatorOrder;

  List<NavigationRailDestination> get _adminNavigationDestinations => [
        for (final index in _adminScreenOrder) _destinations[index],
        ..._billingDestinations.skip(1),
      ];

  static const _titles = [
    'Dashboard',
    'Orders',
    'Delivery',
    'Customers',
    'Announcements',
    'Retails',
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
    if (_isWindows) {
      _useDarkWindowsTheme = true;
      AppColors.windowsAdminDarkTheme = true;
      _restoreWindowsThemePreference();
    }
    final api = context.read<ApiService>();
    if (_isWindows && !widget.isBillingStaff) {
      _priceExcel = CatalogueExcelSync(
          AdminApiService(api, offlineStore: widget.offlineStore),
          widget.offlineStore,
          ownerId: context.read<AuthProvider>().currentUser?.id ?? '')
        ..start();
    }
    if (widget.isBillingStaff) {
      _screens = [
        AdminBillingScreen(
          offlineStore: widget.offlineStore,
          key: _billingKey,
          api: api,
          isBillingStaff: true,
        ),
      ];
      return;
    }

    final productProvider = context.read<ProductProvider>();
    final adminScreens = <Widget>[
      AdminDashboardScreen(
        offlineStore: widget.offlineStore,
        api: api,
        onOrdersRequested: () {
          if (mounted) _selectIndex(1);
        },
      ),
      AdminOrdersScreen(
        key: _ordersKey,
        api: api,
        isActive: true,
        onUnreadOrderCountChanged: (count) {
          if (!mounted || _unreadDeliveryCount == count) return;
          setState(() => _unreadDeliveryCount = count);
        },
      ),
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
        onFeaturedChanged: productProvider.setFeaturedLocally,
        onProductImageChanged: productProvider.setProductImageLocally,
      ),
      AdminSkusScreen(api: api),
      const AdminStoreHoursScreen(),
      AdminStreakScreen(api: api),
      AdminCouponsScreen(api: api),
      AdminBillingScreen(
          key: _billingKey, api: api, offlineStore: widget.offlineStore),
    ];
    _screens = [
      for (final index in _adminScreenOrder) adminScreens[index],
    ];
  }

  Future<void> _restoreWindowsThemePreference() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final savedValue = preferences.getBool(_windowsThemePreferenceKey);
      if (savedValue == null || !mounted) return;
      setState(() => _useDarkWindowsTheme = savedValue);
      AppColors.windowsAdminDarkTheme = savedValue;
    } catch (error) {
      debugPrint('Could not restore Windows admin theme: $error');
    }
  }

  Future<void> _toggleWindowsTheme() async {
    if (!_isWindows) return;
    final nextValue = !_useDarkWindowsTheme;
    setState(() => _useDarkWindowsTheme = nextValue);
    AppColors.windowsAdminDarkTheme = nextValue;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_windowsThemePreferenceKey, nextValue);
    } catch (error) {
      debugPrint('Could not save Windows admin theme: $error');
    }
  }

  @override
  void dispose() {
    _priceExcel?.dispose();
    if (_isWindows) AppColors.clearWindowsAdminTheme();
    super.dispose();
  }

  Future<void> _showPriceExcel() async {
    final sync = _priceExcel;
    if (sync == null) return;
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => ListenableBuilder(
            listenable: sync,
            builder: (_, __) => AlertDialog(
                  title: const BillingText('Linked product prices'),
                  content: SizedBox(
                      width: 480,
                      child: SingleChildScrollView(
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const BillingText(
                                'Edit Price NPR in Products, Wholesale or Drinks. Save and close Excel. Prices sync every 30 seconds while this admin panel is open.'),
                            const SizedBox(height: 12),
                            SelectableText(sync.path),
                            const SizedBox(height: 12),
                            BillingText(sync.status),
                            const SizedBox(height: 8),
                            const BillingText(
                                'Stock, names and categories are reference only. Formulas are not accepted. Deleted Excel rows never delete products.'),
                          ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const BillingText('Close')),
                    TextButton(
                        onPressed: sync.busy
                            ? null
                            : () async {
                                final confirmed = await showDialog<bool>(
                                    context: dialogContext,
                                    builder: (context) => AlertDialog(
                                            title: const BillingText(
                                                'Use app prices?'),
                                            content: const BillingText(
                                                'Keep a backup of the current Excel file, then replace it with current app prices. Unsynced Excel edits will not be imported.'),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, false),
                                                  child: const BillingText(
                                                      'Cancel')),
                                              FilledButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, true),
                                                  child: const BillingText(
                                                      'Use app prices'))
                                            ]));
                                if (confirmed == true) {
                                  await sync.synchronize(useAppPrices: true);
                                }
                              },
                        child: const BillingText('Use app prices')),
                    TextButton(
                        onPressed: sync.busy ? null : () => sync.synchronize(),
                        child: const BillingText('Sync now')),
                    FilledButton.icon(
                        onPressed: () async {
                          try {
                            if (!await File(sync.path).exists()) {
                              throw StateError(
                                  'Sync first to create the workbook.');
                            }
                            await Process.start('explorer.exe', [sync.path]);
                          } catch (error) {
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  SnackBar(content: Text('$error')));
                            }
                          }
                        },
                        icon: const Icon(Icons.open_in_new),
                        label: const BillingText('Open Excel')),
                  ],
                )));
  }

  void _selectIndex(int index) {
    setState(() {
      _selectedIndex = index;
      if (!widget.isBillingStaff && index == 1) {
        _unreadDeliveryCount = 0;
      }
      if (!widget.isBillingStaff) {
        if (index >= _titles.length &&
            !_primaryNavigationIndices.contains(index)) {
          _billingToolsExpanded = true;
        } else if (_onlineDeliveryDestinationIndices.contains(index)) {
          _onlineDeliveryExpanded = true;
        } else if (index >= 4 && index < _titles.length) {
          _managementExpanded = true;
        }
      }
    });
    if (!widget.isBillingStaff && index == 1) {
      _ordersKey.currentState?.markOrdersRead();
    }
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
        case _BillingAction.inventory:
          Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => AdminRoomInventoryScreen(
                    api: context.read<ApiService>(),
                    offlineStore: widget.offlineStore,
                    readOnly: widget.isBillingStaff,
                  )));
          break;
        case _BillingAction.newBill:
          _billingKey.currentState?.startNewBill();
          break;
        case _BillingAction.barcode:
          if (_isWindows && !widget.isBillingStaff) {
            _billingKey.currentState
                ?.activateSection(AdminBillingSection.barcodeScanner);
          } else {
            _billingKey.currentState?.openBarcodeScanner();
          }
          break;
        case _BillingAction.profile:
          _showProfile();
          break;
        case _BillingAction.expiry:
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AdminInventoryExpiryScreen(
                api: context.read<ApiService>(),
              ),
            ),
          );
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
        title: const BillingText('My profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BillingText(
              user?.fullName ?? 'Store staff',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (user?.email.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              BillingText(user!.email),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const BillingText('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _signOut();
            },
            icon: const Icon(Icons.logout_rounded),
            label: const BillingText('Log out'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: BillingText(
          widget.isBillingStaff
              ? 'Sign out of the billing counter?'
              : 'Sign out of admin?',
        ),
        content: BillingText(
          widget.isBillingStaff
              ? 'You will need to sign in again to continue billing.'
              : 'You will need to sign in again to manage the store.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const BillingText('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const BillingText('Sign out'),
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

  Future<void> _signInAfterExpiry() async {
    if (_recoveringSession) return;
    setState(() => _recoveringSession = true);
    try {
      await context.read<AuthProvider>().logout();
    } catch (_) {
      // AuthProvider clears its in-memory token even if credential storage fails.
      debugPrint(
          'Expired credentials could not be removed from local storage.');
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(
          builder: (_) => LoginScreen(
                isWindowsStaffLogin: _isWindows,
                isAdminLogin: !_isWindows && !widget.isBillingStaff,
                isBillingLogin: !_isWindows && widget.isBillingStaff,
              )),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final showSidebar = MediaQuery.sizeOf(context).width >= 900;
    final adminTitles = [
      for (final index in _adminScreenOrder) _titles[index],
    ];
    final billingScreenIndex =
        widget.isBillingStaff ? 0 : _adminScreenOrder.indexOf(15);
    final activeScreenIndex = widget.isBillingStaff
        ? 0
        : _selectedIndex >= _screens.length
            ? billingScreenIndex
            : _selectedIndex;
    final title = widget.isBillingStaff
        ? _billingStaffModules[_selectedIndex].title
        : _selectedIndex < _titles.length
            ? adminTitles[_selectedIndex]
            : _billingModules[_selectedIndex - _titles.length + 1].title;
    final destinations = widget.isBillingStaff
        ? _billingStaffDestinations
        : _adminNavigationDestinations;
    final subtitle = _subtitleFor(title);

    return Theme(
      data: AppTheme.data,
      child: AdminGradientBackground(
        child: Scaffold(
          appBar: showSidebar
              ? null
              : AppBar(
                  title: BillingText(title),
                  actions: [
                    if (_isWindows) _windowsThemeButton(),
                    BillingIconButton(
                      tooltip: 'Sign out',
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout_rounded),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
          drawer: showSidebar ? null : _buildAdminDrawer(destinations),
          body: SafeArea(
            top: showSidebar,
            child: Row(
              children: [
                if (showSidebar)
                  SizedBox(
                    width: 300,
                    child: _buildSidebar(destinations),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      Row(children: [
                        const Expanded(child: BillingLanguageSwitch()),
                        if (_priceExcel != null)
                          ListenableBuilder(
                              listenable: _priceExcel!,
                              builder: (_, __) => TextButton.icon(
                                    onPressed: _showPriceExcel,
                                    icon: Icon(
                                        _priceExcel!.busy
                                            ? Icons.sync
                                            : Icons.table_chart_outlined,
                                        size: 18),
                                    label: const BillingText('Product Excel'),
                                  )),
                      ]),
                      ValueListenableBuilder<bool>(
                        valueListenable:
                            context.read<ApiService>().requiresSignIn,
                        builder: (context, required, _) => required
                            ? AppBanner(
                                message:
                                    'Your session has expired. Sign in again to continue.',
                                variant: AppStatusVariant.error,
                                icon: Icons.lock_outline,
                                trailing: TextButton(
                                  onPressed: _recoveringSession
                                      ? null
                                      : _signInAfterExpiry,
                                  child: const BillingText('Sign in again'),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      if (showSidebar)
                        _buildPageHeader(title: title, subtitle: subtitle),
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1440),
                            child: IndexedStack(
                              index: activeScreenIndex,
                              children: [
                                for (var index = 0;
                                    index < _screens.length;
                                    index++)
                                  TickerMode(
                                    enabled: index == activeScreenIndex,
                                    child: index == activeScreenIndex ||
                                            _openedScreens.contains(index) ||
                                            _screens[index]
                                                is AdminBillingScreen ||
                                            _screens[index] is AdminOrdersScreen
                                        ? _rememberScreen(index)
                                        : const SizedBox.shrink(),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitleFor(String title) => switch (title) {
        'Dashboard' => 'A clear view of what is happening in your store today',
        'Orders' => 'Review and manage incoming customer orders',
        'Delivery' => 'Dispatch orders and track delivery activity',
        'Cash Register' => 'Operate the counter and review today’s activity',
        'New Bill / POS' => 'Build and complete an in-store bill',
        'Held / Suspended Bills' => 'Resume an in-progress counter sale',
        'Bill History / Invoices' => 'Find, review, and print completed bills',
        'Pending Cash' =>
          'Review customer balances and record partial or full payments',
        'Billing' => 'Manage in-store sales and billing tools',
        'Customers' => 'View customer details and purchase history',
        'Retails' => 'Manage retail products available in your store',
        'Restock' => 'Review stock requests and supplier quantities',
        'Wholesale' => 'Manage wholesale pricing and availability',
        'Drinks' => 'Manage products shown in the drinks menu',
        'Categories' => 'Organize the store product catalog',
        'Showcase' => 'Choose products featured across the storefront',
        'Product SKUs' => 'Maintain product identifiers for billing',
        'Store hours' => 'Set opening hours and online order availability',
        'Promotions' => 'Manage coupons and customer offers',
        'Announcements' => 'Share updates with store customers',
        'Buying streak' => 'Review customer milestones and claims',
        _ => widget.isBillingStaff
            ? 'Operate the store billing counter'
            : 'Store management and operations',
      };

  Widget _buildPageHeader({required String title, required String subtitle}) {
    if (!_isWindows) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 24, 30, 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BillingText(title,
                      style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: 4),
                  BillingText(subtitle,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            BillingIconButton(
              tooltip: 'Sign out',
              onPressed: _signOut,
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
      );
    }

    final headerStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        );
    return Container(
      height: 58,
      color: AppColors.header,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: BillingText(
              _invoisoPageTitle(title),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: headerStyle,
            ),
          ),
          Positioned(
            right: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _windowsThemeButton(),
                BillingIconButton(
                  tooltip: 'Sign out',
                  style: IconButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.transparent,
                  ),
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _invoisoPageTitle(String title) => switch (title) {
        'Dashboard' => 'Dashboard Overview',
        'Retails' => 'Retail Management',
        'Customers' => 'Customer Management',
        'Sales Reports' => 'Reports',
        'New Bill / POS' => 'Create New Invoice',
        'Bill History / Invoices' => 'Invoice Management',
        'Payments & Refunds' => 'Refund Management',
        _ => title,
      };

  Widget _windowsThemeButton() => BillingIconButton(
        tooltip: _useDarkWindowsTheme
            ? 'Switch to white theme'
            : 'Switch to dark theme',
        style: _isWindows
            ? IconButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.transparent,
              )
            : null,
        onPressed: _toggleWindowsTheme,
        icon: Icon(
          _useDarkWindowsTheme
              ? Icons.light_mode_rounded
              : Icons.dark_mode_rounded,
        ),
      );

  Widget _buildAdminDrawer(List<NavigationRailDestination> destinations) =>
      Drawer(
        child: SafeArea(child: _buildSidebar(destinations)),
      );

  Widget _buildSidebar(List<NavigationRailDestination> destinations) {
    final user = context.read<AuthProvider>().currentUser;
    return Container(
      color: AppColors.sidebar,
      child: Column(
        children: [
          if (_isWindows) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
              child: Center(
                child: BillingText(
                  'Ram Prasad\nGeneral Store',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.action,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 9),
                decoration: BoxDecoration(
                  color: AppColors.navigationSelected,
                  borderRadius: BorderRadius.circular(AppRadii.navigation),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: AppColors.action,
                      foregroundColor: AppColors.onAction,
                      child: const BillingText('M',
                          style: TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: BillingText(
                        'My Company',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.action,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    Icon(Icons.expand_more, size: 18, color: AppColors.action),
                  ],
                ),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 12, 20),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadii.brand),
                    ),
                    child: Icon(Icons.storefront_rounded,
                        color: AppColors.accent, size: 21),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BillingText(
                            widget.isBillingStaff
                                ? 'STORE STAFF'
                                : 'STORE ADMIN',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(color: AppColors.primary)),
                        BillingText('Ram Prasad General Store',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView(
              key: const ValueKey('admin-navigation-list'),
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              children: _buildNavigationItems(destinations),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: AppColors.isWindowsAdminDarkTheme
                      ? AppColors.successBanner
                      : AppColors.primary,
                  foregroundColor: AppColors.isWindowsAdminDarkTheme
                      ? AppColors.successText
                      : AppColors.accent,
                  child: BillingText(
                    (user?.fullName.isNotEmpty == true
                            ? user!.fullName.substring(0, 1)
                            : 'S')
                        .toUpperCase(),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BillingText(
                    user?.fullName ?? 'Store staff',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                BillingIconButton(
                  tooltip: 'My profile / logout',
                  onPressed: _showProfile,
                  icon: const Icon(Icons.more_horiz_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildNavigationItems(
    List<NavigationRailDestination> destinations,
  ) {
    final adminTitles = [
      for (final index in _adminScreenOrder) _titles[index],
    ];
    String titleForIndex(int index) {
      if (widget.isBillingStaff) {
        return _billingStaffModules[index].title;
      }
      return index < _titles.length
          ? adminTitles[index]
          : _billingModules[index - _titles.length + 1].title;
    }

    Widget navigationTile(int index) {
      final destination = destinations[index];
      final selected = index == _selectedIndex;
      final icon = selected
          ? (destination.selectedIcon as Icon).icon
          : (destination.icon as Icon).icon;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          color: selected
              ? (_isWindows
                  ? AppColors.navigationSelected
                  : (AppColors.isWindowsAdminDarkTheme
                      ? AppColors.successBanner
                      : AppColors.primary))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.navigation),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.navigation),
            onTap: () {
              _selectIndex(index);
              if (MediaQuery.sizeOf(context).width < 900) {
                Navigator.pop(context);
              }
            },
            child: SizedBox(
              height: BillingStrings.isNepali ? 78 : 62,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: _isWindows ? 10 : 5),
                child: Row(
                  children: [
                    if (!_isWindows) ...[
                      Container(
                        width: 25,
                        height: 25,
                        decoration: BoxDecoration(
                          color: selected
                              ? (AppColors.isWindowsAdminDarkTheme
                                  ? AppColors.success
                                  : AppColors.accent)
                              : AppColors.surface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          size: 15,
                          color: selected && AppColors.isWindowsAdminDarkTheme
                              ? AppColors.darkGreen
                              : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ] else ...[
                      Icon(
                        icon,
                        size: 17,
                        color:
                            selected ? AppColors.actionText : AppColors.muted,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: BillingText(
                        _isWindows
                            ? _invoisoNavigationTitle(titleForIndex(index))
                            : titleForIndex(index),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: selected
                                  ? (_isWindows
                                      ? AppColors.actionText
                                      : (AppColors.isWindowsAdminDarkTheme
                                          ? AppColors.successText
                                          : AppColors.accent))
                                  : AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    if (!widget.isBillingStaff &&
                        titleForIndex(index) == 'Orders' &&
                        _unreadDeliveryCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        constraints: const BoxConstraints(
                          minWidth: 19,
                          minHeight: 19,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE53935),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: BillingText(
                          _unreadDeliveryCount > 99
                              ? '99+'
                              : '$_unreadDeliveryCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                    if (_isWindows && selected) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 3,
                        height: 21,
                        decoration: BoxDecoration(
                          color: AppColors.action,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (widget.isBillingStaff) {
      final customerIndex = _billingStaffModules.indexWhere(
          (module) => module.section == AdminBillingSection.customers);
      final expiryIndex = _billingStaffModules
          .indexWhere((module) => module.action == _BillingAction.expiry);
      return [
        for (var index = 0; index < destinations.length; index++) ...[
          if (index != customerIndex) navigationTile(index),
          if (index == expiryIndex && customerIndex >= 0)
            navigationTile(customerIndex),
        ]
      ];
    }

    final primaryIndices = _primaryNavigationIndices.toSet();
    final onlineDeliveryIndices = _onlineDeliveryDestinationIndices.toSet();
    final children = <Widget>[
      for (final index in _primaryNavigationIndices) navigationTile(index),
      _buildNavigationGroup(
        title: 'Online delivery',
        expanded: _onlineDeliveryExpanded,
        onChanged: (expanded) => _onlineDeliveryExpanded = expanded,
        children: [
          for (final index in _onlineDeliveryDestinationIndices)
            navigationTile(index),
        ],
      ),
      _buildNavigationGroup(
        title: 'Store setup & management',
        expanded: _managementExpanded,
        onChanged: (expanded) => _managementExpanded = expanded,
        children: [
          for (var index = 4; index < _titles.length; index++)
            if (!primaryIndices.contains(index) &&
                !onlineDeliveryIndices.contains(index))
              navigationTile(index),
        ],
      ),
      _buildNavigationGroup(
        title: 'Billing management',
        expanded: _billingToolsExpanded,
        onChanged: (expanded) => _billingToolsExpanded = expanded,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  _selectIndex(_titles.length);
                  if (MediaQuery.sizeOf(context).width < 900) {
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const BillingText('New bill'),
              ),
            ),
          ),
          for (var index = _titles.length; index < destinations.length; index++)
            if (index != _titles.length && !primaryIndices.contains(index))
              navigationTile(index),
        ],
      ),
    ];
    return children;
  }

  String _invoisoNavigationTitle(String title) => switch (title) {
        'New Bill / POS' => 'New Invoice',
        'Bill History / Invoices' => 'Invoices',
        'Payments & Refunds' => 'Refunds',
        'Sales Reports' => 'Reports',
        _ => title,
      };

  Widget _buildNavigationGroup({
    required String title,
    required bool expanded,
    required ValueChanged<bool> onChanged,
    required List<Widget> children,
  }) =>
      Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Divider(),
          ),
          Theme(
            data: Theme.of(context).copyWith(
              listTileTheme: const ListTileThemeData(
                dense: true,
                minVerticalPadding: 0,
              ),
            ),
            child: Material(
              color: AppColors.sidebar,
              child: ExpansionTile(
                key: ValueKey('$title-$expanded'),
                initiallyExpanded: expanded,
                tilePadding: const EdgeInsets.symmetric(horizontal: 5),
                childrenPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onExpansionChanged: onChanged,
                title: BillingText(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.muted,
                        letterSpacing: 0,
                      ),
                ),
                children: children,
              ),
            ),
          ),
        ],
      );

  static const _destinations = [
    NavigationRailDestination(
      icon: Icon(Icons.space_dashboard_outlined),
      selectedIcon: Icon(Icons.space_dashboard_rounded),
      label: BillingText('Dashboard'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long_rounded),
      label: BillingText('Orders'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.local_shipping_outlined),
      selectedIcon: Icon(Icons.local_shipping_rounded),
      label: BillingText('Delivery'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.people_outline_rounded),
      selectedIcon: Icon(Icons.people_rounded),
      label: BillingText('Customers'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.campaign_outlined),
      selectedIcon: Icon(Icons.campaign_rounded),
      label: BillingText('Announcements'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.inventory_2_outlined),
      selectedIcon: Icon(Icons.inventory_2_rounded),
      label: BillingText('Retails'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.local_drink_outlined),
      selectedIcon: Icon(Icons.local_drink_rounded),
      label: BillingText('Drinks'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.storefront_outlined),
      selectedIcon: Icon(Icons.storefront_rounded),
      label: BillingText('Wholesale'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.add_box_outlined),
      selectedIcon: Icon(Icons.add_box_rounded),
      label: BillingText('Restock'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.category_outlined),
      selectedIcon: Icon(Icons.category_rounded),
      label: BillingText('Categories'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.view_carousel_outlined),
      selectedIcon: Icon(Icons.view_carousel_rounded),
      label: BillingText('Showcase'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.qr_code_2_outlined),
      selectedIcon: Icon(Icons.qr_code_2_rounded),
      label: BillingText('Product SKUs'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.schedule_outlined),
      selectedIcon: Icon(Icons.schedule_rounded),
      label: BillingText('Store hours'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.local_fire_department_outlined),
      selectedIcon: Icon(Icons.local_fire_department_rounded),
      label: BillingText('Buying streak'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.local_offer_outlined),
      selectedIcon: Icon(Icons.local_offer_rounded),
      label: BillingText('Promotions'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.point_of_sale_outlined),
      selectedIcon: Icon(Icons.point_of_sale_rounded),
      label: BillingText('Billing'),
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
      'Pending Cash',
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet_rounded,
      section: AdminBillingSection.pendingPayments,
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
      'Expiry',
      Icons.event_busy_outlined,
      Icons.event_busy_rounded,
      action: _BillingAction.expiry,
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
    _BillingModule(
        'Inventory', Icons.warehouse_outlined, Icons.warehouse_rounded,
        action: _BillingAction.inventory),
  ];

  static final _billingDestinations = _billingModules
      .map((module) => NavigationRailDestination(
            icon: Icon(module.icon),
            selectedIcon: Icon(module.selectedIcon),
            label: BillingText(module.title),
          ))
      .toList(growable: false);

  static const _billingStaffModules = _billingModules;

  static final _billingStaffDestinations = _billingStaffModules
      .map((module) => NavigationRailDestination(
            icon: Icon(module.icon),
            selectedIcon: Icon(module.selectedIcon),
            label: BillingText(module.title),
          ))
      .toList(growable: false);
}
