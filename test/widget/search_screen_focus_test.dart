import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freshharvest_grocery/providers/product_provider.dart';
import 'package:freshharvest_grocery/screens/search/search_screen.dart';
import 'package:freshharvest_grocery/services/api_service.dart';

class _SearchApi extends ApiService {
  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    if (endpoint == '/categories') return {'data': <dynamic>[]};
    return {
      'data': <dynamic>[],
      'pagination': {'page': 1, 'limit': 100, 'total': 0},
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('search keyboard opens only when the search field is tapped',
      (tester) async {
    final products = ProductProvider(apiService: _SearchApi());
    addTearDown(products.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<ProductProvider>.value(
        value: products,
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
    await tester.pump();

    expect(tester.testTextInput.isVisible, isFalse);

    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(tester.testTextInput.isVisible, isTrue);
  });
}
