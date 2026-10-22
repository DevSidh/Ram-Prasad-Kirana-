import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freshharvest_grocery/providers/cart_provider.dart';
import 'package:freshharvest_grocery/providers/product_provider.dart';
import 'package:freshharvest_grocery/screens/product/product_details_screen.dart';
import 'package:freshharvest_grocery/screens/wholesale/wholesale_screen.dart';
import 'package:freshharvest_grocery/services/api_service.dart';

class _WholesaleApi extends ApiService {
  int requests = 0;

  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    expect(endpoint, '/wholesale');
    requests++;
    return {
      'data': [
        {
          'id': 'bulk-rice',
          'name': 'Basmati rice',
          'sku': 'RICE-5KG',
          'categoryId': 'pantry',
          'categoryName': 'Pantry',
          'price': 1200,
          'stock': 30,
          'minimumQuantity': 5,
          'unitLabel': '5 kg bag',
          'description': 'Premium long-grain rice.',
          'imageUrl': '',
        },
      ],
    };
  }
}

class _WholesaleDetailsApi extends ApiService {
  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    if (endpoint == '/wholesale') {
      return {
        'data': [
          {
            'id': 'wholesale-rice',
            'name': 'Basmati rice',
            'sku': 'RICE-10',
            'categoryId': 'pantry',
            'categoryName': 'Pantry',
            'brand': 'Himalayan Farms',
            'price': 120,
            'rating': 4.5,
            'reviewCount': 4,
            'stock': 30,
            'minimumQuantity': 5,
            'unitLabel': '1 kg',
            'description': 'Aromatic long-grain rice.',
            'imageUrl': '',
          },
        ],
      };
    }
    return {'data': []};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('searches bulk products and adds the required minimum quantity',
      (tester) async {
    final api = _WholesaleApi();
    final cart = CartProvider(apiService: api);
    addTearDown(cart.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>.value(value: api),
          ChangeNotifierProvider<CartProvider>.value(value: cart),
        ],
        child: const MaterialApp(home: WholesaleScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Basmati rice'), findsOneWidget);
    expect(find.text('Add 5'), findsOneWidget);
    await tester.tap(find.text('Add 5'));
    await tester.pump();
    expect(cart.itemCount, 5);
    expect(cart.itemList.single.isWholesale, isTrue);
    expect(find.text('5 in basket'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      'oil',
    );
    await tester.pump();
    expect(find.textContaining('No wholesale products match'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    expect(find.text('Basmati rice'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens wholesale product details with brand and rating',
      (tester) async {
    final api = _WholesaleDetailsApi();
    final products = ProductProvider(apiService: api);
    final cart = CartProvider(apiService: api);
    addTearDown(products.dispose);
    addTearDown(cart.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>.value(value: api),
          ChangeNotifierProvider<ProductProvider>.value(value: products),
          ChangeNotifierProvider<CartProvider>.value(value: cart),
        ],
        child: const MaterialApp(home: WholesaleScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('HIMALAYAN FARMS'), findsOneWidget);
    expect(find.text('4.5 · 4 ratings'), findsOneWidget);
    await tester.tap(find.text('Basmati rice').first);
    await tester.pumpAndSettle();

    expect(find.byType(ProductDetailsScreen), findsOneWidget);
    expect(find.text('HIMALAYAN FARMS'), findsOneWidget);
    expect(find.text('4.5'), findsOneWidget);
    expect(find.text('Rate this product'), findsOneWidget);
    expect(find.text('Wholesale unit · minimum 5'), findsOneWidget);
    await tester.tap(find.text('Add to Cart'));
    await tester.pump();
    expect(cart.itemList.single.isWholesale, isTrue);
    expect(cart.itemList.single.quantity, 5);
    expect(tester.takeException(), isNull);
  });
}
