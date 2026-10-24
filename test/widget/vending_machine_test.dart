import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freshharvest_grocery/providers/cart_provider.dart';
import 'package:freshharvest_grocery/providers/product_provider.dart';
import 'package:freshharvest_grocery/screens/vending/vending_machine_screen.dart';
import 'package:freshharvest_grocery/screens/vending/drinks_menu_section.dart';
import 'package:freshharvest_grocery/services/api_service.dart';
import 'package:freshharvest_grocery/widgets/product_card.dart';

const _drinks = <String>[
  'Cola',
  'Lime Fizz',
  'Orange',
  'Milk Tea',
  'Choco Milk',
  'Matcha Latte',
  'Kiwi Crush',
  'Energy Boost',
  'Peach Tea',
  'Mango Lassi',
  'Blueberry Soda',
  'Lemon Iced Tea',
  'Coconut Water',
  'Cold Coffee',
  'Ginger Ale',
  'Grape Fizz',
  'Green Apple',
  'Mineral Water',
];

class _VendingApi extends ApiService {
  final bool empty;
  Map<String, String>? requestedQuery;

  _VendingApi({this.empty = false});

  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    expect(endpoint, '/products');
    requestedQuery = queryParams;
    if (empty) return {'data': []};
    return {
      'data': [
        for (var index = 0; index < _drinks.length; index++)
          {
            'id': 'drink-$index',
            'name': _drinks[index],
            'categoryId': 'drinks',
            'categoryName': _categoryFor(index),
            'categorySlug': _categoryFor(index).toLowerCase(),
            'price': 60 + index,
            'stock': index == 0 || index == 17 ? 0 : (index == 1 ? 2 : 5),
            'unitLabel': '330 ml',
            'description': 'Chilled drink, made for a refreshing break.',
            'imageUrl': '',
            'isBestSeller': index == 0,
            'isVendingDrink': true,
            if (index == 3) 'vendingSection': 'TEA_COFFEE',
          },
      ],
    };
  }

  static String _categoryFor(int index) {
    return switch (index) {
      3 || 4 || 9 => 'Milk',
      5 || 8 || 11 || 13 => 'Tea & Coffee',
      7 => 'Energy',
      12 || 17 => 'Water',
      _ => 'Soda',
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    _VendingApi api,
    CartProvider cart, {
    Size size = const Size(360, 800),
    double textScale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final products = ProductProvider(apiService: api);
    addTearDown(products.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>.value(value: api),
          ChangeNotifierProvider<CartProvider>.value(value: cart),
          ChangeNotifierProvider<ProductProvider>.value(value: products),
        ],
        child: MaterialApp(
          theme: brightness == Brightness.dark
              ? ThemeData.dark(useMaterial3: true)
              : ThemeData.light(useMaterial3: true),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
              ),
              child: const VendingMachineScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows home-style drink cards and keeps category/cart behavior',
      (tester) async {
    final api = _VendingApi();
    final cart = CartProvider();
    addTearDown(cart.dispose);

    await pumpScreen(tester, api, cart);

    expect(api.requestedQuery, {
      'vendingDrink': 'true',
      'page': '1',
      'limit': '100',
    });

    expect(find.text('14 drinks'), findsOneWidget);
    expect(find.text('Cola'), findsWidgets);
    expect(find.text('Milk Tea'), findsWidgets);
    expect(find.text('Mineral Water'), findsNothing);
    expect(find.byKey(const ValueKey('drink-category-Milk')), findsNothing);
    expect(find.byKey(const ValueKey('drink-category-Water')), findsNothing);
    expect(find.byType(ProductCard), findsWidgets);
    expect(
      tester.widgetList<ProductCard>(find.byType(ProductCard)).every(
            (card) => card.compact && card.compactImageHeight == 100,
          ),
      isTrue,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('drink-category-Tea & Coffee')));
    await tester.pumpAndSettle();
    expect(find.text('5 drinks'), findsOneWidget);
    expect(find.text('Milk Tea'), findsWidgets);
    expect(find.text('Matcha Latte'), findsOneWidget);
    expect(find.text('Cola'), findsNothing);
    expect(tester.takeException(), isNull);

    final drinkCard = find.byKey(const ValueKey('drink-5'));
    final addButton = find.descendant(
      of: drinkCard,
      matching: find.byTooltip('Add to basket'),
    );
    await tester.tap(addButton);
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Matcha Latte'), findsWidgets);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(cart.itemCount, 2);
    expect(cart.itemList.single.product.name, 'Matcha Latte');
  });

  testWidgets('shows featured drink first and keeps catalog order below',
      (tester) async {
    final cart = CartProvider();
    addTearDown(cart.dispose);
    await pumpScreen(tester, _VendingApi(), cart);

    expect(find.byType(DrinkCard), findsOneWidget);
    expect(find.text('Featured drink'), findsOneWidget);
    expect(find.text('Cola'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('drink-0')), findsOneWidget);
    final gridProducts = tester.widgetList<ProductCard>(
      find.byType(ProductCard),
    );
    expect(gridProducts.first.product.name, 'Cola');
    final featuredBackground = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('featured-drink-white-stage')),
    );
    expect(
      (featuredBackground.decoration as BoxDecoration).color,
      Colors.white,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits 360x800 and keeps every grid card inside the viewport',
      (tester) async {
    final cart = CartProvider();
    addTearDown(cart.dispose);
    await pumpScreen(tester, _VendingApi(), cart);

    final cards = find.byType(ProductCard);
    expect(cards, findsWidgets);
    for (final card in tester.widgetList<Widget>(cards)) {
      final rect = tester.getRect(find.byWidget(card));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(360));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits 440x956 with long product names', (tester) async {
    final cart = CartProvider();
    addTearDown(cart.dispose);
    await pumpScreen(
      tester,
      _VendingApi(),
      cart,
      size: const Size(440, 956),
      textScale: 2,
    );

    expect(find.byKey(const ValueKey('drink-category-Milk')), findsNothing);
    expect(tester.takeException(), isNull);
    for (final card in tester.widgetList<Widget>(find.byType(ProductCard))) {
      final rect = tester.getRect(find.byWidget(card));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(440));
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('uses $brightness text and surfaces in the drink menu',
        (tester) async {
      final cart = CartProvider();
      addTearDown(cart.dispose);
      await pumpScreen(
        tester,
        _VendingApi(),
        cart,
        brightness: brightness,
      );
      await tester.tap(
        find.byKey(const ValueKey('drink-category-Tea & Coffee')),
      );
      await tester.pumpAndSettle();

      final card = find.ancestor(
        of: find.text('Matcha Latte'),
        matching: find.byType(ProductCard),
      );
      final theme = Theme.of(tester.element(card));
      final isDark = brightness == Brightness.dark;
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        isDark ? const Color(0xFF101316) : Colors.white,
      );
      final name = find.text('Matcha Latte');
      expect(
          tester.widget<Text>(name).style?.color, theme.colorScheme.onSurface);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('sold-out drinks cannot be added to the cart', (tester) async {
    final cart = CartProvider();
    addTearDown(cart.dispose);
    await pumpScreen(tester, _VendingApi(), cart);

    expect(find.text('Sold out'), findsWidgets);
    expect(cart.itemCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a clear empty state when there are no drinks',
      (tester) async {
    final cart = CartProvider();
    addTearDown(cart.dispose);
    await pumpScreen(tester, _VendingApi(empty: true), cart);

    expect(find.text('No drinks in this category yet.'), findsOneWidget);
    expect(find.text('0 drinks'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
