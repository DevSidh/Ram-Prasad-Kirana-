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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('carousel arrow advances and featured products open quick view',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _CarouselApi();
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
          ChangeNotifierProvider(
            create: (_) => AuthProvider(apiService: api),
          ),
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

    double searchOpacity(String key) => tester
        .widget<Opacity>(
          find
              .ancestor(
                of: find.byKey(ValueKey(key)),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;

    expect(searchOpacity('home-search-inline'), 1);
    expect(searchOpacity('home-search-pinned'), 0);
    expect(find.text('Shop by categories'), findsOneWidget);
    expect(find.text('Cheap'), findsOneWidget);
    expect(find.text('Everyday rice'), findsNothing);
    expect(find.byType(SliverGrid), findsOneWidget);
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
      find.byKey(const ValueKey('featured-discount-badge-apples')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('featured-savings-apples')),
      findsOneWidget,
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pump(const Duration(seconds: 1));
    expect(searchOpacity('home-search-inline'), 0);
    expect(searchOpacity('home-search-pinned'), 1);
    expect(find.text('Everyday rice'), findsOneWidget);
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
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 350));
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
    await tester.pump(const Duration(milliseconds: 700));
    expect(cart.itemCount, 1);
    expect(find.byKey(const ValueKey('home-floating-cart-bar')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Next featured product'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(pageController.page, 0);

    for (final size in [
      const Size(360, 800),
      const Size(412, 915),
      const Size(440, 956),
    ]) {
      tester.view.physicalSize = size;
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    }
  });
}
