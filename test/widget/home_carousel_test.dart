import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freshharvest_grocery/core/constants.dart';
import 'package:freshharvest_grocery/providers/auth_provider.dart';
import 'package:freshharvest_grocery/providers/cart_provider.dart';
import 'package:freshharvest_grocery/providers/product_provider.dart';
import 'package:freshharvest_grocery/providers/store_availability_provider.dart';
import 'package:freshharvest_grocery/screens/home/home_screen.dart';
import 'package:freshharvest_grocery/services/api_service.dart';
import 'package:freshharvest_grocery/widgets/cart_flight_overlay.dart';

class _CarouselApi extends ApiService {
  int _loginCount = 0;

  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    if (endpoint == '/categories') {
      return {
        'data': [
          {'id': 'fresh', 'name': 'Fresh', 'slug': 'fresh'},
        ],
      };
    }
    if (endpoint == '/store/availability') {
      return {
        'isOrderingEnabled': true,
        'isAcceptingOrders': true,
        'weeklyHours': List.generate(
          7,
          (index) => {
            'day': index + 1,
            'isOpen': true,
            'openTime': '00:00',
            'closeTime': '23:59',
          },
        ),
        'timeZone': 'Asia/Kathmandu',
        'statusMessage': 'The store is open and accepting orders.',
      };
    }
    if (endpoint == '/store/customer-menu-features') {
      return {
        'customerMenuFeatures': {'coupons': true},
      };
    }
    if (endpoint == '/account/coupons/used') {
      return {'usedCouponCodes': <String>[]};
    }
    if (endpoint == '/coupons/offer') {
      return {
        'offer': {
          'id': 'offer-1',
          'enabled': true,
          'code': 'DIWALI50',
          'discountType': 'FIXED',
          'amount': 50,
          'minOrderAmount': 0,
          'endsAt': null,
        },
      };
    }

    return {
      'data': [
        {
          'id': 'apples',
          'name': 'Red apples',
          'categoryId': 'fresh',
          'categoryName': 'Fresh',
          'categorySlug': 'fresh',
          'price': 220,
          'originalPrice': 250,
          'weight': '1 kg',
          'stock': 10,
          'description': 'Crisp red apples.',
          'isFeatured': true,
        },
        {
          'id': 'oranges',
          'name': 'Sweet oranges',
          'categoryId': 'fresh',
          'categoryName': 'Fresh',
          'categorySlug': 'fresh',
          'price': 180,
          'weight': '1 kg',
          'stock': 12,
          'description': 'Juicy oranges.',
          'isFeatured': true,
        },
        {
          'id': 'rice',
          'name': 'Everyday rice',
          'categoryId': 'pantry',
          'categoryName': 'Pantry',
          'categorySlug': 'pantry',
          'price': 120,
          'weight': '1 kg',
          'stock': 8,
          'description': 'Daily pantry rice.',
        },
      ],
      'pagination': {'page': 1, 'limit': 100, 'total': 3},
    };
  }

  @override
  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    if (endpoint == '/auth/login') {
      _loginCount++;
      return {
        'token': 'test-session-$_loginCount',
        'user': {
          'id': 'customer-1',
          'email': body['email'],
          'fullName': 'Test Customer',
          'phone': '9800000000',
          'role': 'CUSTOMER',
        },
      };
    }
    return super.post(endpoint, body);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('carousel arrow advances and featured products open quick view',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _CarouselApi();
    final auth = AuthProvider(apiService: api);
    await auth.sessionReady;
    addTearDown(auth.dispose);
    final products = ProductProvider(apiService: api);
    final cart = CartProvider();
    final cartTargetKey = GlobalKey();
    final homeActive = ValueNotifier(true);
    addTearDown(homeActive.dispose);
    await products.loadCatalog();
    products.setCatalogFilters(categorySlug: 'not-on-home');
    addTearDown(products.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>.value(value: api),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<ProductProvider>.value(value: products),
          ChangeNotifierProvider<CartProvider>.value(value: cart),
          ChangeNotifierProvider(
            create: (_) => StoreAvailabilityProvider(apiService: api),
          ),
        ],
        child: ValueListenableBuilder<bool>(
          valueListenable: homeActive,
          child: CartFlightTarget(
            targetKey: cartTargetKey,
            child: MaterialApp(
              home: Scaffold(
                body: const HomeScreen(),
                bottomNavigationBar: SizedBox(
                  key: cartTargetKey,
                  height: 48,
                  child: const Icon(Icons.shopping_cart_outlined),
                ),
              ),
            ),
          ),
          builder: (context, isActive, child) => TickerMode(
            enabled: isActive,
            child: child!,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
        find.byKey(const ValueKey(
            'store-animation-animations/diwali_greeting.lottie')),
        findsNothing);
    expect(find.byTooltip('Close Diwali animation'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('home-coupon-gift-button')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('Coupons'), findsOneWidget);
    expect(find.text('DIWALI50'), findsOneWidget);
    await tester.tap(find.text('Use at checkout'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(cart.suggestedCouponCode, 'DIWALI50');
    expect(tester.takeException(), isNull);

    expect(find.byKey(const ValueKey('home-search-inline')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-search-pinned')), findsOneWidget);
    expect(find.text('Shop by categories'), findsOneWidget);
    expect(find.text('Cheap'), findsOneWidget);
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byType(PageView),
              matching: find.text('${AppConstants.currencySymbol}250'),
            ),
          )
          .style
          ?.decoration,
      TextDecoration.lineThrough,
    );
    expect(
      find.descendant(
        of: find.byType(PageView),
        matching: find.text('${AppConstants.currencySymbol}220'),
      ),
      findsOneWidget,
    );
    expect(tester.getSize(find.byType(PageView)).height, 260);
    expect(
      find.descendant(
        of: find.byType(PageView),
        matching: find.byWidgetPredicate(
          (widget) => widget is ColoredBox && widget.color == Colors.white,
        ),
      ),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('featured-discount-badge-apples')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('featured-savings-apples')),
      findsOneWidget,
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('home-search-inline')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-search-pinned')), findsOneWidget);
    expect(find.text('Everyday rice'), findsOneWidget);
    expect(find.byType(SliverGrid), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 700));
    await tester.pump(const Duration(seconds: 1));

    final pageController =
        tester.widget<PageView>(find.byType(PageView)).controller!;
    expect(find.byTooltip('Next featured product'), findsOneWidget);
    expect(pageController.page, 0);

    homeActive.value = false;
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(pageController.page, 0);

    homeActive.value = true;
    await tester.pump();
    await tester.pump(const Duration(seconds: 7));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));
    expect(pageController.page, 1);
    expect(
      find.byKey(const ValueKey('featured-sale-price-oranges')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('featured-old-price-oranges')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('featured-savings-oranges')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('featured-discount-badge-oranges')),
      findsNothing,
    );

    await tester.ensureVisible(
      find.descendant(
        of: find.byType(PageView),
        matching: find.text('Sweet oranges'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(
      find.descendant(
        of: find.byType(PageView),
        matching: find.text('Sweet oranges'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.textContaining('Add to basket'), findsOneWidget);
    expect(pageController.page, 1);

    expect(find.byKey(const ValueKey('home-floating-cart-bar')), findsNothing);
    await tester.tap(find.textContaining('Add to basket'));
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'weight dialog layout');
    expect(find.text('Choose Sweet oranges weight'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Weight in kg'),
      '0.5',
    );
    await tester.tap(find.text('Add weight'));
    await tester.pump();
    final weightLayoutError = tester.takeException();
    expect(
      weightLayoutError,
      isNull,
      reason: weightLayoutError is FlutterError
          ? weightLayoutError.diagnostics
              .map((diagnostic) => diagnostic.toStringDeep())
              .join('\n')
          : 'weight selection layout',
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));
    expect(cart.itemCount, 1);
    expect(cart.itemForProduct('oranges')?.weightGrams, 500);
    expect(find.byKey(const ValueKey('home-floating-cart-bar')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Next featured product'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(pageController.page, 0);

    await auth.login('customer@example.com', 'password');
    await tester.pump();
    expect(find.byTooltip('Close Diwali animation'), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
    expect(find.byKey(const ValueKey('home-diwali-ribbon-slot')), findsNothing);
    await tester.tap(find.byTooltip('Close Diwali animation'));
    await tester.pump();
    expect(find.byKey(const ValueKey('home-diwali-replay-tile')), findsNothing);
    expect(find.text('Festival of Lights'), findsNothing);
    if (find.byTooltip('Close offer').evaluate().isNotEmpty) {
      await tester.tap(find.byTooltip('Close offer'));
      await tester.pump(const Duration(milliseconds: 500));
    }
    await auth.logout();
    await tester.pump();
    await auth.login('customer@example.com', 'password');
    await tester.pump();
    expect(find.byTooltip('Close Diwali animation'), findsOneWidget);
    await tester.tap(find.byTooltip('Close Diwali animation'));
    await tester.pump();
    expect(find.byTooltip('Close Diwali animation'), findsNothing);
    expect(find.byKey(const ValueKey('home-diwali-replay-tile')), findsNothing);
    expect(find.text('Festival of Lights'), findsNothing);
    if (find.byTooltip('Close offer').evaluate().isNotEmpty) {
      await tester.tap(find.byTooltip('Close offer'));
      await tester.pump(const Duration(milliseconds: 500));
    }

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(find.text('Everyday rice'));
    await tester.tap(find.text('Everyday rice').first);
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    Navigator.of(tester.element(find.byType(DraggableScrollableSheet))).pop();
    await tester.pump(const Duration(milliseconds: 350));

    for (final size in [
      const Size(360, 800),
      const Size(412, 915),
      const Size(440, 956),
    ]) {
      tester.view.physicalSize = size;
      await tester.pump(const Duration(milliseconds: 100));
      final layoutError = tester.takeException();
      expect(layoutError, isNull, reason: 'viewport $size');
    }
  });
}
