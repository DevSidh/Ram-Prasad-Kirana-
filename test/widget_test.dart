import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freshharvest_grocery/core/theme.dart';
import 'package:freshharvest_grocery/navigation/main_bottom_nav.dart';
import 'package:freshharvest_grocery/providers/auth_provider.dart';
import 'package:freshharvest_grocery/providers/cart_provider.dart';
import 'package:freshharvest_grocery/providers/order_provider.dart';
import 'package:freshharvest_grocery/providers/product_provider.dart';
import 'package:freshharvest_grocery/providers/store_availability_provider.dart';
import 'package:freshharvest_grocery/providers/theme_provider.dart';
import 'package:freshharvest_grocery/models/product.dart';
import 'package:freshharvest_grocery/screens/home/home_screen.dart';
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
    var themeMode = ThemeMode.light;
    late StateSetter setThemeMode;

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
          ChangeNotifierProvider(
            create: (_) => StoreAvailabilityProvider(apiService: apiService),
          ),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: StatefulBuilder(
          builder: (context, setState) {
            setThemeMode = setState;
            return MaterialApp(
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: themeMode,
              home: const MainBottomNav(),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    for (final label in ['Home', 'Categories', 'Search', 'Cart', 'Profile']) {
      final tab = find.byKey(ValueKey('nav-tab-$label'));
      expect(tab, findsOneWidget);
      expect(
          find.descendant(of: tab, matching: find.text(label)), findsNothing);
    }
    expect(find.text('India Gate Classic Basmati Rice'), findsNothing);

    void expectIndicatorWithinTab(String label) {
      final tab = tester.getRect(find.byKey(ValueKey('nav-tab-$label')));
      final indicator =
          tester.getRect(find.byKey(const ValueKey('selected-tab-indicator')));
      expect(indicator.left, greaterThanOrEqualTo(tab.left));
      expect(indicator.right, lessThanOrEqualTo(tab.right));
    }

    expectIndicatorWithinTab('Home');
    expect(find.byKey(const ValueKey('floating-nav-capsule')), findsOneWidget);
    final capsuleFinder = find.byKey(const ValueKey('floating-nav-capsule'));
    expect(tester.getSize(capsuleFinder), const Size(294, 62));
    void expectTransparentNavigationArea() {
      final navigationArea = tester.widget<Positioned>(
        find.byKey(const ValueKey('transparent-nav-area')),
      );
      expect(navigationArea.left, 0);
      expect(navigationArea.right, 0);
      expect(navigationArea.height, 62);
      expect(
        tester.getRect(find.byKey(const ValueKey('transparent-nav-area'))),
        Rect.fromLTWH(
          0,
          tester.view.physicalSize.height / tester.view.devicePixelRatio -
              MediaQuery.paddingOf(tester.element(capsuleFinder)).bottom -
              18 -
              62,
          tester.view.physicalSize.width / tester.view.devicePixelRatio,
          62,
        ),
      );
      final capsule = tester.widget<ClipRRect>(capsuleFinder);
      expect(capsule.borderRadius, BorderRadius.circular(40));
      expect(capsule.child, isA<BackdropFilter>());
      final decoration = tester
          .widget<Container>(
            find.descendant(
              of: capsuleFinder,
              matching: find.byType(Container),
            ),
          )
          .decoration! as BoxDecoration;
      expect(decoration.boxShadow, isNull);
    }

    expectTransparentNavigationArea();
    expect(
      tester.getSize(find.byKey(const ValueKey('nav-tab-Home'))).width,
      greaterThanOrEqualTo(48),
    );
    final lightCapsule = tester.widget<Container>(
      find
          .descendant(of: capsuleFinder, matching: find.byType(Container))
          .first,
    );
    final lightDecoration = lightCapsule.decoration! as BoxDecoration;
    expect(
      lightDecoration.color,
      const Color(0x99FFFFFF),
    );
    expect(lightDecoration.border!.top.color, const Color(0x14000000));
    expect(
      find.descendant(
        of: capsuleFinder,
        matching: find.byType(BackdropFilter),
      ),
      findsOneWidget,
    );
    expect(
      (tester
              .widget<DecoratedBox>(
                find.byKey(const ValueKey('selected-tab-indicator')),
              )
              .decoration as BoxDecoration)
          .color,
      const Color(0xFF16A34A),
    );
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(const ValueKey('nav-tab-Home')),
              matching: find.byType(Icon),
            ),
          )
          .color,
      Colors.white,
    );
    expect(
      tester
          .widget<Scaffold>(
            find.byKey(const ValueKey('main-bottom-nav-scaffold')),
          )
          .extendBody,
      isTrue,
    );
    final navigation =
        tester.getRect(find.byKey(const ValueKey('floating-nav-capsule')));
    final body =
        tester.getRect(find.byKey(const ValueKey('main-bottom-nav-body')));
    expect(
      body.bottom,
      greaterThan(navigation.top),
      reason:
          'The screen should paint behind the floating navigation; body $body, bar $navigation.',
    );
    for (final width in [360.0, 412.0]) {
      tester.view.physicalSize = Size(width, 780);
      await tester.pumpAndSettle();
      expect(tester.getSize(capsuleFinder), const Size(294, 62));
      expectTransparentNavigationArea();
    }
    tester.view.physicalSize = const Size(320, 780);
    await tester.pumpAndSettle();

    await tester.dragFrom(const Offset(160, 420), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('floating-nav-capsule')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-tab-Categories')));
    await tester.pump();
    expect(
      tester
          .widget<IndexedStack>(
            find.byKey(const ValueKey('main-bottom-nav-pages')),
          )
          .index,
      1,
    );
    await tester.pump(const Duration(milliseconds: 120));
    final categoriesBounds =
        tester.getRect(find.byKey(const ValueKey('categories-screen-scroll')));
    expect(categoriesBounds.left, 0);
    expect(categoriesBounds.width, 320);
    await tester.pumpAndSettle();
    expectIndicatorWithinTab('Categories');

    await tester.tap(find.byKey(const ValueKey('nav-tab-Search')));
    await tester.pump();
    await tester.pumpAndSettle();
    expectIndicatorWithinTab('Search');
    expect(find.byType(TextField), findsWidgets);
    await tester.enterText(find.byType(TextField).first, 'lentils');

    await tester.tap(find.byKey(const ValueKey('nav-tab-Cart')));
    await tester.pump();
    await tester.pumpAndSettle();
    expectIndicatorWithinTab('Cart');
    expect(find.text('Your basket is empty'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-tab-Search')));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is TextField && widget.controller?.text == 'lentils',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('nav-tab-Profile')));
    await tester.pump();
    await tester.pumpAndSettle();
    expectIndicatorWithinTab('Profile');

    await tester.tap(find.byKey(const ValueKey('nav-tab-Home')));
    await tester.pump(const Duration(milliseconds: 120));
    final homeBounds = tester.getRect(find.byType(HomeScreen));
    expect(homeBounds.left, 0);
    expect(homeBounds.width, 320);
    await tester.pumpAndSettle();

    setThemeMode(() => themeMode = ThemeMode.dark);
    await tester.pumpAndSettle();
    final darkCapsule = tester.widget<Container>(
      find
          .descendant(of: capsuleFinder, matching: find.byType(Container))
          .first,
    );
    final darkDecoration = darkCapsule.decoration! as BoxDecoration;
    expectTransparentNavigationArea();
    expect(
      darkDecoration.color,
      const Color(0x73141414),
    );
    expect(darkDecoration.border!.top.color, const Color(0x20FFFFFF));
    expect(
      (tester
              .widget<DecoratedBox>(
                find.byKey(const ValueKey('selected-tab-indicator')),
              )
              .decoration as BoxDecoration)
          .color,
      Colors.white,
    );
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(const ValueKey('nav-tab-Home')),
              matching: find.byType(Icon),
            ),
          )
          .color,
      const Color(0xFF111111),
    );
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
          ChangeNotifierProvider(
            create: (_) => StoreAvailabilityProvider(apiService: apiService),
          ),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const MaterialApp(home: MainBottomNav(initialIndex: 3)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('nav-tab-Cart')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    final checkout =
        tester.getRect(find.byKey(const ValueKey('cart-proceed-checkout')));
    final cartScaffold = tester.widget<Scaffold>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('cart-proceed-checkout')),
            matching: find.byType(Scaffold),
          )
          .first,
    );
    expect(cartScaffold.backgroundColor, const Color(0xFF07100D));
    expect(cartScaffold.extendBody, isTrue);
    expect(cartScaffold.extendBodyBehindAppBar, isTrue);
    expect(cartScaffold.bottomNavigationBar, isNull);
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('cart-proceed-checkout')),
        matching: find.byType(Stack),
      ),
      findsWidgets,
    );
    final navigation =
        tester.getRect(find.byKey(const ValueKey('floating-nav-capsule')));
    expect(
      checkout.bottom,
      lessThanOrEqualTo(navigation.top),
      reason: 'Checkout $checkout must remain above navigation $navigation.',
    );
    expect(tester.takeException(), isNull);
  });
}
