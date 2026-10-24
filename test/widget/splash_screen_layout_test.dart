import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freshharvest_grocery/providers/auth_provider.dart';
import 'package:freshharvest_grocery/providers/cart_provider.dart';
import 'package:freshharvest_grocery/providers/product_provider.dart';
import 'package:freshharvest_grocery/providers/store_availability_provider.dart';
import 'package:freshharvest_grocery/screens/onboarding_screen.dart';
import 'package:freshharvest_grocery/screens/splash_screen.dart';
import 'package:freshharvest_grocery/services/api_service.dart';

class _StartupApi extends ApiService {
  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    if (endpoint == '/store/availability') {
      return {
        'isOrderingEnabled': true,
        'isAcceptingOrders': true,
        'weeklyHours': [],
        'timeZone': 'Asia/Kolkata',
        'statusMessage': '',
      };
    }
    if (endpoint == '/categories') return {'data': []};
    if (endpoint == '/products') {
      return {
        'data': [],
        'pagination': {'limit': 100, 'total': 0},
      };
    }
    throw StateError('Unexpected startup endpoint $endpoint');
  }
}

class _SlowCatalogApi extends ApiService {
  final _neverCompletes = Completer<dynamic>();

  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) {
    return _neverCompletes.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('splash screen tolerates zero-width startup metrics',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthProvider(apiService: ApiService());
    final products = ProductProvider(apiService: _StartupApi());
    final cart = CartProvider();
    final availability =
        StoreAvailabilityProvider(apiService: _StartupApi());
    addTearDown(auth.dispose);
    addTearDown(products.dispose);
    addTearDown(cart.dispose);
    addTearDown(availability.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<ProductProvider>.value(value: products),
          ChangeNotifierProvider<CartProvider>.value(value: cart),
          ChangeNotifierProvider<StoreAvailabilityProvider>.value(
            value: availability,
          ),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size.zero),
            child: SplashScreen(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1499));
    expect(
      find.byKey(const ValueKey('scooter-loading-screen')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('startup continues while the product catalog is unavailable',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthProvider(apiService: ApiService());
    final products = ProductProvider(apiService: _SlowCatalogApi());
    final cart = CartProvider();
    final availability =
        StoreAvailabilityProvider(apiService: _SlowCatalogApi());
    addTearDown(auth.dispose);
    addTearDown(products.dispose);
    addTearDown(cart.dispose);
    addTearDown(availability.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<ProductProvider>.value(value: products),
          ChangeNotifierProvider<CartProvider>.value(value: cart),
          ChangeNotifierProvider<StoreAvailabilityProvider>.value(
            value: availability,
          ),
        ],
        child: const MaterialApp(home: SplashScreen()),
      ),
    );
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
