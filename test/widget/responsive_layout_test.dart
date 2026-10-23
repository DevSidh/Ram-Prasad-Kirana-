import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freshharvest_grocery/core/responsive_layout.dart';
import 'package:freshharvest_grocery/providers/auth_provider.dart';
import 'package:freshharvest_grocery/providers/cart_provider.dart';
import 'package:freshharvest_grocery/providers/product_provider.dart';
import 'package:freshharvest_grocery/providers/store_availability_provider.dart';
import 'package:freshharvest_grocery/screens/auth/login_screen.dart';
import 'package:freshharvest_grocery/screens/profile/profile_screen.dart';
import 'package:freshharvest_grocery/screens/cart/cart_screen.dart';
import 'package:freshharvest_grocery/screens/admin/admin_shell.dart';
import 'package:freshharvest_grocery/screens/admin/admin_store_hours_screen.dart';
import 'package:freshharvest_grocery/screens/admin/admin_coupons_screen.dart';
import 'package:freshharvest_grocery/screens/admin/admin_restock_screen.dart';
import 'package:freshharvest_grocery/widgets/product_card.dart';
import 'package:freshharvest_grocery/widgets/custom_button.dart';
import 'package:freshharvest_grocery/navigation/main_bottom_nav.dart';
import 'package:freshharvest_grocery/services/api_service.dart';
import 'package:freshharvest_grocery/models/product.dart';

class _ResponsiveApiService extends ApiService {
  Map<String, dynamic>? storeSettingsUpdate;
  Map<String, dynamic>? restockRequest;

  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    if (endpoint == '/admin/coupons') return {'coupons': []};
    if (endpoint == '/admin/products' && queryParams?['stock'] == 'restock') {
      return {
        'products': [
          {
            'id': 'rice-1',
            'name': 'Rice',
            'sku': 'rice-1kg',
            'slug': 'rice',
            'categoryId': 'pantry',
            'category': {'id': 'pantry', 'name': 'Pantry'},
            'price': 250,
            'stock': 2,
            'lowStockThreshold': 4,
            'isActive': true,
          },
        ],
        'pagination': {'page': 1, 'pageSize': 100, 'total': 1},
      };
    }
    if (endpoint == '/admin/inventory/restock-history') {
      return {
        'receipts': [
          {
            'id': 'receipt-1',
            'quantity': 3,
            'balanceAfter': 5,
            'createdAt': '2026-10-19T10:00:00.000Z',
            'product': {
              'id': 'rice-1',
              'name': 'Rice',
              'sku': 'rice-1kg',
              'unitLabel': '1 kg',
            },
            'staff': {'id': 'admin-1', 'name': 'Store Admin'},
          },
        ],
        'pagination': {'page': 1, 'pageSize': 25, 'total': 1},
      };
    }
    if (endpoint == '/admin/store-settings' ||
        endpoint == '/store/availability') {
      return {
        'isOrderingEnabled': true,
        'isAcceptingOrders': true,
        'weeklyHours': List.generate(
          7,
          (index) => {
            'day': index + 1,
            'isOpen': true,
            'openTime': '09:00',
            'closeTime': '21:00',
          },
        ),
        'timeZone': 'Asia/Kathmandu',
        'statusMessage': 'The store is open and accepting orders.',
      };
    }
    if (endpoint == '/categories') return {'data': []};
    return {
      'data': [],
      'pagination': {'page': 1, 'limit': 100, 'total': 0},
    };
  }

  @override
  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    if (endpoint == '/admin/products/rice-1/restock') {
      restockRequest = body;
      return {
        'product': {
          'id': 'rice-1',
          'name': 'Rice',
          'sku': 'rice-1kg',
          'slug': 'rice',
          'categoryId': 'pantry',
          'category': {'id': 'pantry', 'name': 'Pantry'},
          'price': 250,
          'stock': 5,
          'lowStockThreshold': 4,
          'isActive': true,
        },
      };
    }
  }

  @override
  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    storeSettingsUpdate = body;
    final isOrderingEnabled = body['isOrderingEnabled'] == true;
    return {
      ...body,
      'isAcceptingOrders': isOrderingEnabled,
      'timeZone': 'Asia/Kathmandu',
      'statusMessage': isOrderingEnabled
          ? 'The store is open and accepting orders.'
          : 'Online ordering is temporarily paused by the store.',
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('product grids select a usable number of columns by available width',
      () {
    expect(
      responsiveGridCrossAxisCount(
        availableWidth: 288,
        minTileWidth: 128,
      ),
      2,
    );
    expect(
      responsiveGridCrossAxisCount(
        availableWidth: 248,
        minTileWidth: 128,
      ),
      1,
    );
    expect(
      responsiveGridCrossAxisCount(
        availableWidth: 1200,
        minTileWidth: 128,
      ),
      6,
    );
  });

  testWidgets('login layout does not overflow on narrow phones or desktop',
      (tester) async {
    final apiService = ApiService();
    final authProvider = AuthProvider(apiService: apiService);

    for (final width in [280.0, 320.0, 360.0, 768.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ApiService>.value(value: apiService),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pump();

      expect(
        tester.takeException(),
        isNull,
        reason: 'Login should fit a viewport width of $width logical pixels.',
      );
    }

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('customer navigation fits phone, tablet, and desktop widths',
      (tester) async {
    final apiService = _ResponsiveApiService();
    final authProvider = AuthProvider(apiService: apiService);
    final cartProvider = CartProvider();
    final productProvider = ProductProvider(apiService: apiService);
    addTearDown(authProvider.dispose);
    addTearDown(cartProvider.dispose);
    addTearDown(productProvider.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final width in [280.0, 320.0, 360.0, 768.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ApiService>.value(value: apiService),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<CartProvider>.value(value: cartProvider),
            ChangeNotifierProvider<ProductProvider>.value(
              value: productProvider,
            ),
            ChangeNotifierProvider(
              create: (_) => StoreAvailabilityProvider(apiService: apiService),
            ),
          ],
          child: const MaterialApp(home: MainBottomNav()),
        ),
      );
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: 'Initial screen should fit a viewport width of $width pixels.',
      );

      for (final label in ['Wholesale', 'Search', 'Cart', 'Profile']) {
        await tester.tap(find.byKey(ValueKey('nav-tab-$label')));
        await tester.pump(const Duration(milliseconds: 400));
        final layoutError = tester.takeException();
        final errorDetails = layoutError is FlutterError
            ? layoutError.diagnostics
                .map((diagnostic) => diagnostic.toStringDeep())
                .join('\n')
            : '$layoutError';
        expect(
          layoutError,
          isNull,
          reason:
              '$label should fit a viewport width of $width logical pixels: '
              '$errorDetails',
        );
      }
    }
  });

  testWidgets('custom buttons handle long labels in narrow layouts',
      (tester) async {
    tester.view.physicalSize = const Size(280, 120);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 136,
              child: CustomButton(
                text: 'Confirm and place this complete order',
                icon: Icons.shopping_basket_outlined,
                onPressed: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('profile content fits a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final apiService = _ResponsiveApiService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>.value(value: apiService),
          ChangeNotifierProvider(
            create: (_) => AuthProvider(apiService: apiService),
          ),
          ChangeNotifierProvider(
            create: (_) => ProductProvider(apiService: apiService),
          ),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pump();
    final overflowingRows = tester.allRenderObjects
        .whereType<RenderFlex>()
        .where(
            (renderFlex) => renderFlex.toStringShort().contains('OVERFLOWING'))
        .toList();
    expect(
      overflowingRows,
      isEmpty,
      reason: overflowingRows
          .map((renderFlex) => renderFlex.toStringDeep())
          .join('\n'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('cart delivery progress text fits a narrow phone',
      (tester) async {
    tester.view.physicalSize = const Size(280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cart = CartProvider()
      ..addItem(
        Product(
          id: 'rice',
          name: 'Basmati Rice',
          categoryId: 'grains',
          price: 150,
          weight: '1 kg',
          stock: 10,
          description: 'Rice',
          imageUrl: '',
        ),
      );

    await tester.pumpWidget(
      ChangeNotifierProvider<CartProvider>.value(
        value: cart,
        child: const MaterialApp(home: CartScreen()),
      ),
    );

    expect(tester.takeException(), isNull);
    final removeOne = find.byTooltip('Remove one Basmati Rice');
    final addOne = find.byTooltip('Add one Basmati Rice');
    expect(removeOne, findsOneWidget);
    expect(addOne, findsOneWidget);
    expect(tester.getSize(removeOne), const Size(48, 48));
    expect(tester.getSize(addOne), const Size(48, 48));

    await tester.tap(find.byTooltip('Clear basket'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Clear basket'));
    await tester.pumpAndSettle();
    expect(find.text('Your basket is empty'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Basmati Rice'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'product add control animates into basket quantity on narrow cards',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final apiService = ApiService();
    final cart = CartProvider();
    final products = ProductProvider(apiService: apiService);
    final product = Product(
      id: 'apples',
      name: 'Red apples',
      categoryId: 'fresh',
      price: 220,
      weight: '1 kg',
      stock: 10,
      description: 'Crisp red apples',
      imageUrl: '',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CartProvider>.value(value: cart),
          ChangeNotifierProvider<ProductProvider>.value(value: products),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 136,
                child: ProductCard(product: product),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Add'), findsOneWidget);
    await tester.tap(find.text('Add'));
    await tester.pump();
    expect(find.text('Choose Red apples weight'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Weight in kg'),
      '0.5',
    );
    await tester.tap(find.text('Add weight'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(cart.items['apples']?.weightGrams, 500);
    expect(find.text('0.5 kg'), findsOneWidget);
    expect(tester.takeException(), isNull);
    products.dispose();
  });

  testWidgets('admin uses a sidebar drawer instead of a bottom navbar on phone',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final apiService = ApiService();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>.value(value: apiService),
          ChangeNotifierProvider(
            create: (_) => AuthProvider(apiService: apiService),
          ),
          ChangeNotifierProvider(
            create: (_) => ProductProvider(apiService: apiService),
          ),
        ],
        child: const MaterialApp(home: AdminShell()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byIcon(Icons.menu), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    final productSkusTile = find.descendant(
      of: find.byType(Drawer),
      matching: find.text('Product SKUs'),
    );
    expect(productSkusTile, findsOneWidget);

    await tester.ensureVisible(productSkusTile);
    await tester.tap(productSkusTile);
    await tester.pumpAndSettle();
    expect(find.text('Product SKUs'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    final productSkusTileAgain = find.descendant(
      of: find.byType(Drawer),
      matching: find.text('Product SKUs'),
    );
    await tester.ensureVisible(productSkusTileAgain);
    await tester.tap(productSkusTileAgain);
    await tester.pumpAndSettle();
    expect(find.text('Product SKUs'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('store hours controls fit a narrow admin viewport',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final apiService = _ResponsiveApiService();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>.value(value: apiService),
          ChangeNotifierProvider(
            create: (_) => StoreAvailabilityProvider(apiService: apiService),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AdminStoreHoursScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Weekly opening hours'), findsOneWidget);
    expect(find.text('Monday'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Sunday'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Sunday'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(
      SwitchListTile,
      'Accept online orders',
    ));
    await tester.pumpAndSettle();
    expect(apiService.storeSettingsUpdate?['isOrderingEnabled'], isFalse);
    expect(find.text('Ordering is paused for every customer.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('promotion management fits a narrow admin viewport',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final apiService = _ResponsiveApiService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminCouponsScreen(api: apiService),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final initialLayoutError = tester.takeException();
    if (initialLayoutError is FlutterError) {
      debugPrint(initialLayoutError.toStringDeep());
    }
    expect(initialLayoutError, isNull);
    expect(find.text('Promotions'), findsOneWidget);
    expect(find.text('No promotions yet'), findsOneWidget);
    await tester.tap(find.text('Add code'));
    await tester.pumpAndSettle();
    expect(find.text('Create promotion'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('restock queue records quantities on a narrow phone',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final apiService = _ResponsiveApiService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminRestockScreen(api: apiService),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Restock queue'), findsOneWidget);
    expect(find.text('Rice'), findsOneWidget);
    expect(find.text('2 available'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Restock'));
    await tester.pumpAndSettle();
    expect(find.text('Record restock'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Manufacture date (MFG)'));
    await tester.tap(find.text('Manufacture date (MFG)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Expiry date (EXP)'));
    await tester.tap(find.text('Expiry date (EXP)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to stock'));
    await tester.pumpAndSettle();

    expect(apiService.restockRequest?['quantity'], 3);
    expect(apiService.restockRequest?['noExpiry'], isFalse);
    expect(apiService.restockRequest?['lotNumber'], isNull);
    final manufacturedAt = DateTime.parse(
      apiService.restockRequest!['manufacturedAt'] as String,
    );
    final expiresAt = DateTime.parse(
      apiService.restockRequest!['expiresAt'] as String,
    );
    expect(expiresAt.isAfter(manufacturedAt), isTrue);
    expect(find.text('Nothing to replenish'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Receipt history'));
    await tester.pumpAndSettle();
    expect(find.text('Recorded by Store Admin'), findsOneWidget);
    expect(find.text('+3 kg'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
