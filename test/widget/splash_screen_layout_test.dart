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
import 'package:freshharvest_grocery/widgets/store_animation.dart';

class _StartupApi extends ApiService {
  final requestedEndpoints = <String>[];

  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    requestedEndpoints.add(endpoint);
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
    final api = _StartupApi();
    final products = ProductProvider(apiService: api);
    final cart = CartProvider();
    final availability = StoreAvailabilityProvider(apiService: api);
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
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byType(StoreAnimation), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();

    expect(api.requestedEndpoints, contains('/store/availability'));
    expect(api.requestedEndpoints, contains('/categories'));
    expect(api.requestedEndpoints, contains('/products'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('startup does not wait for unavailable remote warm-ups',
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
    await tester.pump(const Duration(milliseconds: 1500));
    expect(
      find.byKey(const ValueKey('scooter-loading-screen')),
      findsOneWidget,
    );
    expect(find.byType(CustomPaint), findsWidgets);
    await tester.pump(const Duration(milliseconds: 6500));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
