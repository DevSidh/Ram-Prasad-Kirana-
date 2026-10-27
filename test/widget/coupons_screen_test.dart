import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freshharvest_grocery/core/constants.dart';
import 'package:freshharvest_grocery/providers/auth_provider.dart';
import 'package:freshharvest_grocery/providers/cart_provider.dart';
import 'package:freshharvest_grocery/screens/coupons/coupons_screen.dart';
import 'package:freshharvest_grocery/services/api_service.dart';

class _CouponsApi extends ApiService {
  @override
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    if (endpoint == '/coupons/offer') {
      return {
        'offer': {
          'enabled': true,
          'discountType': 'PERCENTAGE',
          'percent': 20,
          'maxDiscount': 150,
          'minOrderAmount': 500,
          'code': 'DIWALI50',
          'id': 'offer-1',
          'endsAt': null,
        },
      };
    }
    if (endpoint == '/account/notifications') {
      return {
        'data': [
          {
            'id': 'notification-1',
            'title': 'A coupon for you',
            'metadata': {'couponCode': 'SAVE20'},
          },
          {
            'id': 'notification-2',
            'title': 'Duplicate code',
            'metadata': {'couponCode': 'DIWALI50'},
          },
        ],
      };
    }
    if (endpoint == '/account/coupons/available') {
      return {
        'availableCouponCodes': ['DIWALI50', 'SAVE20'],
      };
    }
    throw StateError('Unexpected endpoint: $endpoint');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows active and notification coupons without duplicates',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyToken: 'test-token',
      AppConstants.keyUser: jsonEncode({
        'id': 'customer-1',
        'email': 'customer@example.test',
        'fullName': 'Test Customer',
        'role': 'CUSTOMER',
      }),
    });
    final api = _CouponsApi();
    final auth = AuthProvider(apiService: api);
    final cart = CartProvider(apiService: api);
    addTearDown(auth.dispose);
    addTearDown(cart.dispose);
    await auth.sessionReady;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>.value(value: api),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<CartProvider>.value(value: cart),
        ],
        child: const MaterialApp(home: CouponsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Coupons'), findsOneWidget);
    expect(find.text('Current store offer'), findsOneWidget);
    expect(find.text('DIWALI50'), findsOneWidget);
    expect(find.text('A coupon for you'), findsOneWidget);
    expect(find.text('SAVE20'), findsOneWidget);
    expect(find.text('Duplicate code'), findsNothing);
    expect(find.textContaining('checkout will confirm'), findsOneWidget);
    expect(find.textContaining('Shared with you'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('using a coupon saves it for checkout and returns to the caller',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = _CouponsApi();
    final auth = AuthProvider(apiService: api);
    final cart = CartProvider(apiService: api);
    addTearDown(auth.dispose);
    addTearDown(cart.dispose);
    await auth.sessionReady;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>.value(value: api),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<CartProvider>.value(value: cart),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const CouponsScreen(),
                  ),
                ),
                child: const Text('Open coupons'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open coupons'));
    await tester.pumpAndSettle();
    expect(find.text('DIWALI50'), findsOneWidget);

    await tester.tap(find.text('Add coupon to cart'));
    await tester.pumpAndSettle();

    expect(cart.suggestedCouponCode, 'DIWALI50');
    expect(find.text('Open coupons'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
