import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:freshharvest_grocery/core/billing_strings.dart';
import 'package:freshharvest_grocery/providers/auth_provider.dart';
import 'package:freshharvest_grocery/providers/product_provider.dart';
import 'package:freshharvest_grocery/providers/store_availability_provider.dart';
import 'package:freshharvest_grocery/screens/admin/admin_announcements_screen.dart';
import 'package:freshharvest_grocery/screens/admin/admin_billing_staff_screen.dart';
import 'package:freshharvest_grocery/screens/admin/admin_categories_screen.dart';
import 'package:freshharvest_grocery/screens/admin/admin_coupons_screen.dart';
import 'package:freshharvest_grocery/screens/admin/admin_customers_screen.dart';
import 'package:freshharvest_grocery/screens/admin/admin_delivery_people_screen.dart';
import 'package:freshharvest_grocery/screens/admin/admin_inventory_expiry_screen.dart';
import 'package:freshharvest_grocery/screens/admin/admin_orders_screen.dart';
import 'package:freshharvest_grocery/screens/admin/admin_products_screen.dart';
import 'package:freshharvest_grocery/screens/admin/admin_restock_screen.dart';
import 'package:freshharvest_grocery/screens/admin/admin_showcase_screen.dart';
import 'package:freshharvest_grocery/screens/admin/admin_skus_screen.dart';
import 'package:freshharvest_grocery/screens/admin/admin_store_hours_screen.dart';
import 'package:freshharvest_grocery/screens/admin/admin_streak_screen.dart';
import 'package:freshharvest_grocery/screens/admin/admin_supplier_bills_screen.dart';
import 'package:freshharvest_grocery/screens/admin/admin_wholesale_screen.dart';
import 'package:freshharvest_grocery/screens/admin/customer_menu_settings_screen.dart';
import 'package:freshharvest_grocery/services/api_service.dart';
import 'package:freshharvest_grocery/services/offline_pos_store.dart';
import 'package:freshharvest_grocery/models/pos_models.dart';
import 'package:freshharvest_grocery/theme/app_theme.dart';
import 'package:freshharvest_grocery/theme/app_colors.dart';

class _AuditApi extends ApiService {
  _AuditApi(this.fail, {this.populated = false});
  bool fail;
  final bool populated;
  int writes = 0;
  Future<dynamic> _denyWrite() async {
    writes++;
    throw StateError(
        'Audit fixtures must not submit invalid or cancelled forms');
  }

  @override
  Future<dynamic> post(String endpoint, Map<String, dynamic> body) =>
      _denyWrite();
  @override
  Future<dynamic> patch(String endpoint, Map<String, dynamic> body) =>
      _denyWrite();
  @override
  Future<dynamic> put(String endpoint, Map<String, dynamic> body) =>
      _denyWrite();
  @override
  Future<dynamic> delete(String endpoint, {Map<String, dynamic>? body}) =>
      _denyWrite();
  final endpoints = <String>[];
  @override
  Future<dynamic> get(String endpoint,
      {Map<String, String>? queryParams}) async {
    endpoints.add(endpoint);
    if (fail) throw Exception('Isolated audit network failure');
    if (endpoint == '/admin/billing/rooms') {
      return {
        'rooms': [],
        'stocks': [],
        'totals': [],
        'products': [],
        'capturedAt': '2026-11-06T00:00:00Z'
      };
    }
    return <String, dynamic>{
      for (final key in [
        'products',
        'categories',
        'orders',
        'customers',
        'records',
        'staff',
        'deliveryPeople',
        'deliveries',
        'coupons',
        'rewards',
        'claims',
        'wholesaleItems',
        'bills',
        'receipts',
        'batches',
        'data'
      ])
        key: [],
      'customerMenuFeatures': <String, bool>{},
      'pagination': {'page': 1, 'pageSize': 20, 'total': 0},
      'summary': <String, dynamic>{},
      'isOrderingEnabled': true,
      'isAcceptingOrders': true,
      'weeklyHours': List.generate(
          7,
          (i) => {
                'day': i + 1,
                'isOpen': true,
                'openTime': '09:00',
                'closeTime': '21:00'
              }),
      'timeZone': 'Asia/Kathmandu',
      if (populated) ...{
        'products': [
          {
            'id': 'product-a',
            'name': 'Rice sample',
            'sku': 'RICE-1',
            'slug': 'rice',
            'price': 235,
            'stock': 12,
            'unitLabel': '1 pc',
            'categoryId': 'cat-a',
            'category': {'id': 'cat-a', 'name': 'Pantry'},
            'isActive': true,
            'isVendingDrink': true
          }
        ],
        'categories': [
          {'id': 'cat-a', 'name': 'Pantry', 'slug': 'pantry', 'isActive': true}
        ],
        'customers': [
          {
            'id': 'customer-a',
            'name': 'Audit customer',
            'phone': '9800000000',
            'email': 'audit@example.test',
            'isActive': true
          }
        ],
        'staff': [
          {
            'id': 'staff-a',
            'name': 'Audit staff',
            'email': 'staff@example.test',
            'role': 'CUSTOMER',
            'isActive': true,
            'emailVerified': true
          }
        ],
        'deliveryPeople': [
          {
            'id': 'rider-a',
            'name': 'Audit rider',
            'email': 'rider@example.test',
            'phone': '9800000000',
            'isActive': true,
            'isAvailable': true
          }
        ],
        'orders': [
          {
            'id': 'order-a',
            'orderNumber': 'TEST-001',
            'status': 'PROCESSING',
            'paymentMethod': 'COD',
            'paymentStatus': 'PENDING',
            'subtotal': 235,
            'total': 235,
            'customer': {'name': 'Audit customer', 'phone': '9800000000'},
            'shipping': {'address': 'Test road', 'city': 'Janakpur'},
            'items': [],
            'statusHistory': [],
            'createdAt': '2026-11-01T10:00:00Z'
          }
        ],
        'wholesaleItems': [
          {
            'id': 'sack-a',
            'name': 'Rice sack',
            'sku': 'SACK-25',
            'price': 2500,
            'stock': 5,
            'unitLabel': '25 kg',
            'minimumQuantity': 1,
            'isActive': true
          }
        ],
        'coupons': [
          {
            'id': 'coupon-a',
            'code': 'AUDIT50',
            'discountType': 'FIXED',
            'discountAmount': 50,
            'minOrderAmount': 500,
            'isActive': true
          }
        ],
        'pagination': {'page': 1, 'pageSize': 20, 'total': 1},
      },
    };
  }
}

class _MemoryCatalog extends OfflinePosStore {
  const _MemoryCatalog() : super(useLocalStock: false);
  @override
  Future<void> mergeCatalog(List<PosProduct> products) async {}
  @override
  Future<List<Map<String, dynamic>>> readPendingProducts() async => [];
  @override
  Future<List<Map<String, dynamic>>> readCategories() async => [];
  @override
  Future<void> saveCategories(List<Map<String, dynamic>> categories) async {}
  @override
  Future<List<PosProduct>> projectLocalStock(List<PosProduct> products,
          {bool freshStock = false}) async =>
      products;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await BillingStrings.load();
  });
  tearDown(() {
    BillingStrings.languageCode = 'en';
  });
  final pages = <String, Widget Function(_AuditApi)>{
    'announcements': (api) => AdminAnnouncementsScreen(api: api),
    'billing staff': (api) => AdminBillingStaffScreen(api: api),
    'categories': (api) => AdminCategoriesScreen(api: api),
    'coupons': (api) => AdminCouponsScreen(api: api),
    'customers': (api) => AdminCustomersScreen(api: api),
    'delivery': (api) => AdminDeliveryPeopleScreen(api: api),
    'expiry': (api) => AdminInventoryExpiryScreen(api: api),
    'orders': (api) => AdminOrdersScreen(api: api),
    'products': (api) =>
        AdminProductsScreen(api: api, offlineStore: const _MemoryCatalog()),
    'drinks': (api) => AdminProductsScreen(
        api: api, vendingOnly: true, offlineStore: const _MemoryCatalog()),
    'restock': (api) => AdminRestockScreen(api: api),
    'stock history': (api) => AdminRestockHistoryScreen(api: api),
    'showcase': (api) => AdminShowcaseScreen(api: api),
    'SKUs': (api) => AdminSkusScreen(api: api),
    'store hours': (_) => const AdminStoreHoursScreen(),
    'streak': (api) => AdminStreakScreen(api: api),
    'supplier bills': (api) => AdminSupplierBillsScreen(api: api),
    'wholesale': (api) =>
        AdminWholesaleScreen(api: api, offlineStore: const _MemoryCatalog()),
    'menu settings': (api) => CustomerMenuSettingsScreen(api: api),
  };
  for (final dark in [false, true]) {
    testWidgets('wholesale banner contrast in ${dark ? "dark" : "light"} mode',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      AppColors.windowsAdminDarkTheme = dark;
      addTearDown(() {
        AppColors.clearWindowsAdminTheme();
        debugDefaultTargetPlatformOverride = null;
      });
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.data,
          home: Scaffold(
              body: AdminWholesaleScreen(
                  api: _AuditApi(false),
                  offlineStore: const _MemoryCatalog()))));
      await tester.pumpAndSettle();
      final text = tester.widget<Text>(find.text('Wholesale inventory'));
      final foreground = text.style!.color!;
      expect(foreground, Colors.white);
      final contrast = (foreground.computeLuminance() + 0.05) /
          (AppColors.darkGreen.computeLuminance() + 0.05);
      expect(contrast, greaterThan(4.5));
      await tester.pumpWidget(const SizedBox.shrink());
      AppColors.clearWindowsAdminTheme();
      debugDefaultTargetPlatformOverride = null;
    });
  }
  for (final entry in <String, String>{
    'products': 'Add product',
    'drinks': 'Add drink',
    'wholesale': 'Add wholesale item',
    'categories': 'Add',
    'coupons': 'Add code',
    'delivery': 'Add staff',
  }.entries) {
    for (final width in [390.0, 1366.0]) {
      testWidgets('${entry.key} create form at ${width.toInt()}',
          (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        BillingStrings.languageCode = width < 600 ? 'ne' : 'en';
        final api = _AuditApi(false, populated: true);
        await tester.pumpWidget(MultiProvider(
            providers: [
              Provider<ApiService>.value(value: api),
              ChangeNotifierProvider(
                  create: (_) => AuthProvider(apiService: api)),
              ChangeNotifierProvider(
                  create: (_) => ProductProvider(apiService: api)),
            ],
            child: MaterialApp(
                theme: AppTheme.data,
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(disableAnimations: true),
                    child: child!),
                home: Scaffold(body: pages[entry.key]!(api)))));
        await tester.pumpAndSettle();
        final add = find.text(BillingStrings.tr(entry.value));
        if (add.evaluate().isEmpty) {
          await tester.scrollUntilVisible(add, 250,
              scrollable: find.byType(Scrollable).first);
        }
        await tester.ensureVisible(add);
        await tester.pumpAndSettle();
        await tester.ensureVisible(add);
        await tester.pumpAndSettle();
        await tester.tap(add);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
        final save = find
            .descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(FilledButton))
            .last;
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        // Required-field validation keeps an incomplete record in the form.
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(api.writes, 0,
            reason:
                'Invalid forms must be rejected before sending an API mutation');
        final cancel = find
            .descendant(
                of: find.byType(AlertDialog),
                matching: find.text(BillingStrings.tr('Cancel')))
            .last;
        await tester.ensureVisible(cancel);
        await tester.pumpAndSettle();
        await tester.tap(cancel);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(api.writes, 0,
            reason: 'Cancelling a draft must not create a record');
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      });
    }
  }
  for (final page in pages.entries) {
    for (final width in [390.0, 1366.0]) {
      for (final state in ['empty', 'failure', 'populated']) {
        testWidgets('${page.key} ${width.toInt()} $state', (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          BillingStrings.languageCode = width < 600 ? 'ne' : 'en';
          final previousErrorHandler = FlutterError.onError;
          FlutterError.onError = (details) {
            debugPrint(details.toString());
            previousErrorHandler?.call(details);
          };
          addTearDown(() => FlutterError.onError = previousErrorHandler);
          final api =
              _AuditApi(state == 'failure', populated: state == 'populated');
          await tester.pumpWidget(MultiProvider(
              providers: [
                Provider<ApiService>.value(value: api),
                ChangeNotifierProvider(
                    create: (_) => AuthProvider(apiService: api)),
                ChangeNotifierProvider(
                    create: (_) => ProductProvider(apiService: api)),
                ChangeNotifierProvider(
                    create: (_) => StoreAvailabilityProvider(apiService: api)),
              ],
              child: MaterialApp(
                  builder: (context, child) => MediaQuery(
                        data: MediaQuery.of(context)
                            .copyWith(disableAnimations: true),
                        child: child!,
                      ),
                  theme: AppTheme.data,
                  home: Scaffold(body: page.value(api)))));
          await tester.pumpAndSettle();
          final exception = tester.takeException();
          if (exception is FlutterError) debugPrint(exception.toStringDeep());
          expect(exception, isNull);
          // Traverse the complete scrollable page, not just the first viewport.
          final lists = find.byType(Scrollable);
          if (lists.evaluate().isNotEmpty) {
            await tester.drag(lists.first, const Offset(0, -1800));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
