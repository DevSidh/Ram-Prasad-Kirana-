import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:freshharvest_grocery/providers/cart_provider.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
}
