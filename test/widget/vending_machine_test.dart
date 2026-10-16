import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freshharvest_grocery/providers/cart_provider.dart';
import 'package:freshharvest_grocery/screens/vending/vending_machine_screen.dart';
import 'package:freshharvest_grocery/services/api_service.dart';

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
        {
          'id': 'cola-1',
          'name': 'Cola',
          'categoryId': 'drinks',
          'price': 60,
          'stock': 5,
          'unitLabel': '330 ml',
          'description': 'Chilled cola.',
          'imageUrl': '',
          'isVendingDrink': true,
        },
        {
          'id': 'rice-1',
          'name': 'Rice',
          'categoryId': 'pantry',
          'price': 120,
          'stock': 8,
          'unitLabel': '1 kg',
          'description': '',
          'imageUrl': '',
          'isVendingDrink': false,
        },
      ],
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('loads admin-selected drinks and adds them to the real cart',
      (tester) async {
    final api = _VendingApi();
    final cart = CartProvider();
    addTearDown(cart.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>.value(value: api),
          ChangeNotifierProvider<CartProvider>.value(value: cart),
        ],
        child: const MaterialApp(home: VendingMachineScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.requestedQuery, {
      'vendingDrink': 'true',
      'page': '1',
      'limit': '100',
    });
    expect(find.text('Cola'), findsOneWidget);
    expect(find.text('Rice'), findsNothing);
    expect(find.text('Fresh drinks\nanytime'), findsOneWidget);

    await tester.tap(find.text('Cola'));
    await tester.pumpAndSettle();
    expect(find.text('Chilled cola.'), findsOneWidget);

    await tester.tap(find.text('Add to cart'));
    await tester.pumpAndSettle();

    expect(cart.itemCount, 1);
    expect(cart.itemList.single.product.name, 'Cola');
    expect(find.text('Added 1 × Cola to cart.'), findsOneWidget);
  });

  testWidgets('keeps the vending machine visible when it has no drinks',
      (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>.value(value: _VendingApi(empty: true)),
          ChangeNotifierProvider<CartProvider>(
            create: (_) => CartProvider(),
          ),
        ],
        child: const MaterialApp(home: VendingMachineScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ram Prasad'), findsOneWidget);
    expect(find.textContaining('The machine is being stocked'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
