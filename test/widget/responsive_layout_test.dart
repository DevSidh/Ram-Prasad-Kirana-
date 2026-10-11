import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freshharvest_grocery/core/responsive_layout.dart';
import 'package:freshharvest_grocery/providers/auth_provider.dart';
import 'package:freshharvest_grocery/providers/cart_provider.dart';
import 'package:freshharvest_grocery/providers/product_provider.dart';
import 'package:freshharvest_grocery/screens/auth/login_screen.dart';
import 'package:freshharvest_grocery/screens/profile/profile_screen.dart';
import 'package:freshharvest_grocery/screens/cart/cart_screen.dart';
import 'package:freshharvest_grocery/screens/admin/admin_shell.dart';
import 'package:freshharvest_grocery/widgets/product_card.dart';
import 'package:freshharvest_grocery/widgets/custom_button.dart';
import 'package:freshharvest_grocery/navigation/main_bottom_nav.dart';
import 'package:freshharvest_grocery/services/api_service.dart';
import 'package:freshharvest_grocery/models/product.dart';

class _ResponsiveApiService extends ApiService {
  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    if (endpoint == '/categories') return {'data': []};
    return {
      'data': [],
      'pagination': {'page': 1, 'limit': 100, 'total': 0},
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

      for (final label in ['Categories', 'Search', 'Cart', 'Profile']) {
        await tester.tap(find.text(label).last);
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
    await tester.pump(const Duration(milliseconds: 300));

    expect(cart.items['apples']?.quantity, 1);
    expect(find.text('1'), findsOneWidget);
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
    expect(find.text('Product SKUs'), findsOneWidget);

    await tester.tap(find.text('Product SKUs'));
    await tester.pumpAndSettle();
    expect(find.text('Product SKUs'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
