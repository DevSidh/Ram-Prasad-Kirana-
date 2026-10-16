import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freshharvest_grocery/navigation/main_bottom_nav.dart';
import 'package:freshharvest_grocery/providers/auth_provider.dart';
import 'package:freshharvest_grocery/providers/cart_provider.dart';
import 'package:freshharvest_grocery/providers/order_provider.dart';
import 'package:freshharvest_grocery/providers/product_provider.dart';
import 'package:freshharvest_grocery/providers/store_availability_provider.dart';
import 'package:freshharvest_grocery/providers/theme_provider.dart';
import 'package:freshharvest_grocery/screens/category/categories_screen.dart';
import 'package:freshharvest_grocery/services/api_service.dart';

class _CategoryApi extends ApiService {
  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    if (endpoint == '/categories') {
      return {
        'data': [
          {'id': 'fresh', 'name': 'Fresh', 'slug': 'fresh', 'itemCount': 1},
          {
            'id': 'pantry',
            'name': 'Pantry',
            'slug': 'pantry',
            'itemCount': 1,
          },
          {
            'id': 'masalas',
            'name': 'Masalas',
            'slug': 'masalas',
            'itemCount': 1
          },
          {'id': 'oils', 'name': 'Oils', 'slug': 'oils', 'itemCount': 1},
          {'id': 'snacks', 'name': 'Snacks', 'slug': 'snacks', 'itemCount': 1},
          {'id': 'drinks', 'name': 'Drinks', 'slug': 'drinks', 'itemCount': 1},
          {
            'id': 'personal-care',
            'name': 'Personal care',
            'slug': 'personal-care',
            'itemCount': 1,
          },
          {'id': 'pen', 'name': 'Pen', 'slug': 'pen', 'itemCount': 0},
        ],
      };
    }
    return {
      'data': [
        {
          'id': 'greens',
          'name': 'Leafy greens',
          'categoryId': 'fresh',
          'categorySlug': 'fresh',
          'price': 80,
          'stock': 5,
          'rating': 4.8,
          'reviewCount': 15,
          'description': 'Fresh greens.',
          'weight': '1 bunch',
        },
        {
          'id': 'rice',
          'name': 'Rice',
          'categoryId': 'pantry',
          'categorySlug': 'pantry',
          'price': 120,
          'stock': 12,
          'rating': 4.6,
          'reviewCount': 21,
          'description': 'Everyday rice.',
          'weight': '1 kg',
        },
      ],
      'pagination': {'page': 1, 'limit': 100, 'total': 2},
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets("choosing an aisle opens only that aisle's products",
      (tester) async {
    final products = ProductProvider(apiService: _CategoryApi());
    await products.loadCatalog();
    products.setCatalogFilters(
      categorySlug: 'pantry',
      maxPrice: 100,
      minimumRating: 5,
      organicOnly: true,
    );
    addTearDown(products.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<ProductProvider>.value(
        value: products,
        child: ChangeNotifierProvider(
          create: (_) => CartProvider(),
          child: const MaterialApp(home: CategoriesScreen()),
        ),
      ),
    );

    await tester.tap(find.text('Fresh'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Leafy greens'), findsOneWidget);
    expect(find.text('Leafy greens'), findsOneWidget);
    expect(find.text('Rice'), findsNothing);
  });

  testWidgets(
      'last aisle stays clear of floating navigation on compact screens',
      (tester) async {
    tester.view.physicalSize = const Size(435, 545);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final products = ProductProvider(apiService: _CategoryApi());
    await products.loadCatalog();
    addTearDown(products.dispose);
    final api = _CategoryApi();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>.value(value: api),
          ChangeNotifierProvider(
            create: (_) => AuthProvider(apiService: api),
          ),
          ChangeNotifierProvider<ProductProvider>.value(value: products),
          ChangeNotifierProvider(create: (_) => CartProvider()),
          ChangeNotifierProvider(
            create: (_) => OrderProvider(apiService: api),
          ),
          ChangeNotifierProvider(
            create: (_) => StoreAvailabilityProvider(apiService: api),
          ),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const MaterialApp(home: MainBottomNav(initialIndex: 1)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final pageBody =
        tester.getRect(find.byKey(const ValueKey('main-bottom-nav-body')));
    expect(pageBody.height, greaterThan(100));
    expect(
      tester
          .getRect(find.byKey(const ValueKey('categories-screen-scroll')))
          .height,
      greaterThan(100),
    );
    expect(find.text('All Grocery Aisles'), findsOneWidget);

    final navigationBounds =
        tester.getRect(find.byKey(const ValueKey('floating-nav-capsule')));
    expect(navigationBounds.bottom, greaterThan(500));
    expect(pageBody.bottom, greaterThan(navigationBounds.top));

    final categoryScroll = find.descendant(
      of: find.byKey(const ValueKey('categories-screen-scroll')),
      matching: find.byType(Scrollable),
    );
    final scrollPosition =
        tester.state<ScrollableState>(categoryScroll).position;
    scrollPosition.jumpTo(scrollPosition.maxScrollExtent);
    await tester.pumpAndSettle();
    final lastAisle = find
        .ancestor(
          of: find.text('Pen'),
          matching: find.byType(Material),
        )
        .first;
    final aisleBounds = tester.getRect(lastAisle);

    expect(
      aisleBounds.bottom,
      lessThanOrEqualTo(navigationBounds.top),
      reason:
          'Last aisle $aisleBounds must remain above navigation $navigationBounds.',
    );
    expect(tester.takeException(), isNull);
  });
}
