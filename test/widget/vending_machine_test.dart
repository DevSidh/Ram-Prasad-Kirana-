import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freshharvest_grocery/providers/cart_provider.dart';
import 'package:freshharvest_grocery/screens/vending/vending_machine_screen.dart';
import 'package:freshharvest_grocery/screens/vending/drinks_menu_section.dart';
import 'package:freshharvest_grocery/services/api_service.dart';

const _drinks = <String>[
  'Cola',
  'Lime Fizz',
  'Orange',
  'Strawberry Milk Special',
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

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>.value(value: api),
          ChangeNotifierProvider<CartProvider>.value(value: cart),
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

  testWidgets('shows live drinks, filters categories, and adjusts cart inline',
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
    expect(find.text('18 drinks'), findsOneWidget);
    expect(find.text('Cola'), findsOneWidget);
    expect(find.text('Strawberry Milk Special'), findsNothing);
    final featuredCard = find.byWidgetPredicate(
      (widget) => widget is DrinkCard && widget.featured,
    );
    expect(featuredCard, findsOneWidget);
    expect(tester.getSize(featuredCard).width, 328);
    final featuredStage = find.descendant(
      of: featuredCard,
      matching: find.byType(DrinkStage),
    );
    expect(
      find.descendant(
        of: featuredStage,
        matching: find.byWidgetPredicate(
          (widget) => widget is ColoredBox && widget.color == Colors.white,
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: featuredStage,
        matching: find.byType(Transform),
      ),
      findsNothing,
    );
    final normalCards = find.byWidgetPredicate(
      (widget) => widget is DrinkCard && !widget.featured,
    );
    final cardSizes = tester.widgetList<Widget>(normalCards).map(
          (card) => tester.getSize(find.byWidget(card)),
        );
    expect(cardSizes.toSet().length, 1);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('drink-category-Milk')));
    await tester.pumpAndSettle();
    expect(find.text('3 drinks'), findsOneWidget);
    expect(find.text('Strawberry Milk Special'), findsOneWidget);
    expect(find.text('Cola'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('add-drink-drink-3')));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Strawberry Milk Special'), findsWidgets);

    await tester.tap(find.byTooltip('Increase Strawberry Milk Special'));
    await tester.pumpAndSettle();

    expect(cart.itemCount, 2);
    expect(cart.itemList.single.product.name, 'Strawberry Milk Special');
  });

  testWidgets('fits 360x800 and keeps every grid card inside the viewport',
      (tester) async {
    final cart = CartProvider();
    addTearDown(cart.dispose);
    await pumpScreen(tester, _VendingApi(), cart);

    final cards = find.byType(DrinkCard);
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

    await tester.tap(find.byKey(const ValueKey('drink-category-Milk')));
    await tester.pumpAndSettle();
    expect(find.text('Strawberry Milk Special'), findsOneWidget);
    expect(tester.takeException(), isNull);
    for (final card in tester.widgetList<Widget>(find.byType(DrinkCard))) {
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
      await tester.tap(find.byKey(const ValueKey('drink-category-Milk')));
      await tester.pumpAndSettle();

      final info = find.ancestor(
        of: find.text('Strawberry Milk Special'),
        matching: find.byType(DrinkInfoPlate),
      );
      final theme = Theme.of(tester.element(info));
      final isDark = brightness == Brightness.dark;
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        isDark ? const Color(0xFF101316) : Colors.white,
      );
      final name = find.text('Strawberry Milk Special');
      expect(
          tester.widget<Text>(name).style?.color, theme.colorScheme.onSurface);
      final card = tester.widget<AnimatedContainer>(
        find
            .ancestor(
              of: info,
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      expect(
        (card.decoration! as BoxDecoration).color,
        theme.colorScheme.surface,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('greys out sold-out drinks and disables add control',
      (tester) async {
    final cart = CartProvider();
    addTearDown(cart.dispose);
    await pumpScreen(tester, _VendingApi(), cart);

    final soldOutButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('sold-out-drink-drink-0')),
    );
    expect(soldOutButton.onPressed, isNull);
    expect(find.text('Sold out'), findsNWidgets(2));
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
