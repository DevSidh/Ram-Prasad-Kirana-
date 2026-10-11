import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freshharvest_grocery/providers/cart_provider.dart';
import 'package:freshharvest_grocery/providers/product_provider.dart';
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
}
