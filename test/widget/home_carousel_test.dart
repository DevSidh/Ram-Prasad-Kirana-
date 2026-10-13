import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freshharvest_grocery/core/constants.dart';
import 'package:freshharvest_grocery/providers/auth_provider.dart';
import 'package:freshharvest_grocery/providers/cart_provider.dart';
import 'package:freshharvest_grocery/providers/product_provider.dart';
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
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Everyday rice'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 700));
    await tester.pumpAndSettle();

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

    await tester.tap(
      find.descendant(
        of: find.byType(PageView),
        matching: find.text('Sweet oranges'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Add to basket'), findsOneWidget);
    expect(pageController.page, 1);

    await tester.tap(find.text('Add to basket'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(cart.itemCount, 1);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Next featured product'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(pageController.page, 0);
  });
}
