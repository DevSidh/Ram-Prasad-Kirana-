import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freshharvest_grocery/core/constants.dart';
import 'package:freshharvest_grocery/navigation/main_bottom_nav.dart';
import 'package:freshharvest_grocery/providers/auth_provider.dart';
import 'package:freshharvest_grocery/providers/cart_provider.dart';
import 'package:freshharvest_grocery/providers/order_provider.dart';
import 'package:freshharvest_grocery/providers/product_provider.dart';
import 'package:freshharvest_grocery/providers/theme_provider.dart';
import 'package:freshharvest_grocery/models/product.dart';
import 'package:freshharvest_grocery/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('customer navigation switches smoothly between five destinations',
      (tester) async {
    tester.view.physicalSize = const Size(320, 780);
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
          ChangeNotifierProvider(create: (_) => CartProvider()),
          ChangeNotifierProvider(
            create: (_) => OrderProvider(apiService: apiService),
          ),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const MaterialApp(home: MainBottomNav()),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Cart'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Account'), findsNothing);
    expect(find.text('Admin'), findsNothing);
    expect(find.text('Featured for Janakpur'), findsOneWidget);
    expect(find.text('India Gate Classic Basmati Rice'), findsNothing);

    void expectIndicatorWithinTab(String label) {
      final tab = tester.getRect(find.byKey(ValueKey('nav-tab-$label')));
      final indicator =
          tester.getRect(find.byKey(const ValueKey('selected-tab-indicator')));
      expect(indicator.left, greaterThanOrEqualTo(tab.left));
      expect(indicator.right, lessThanOrEqualTo(tab.right));
    }

    expectIndicatorWithinTab('Home');
    expect(
      tester
          .widget<Scaffold>(
            find.byKey(const ValueKey('main-bottom-nav-scaffold')),
          )
          .extendBody,
      isTrue,
    );
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    expectIndicatorWithinTab('Categories');
    expect(find.text('All Grocery Aisles'), findsOneWidget);

    await tester.tap(find.text('Search'));
    await tester.pump();
    await tester.pumpAndSettle();
    expectIndicatorWithinTab('Search');
    expect(find.byType(TextField), findsWidgets);

    await tester.tap(find.text('Cart'));
    await tester.pump();
    await tester.pumpAndSettle();
    expectIndicatorWithinTab('Cart');
    expect(find.text('Your basket is empty'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pump();
    await tester.pumpAndSettle();
    expectIndicatorWithinTab('Profile');
    expect(find.text('Saved items'), findsOneWidget);
    expect(find.text('Store administration'), findsOneWidget);

    await tester.ensureVisible(find.text('Dark appearance'));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Scaffold>(
            find.byKey(const ValueKey('main-bottom-nav-scaffold')),
          )
          .backgroundColor,
      AppConstants.backgroundFor(false),
    );
    await tester.tap(find.byKey(const ValueKey('nav-tab-Home')));
    await tester.pumpAndSettle();
    expect(find.text('Featured for Janakpur'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-tab-Profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved items'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.widgetWithText(AppBar, 'Saved items'),
      findsOneWidget,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Sign in with an admin account'));
    await tester.pump();
    await tester.tap(find.text('Sign in with an admin account'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Admin sign in'), findsOneWidget);
    expect(find.text('Admin username or email'), findsOneWidget);
    await tester.ensureVisible(find.text('Back to customer sign in'));
    await tester.pump();
    await tester.tap(find.text('Back to customer sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Admin login'), findsOneWidget);
    expect(find.text('Delivery staff'), findsNothing);
  });

  testWidgets('cart checkout action stays above floating navigation',
      (tester) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final apiService = ApiService();
    final cartProvider = CartProvider()
      ..addItem(
        Product(
          id: 'checkout-test',
          name: 'Checkout test product',
          categoryId: 'test',
          price: 100,
          weight: '1 pc',
          stock: 5,
          description: '',
          imageUrl: '',
        ),
      );

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
          ChangeNotifierProvider<CartProvider>.value(value: cartProvider),
          ChangeNotifierProvider(
            create: (_) => OrderProvider(apiService: apiService),
          ),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const MaterialApp(home: MainBottomNav(initialIndex: 3)),
      ),
    );
    await tester.pumpAndSettle();

    final checkout =
        tester.getRect(find.byKey(const ValueKey('cart-proceed-checkout')));
    final navigation =
        tester.getRect(find.byKey(const ValueKey('floating-nav-visible')));
    expect(checkout.bottom, lessThanOrEqualTo(navigation.top));
    expect(tester.takeException(), isNull);
  });
}
