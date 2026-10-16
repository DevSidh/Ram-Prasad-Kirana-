import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freshharvest_grocery/core/constants.dart';
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

  testWidgets('search history is saved and removable', (tester) async {
    final products = ProductProvider(apiService: _SearchApi());
    addTearDown(products.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<ProductProvider>.value(
        value: products,
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), '  Apples  ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(
        preferences.getStringList(AppConstants.keySearchHistory), ['Apples']);
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();

    expect(find.text('Recent searches'), findsOneWidget);
    expect(find.text('Apples'), findsOneWidget);

    expect(find.text('Featured products'), findsNothing);
    await tester.tap(find.byTooltip('Remove from search history'));
    await tester.pumpAndSettle();
    expect(find.text('No recent searches'), findsOneWidget);
    expect(preferences.getStringList(AppConstants.keySearchHistory), isEmpty);
  });

  testWidgets('Home search overlay has a working close action', (tester) async {
    final products = ProductProvider(apiService: _SearchApi());
    addTearDown(products.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<ProductProvider>.value(
        value: products,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showSearchOverlay(context),
                child: const Text('Open search'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open search'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Close search'), findsOneWidget);
    await tester.tap(find.byTooltip('Close search'));
    await tester.pumpAndSettle();
    expect(find.text('Open search'), findsOneWidget);
  });
}
