import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freshharvest_grocery/providers/auth_provider.dart';
import 'package:freshharvest_grocery/providers/cart_provider.dart';
import 'package:freshharvest_grocery/providers/order_provider.dart';
import 'package:freshharvest_grocery/providers/product_provider.dart';
import 'package:freshharvest_grocery/services/api_service.dart';
import 'package:freshharvest_grocery/navigation/main_bottom_nav.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('customer navigation switches smoothly between five destinations',
      (tester) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final apiService = ApiService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>.value(value: apiService),
          ChangeNotifierProvider(
            create: (_) => AuthProvider(apiService: apiService),
          ),
          ChangeNotifierProvider(
            create: (_) => ProductProvider(apiService: apiService),
          ),
          ChangeNotifierProvider(create: (_) => CartProvider()),
          ChangeNotifierProvider(
            create: (_) => OrderProvider(apiService: apiService),
          ),
        ],
        child: const MaterialApp(home: MainBottomNav()),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Cart'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Account'), findsNothing);
    expect(find.text('Admin'), findsNothing);
    expect(find.text('Featured for Janakpur'), findsOneWidget);
    expect(find.text('India Gate Classic Basmati Rice'), findsNothing);

    await tester.tap(find.text('Categories'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('All Grocery Aisles'), findsOneWidget);

    await tester.tap(find.text('Search'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(TextField), findsWidgets);

    await tester.tap(find.text('Cart'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Your basket is empty'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Saved items'), findsOneWidget);
    expect(find.text('Store administration'), findsOneWidget);

    await tester.tap(find.text('Saved items'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.widgetWithText(AppBar, 'Saved items'),
      findsOneWidget,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Sign in with an admin account'));
    await tester.pump();
    await tester.tap(find.text('Sign in with an admin account'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Admin sign in'), findsOneWidget);
    expect(find.text('Admin username or email'), findsOneWidget);
    await tester.ensureVisible(find.text('Back to customer sign in'));
    await tester.pump();
    await tester.tap(find.text('Back to customer sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Admin login'), findsOneWidget);
    expect(find.text('Delivery staff'), findsNothing);
  });
}
