import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freshharvest_grocery/providers/cart_provider.dart';
import 'package:freshharvest_grocery/providers/order_provider.dart';
import 'package:freshharvest_grocery/providers/theme_provider.dart';
import 'package:freshharvest_grocery/core/constants.dart';
import 'package:freshharvest_grocery/models/product.dart';
import 'package:freshharvest_grocery/screens/checkout/checkout_screen.dart';
import 'package:freshharvest_grocery/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('checkout only offers the supported COD payment method',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    AppConstants.setDarkTheme(true);
    addTearDown(() => AppConstants.setDarkTheme(true));
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final themeProvider = ThemeProvider();
    addTearDown(themeProvider.dispose);
    final apiService = ApiService(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/account/delivery-quote')) {
          return http.Response(
            jsonEncode({'deliveryFee': 40}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        expect(request.url.path, endsWith('/account/addresses'));
        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 'address-1',
                'title': 'Home',
                'fullName': 'Customer',
                'phone': '9800000000',
                'province': 'Bagmati',
                'city': 'Kathmandu',
                'street': 'Main Road',
                'latitude': 27.7172,
                'longitude': 85.3240,
                'isDefault': true,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>.value(value: apiService),
          ChangeNotifierProvider(create: (_) => CartProvider()),
          ChangeNotifierProvider(
            create: (_) => OrderProvider(apiService: apiService),
          ),
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ],
        child: const MaterialApp(home: CheckoutScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final checkoutScaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(checkoutScaffold.backgroundColor, const Color(0xFFF6FAF7));
    expect(checkoutScaffold.extendBody, isTrue);
    expect(checkoutScaffold.extendBodyBehindAppBar, isTrue);
    final footer = checkoutScaffold.bottomNavigationBar! as Material;
    expect(footer.type, MaterialType.transparency);
    expect(footer.elevation, 0);

    final placeOrderButton = find.ancestor(
      of: find.text('Place order'),
      matching: find.byType(ElevatedButton),
    );
    expect(tester.widget<ElevatedButton>(placeOrderButton).onPressed, isNull);
    expect(
      tester.widget<Text>(find.text('Home')).style?.color,
      AppConstants.textDark,
    );
    expect(
      tester.widget<Text>(find.text('Customer · 9800000000')).style?.color,
      AppConstants.textDark,
    );
    await themeProvider.setDarkMode(false);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('Customer · 9800000000')).style?.color,
      AppConstants.textDark,
    );

    final continueButton = find.ancestor(
      of: find.text('Continue').first,
      matching: find.byType(ElevatedButton),
    );
    await tester.ensureVisible(continueButton);
    expect(tester.widget<ElevatedButton>(continueButton).onPressed, isNotNull);
    tester.widget<ElevatedButton>(continueButton).onPressed!.call();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Instant Delivery'), findsOneWidget);
    expect(find.text('In about 2 hours'), findsOneWidget);
    expect(find.text('In about 4 hours'), findsOneWidget);
    expect(find.text('Choose date and time'), findsOneWidget);
    expect(find.textContaining('Nepal time'), findsOneWidget);
    expect(find.text('Express 45-Min Fast Track (Today)'), findsNothing);

    final paymentContinueButton = find.ancestor(
      of: find.text('Continue').first,
      matching: find.byType(ElevatedButton),
    );
    await tester.ensureVisible(paymentContinueButton);
    tester.widget<ElevatedButton>(paymentContinueButton).onPressed!.call();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.text('Cash on Delivery (COD)'), findsOneWidget);
    expect(find.text('Khalti Digital Wallet'), findsNothing);
    expect(find.text('eSewa Mobile Wallet'), findsNothing);
    tester.widget<ElevatedButton>(paymentContinueButton).onPressed!.call();
    await tester.pumpAndSettle();
    expect(find.text('Order Summary'), findsOneWidget);
    expect(find.text('Rs. 40'), findsAtLeastNWidgets(2));
    expect(
      tester.widget<ElevatedButton>(placeOrderButton).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('coupon selected on the coupons page is validated at checkout',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    AppConstants.setDarkTheme(true);
    addTearDown(() => AppConstants.setDarkTheme(true));
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Map<String, dynamic>? couponRequest;
    Map<String, dynamic>? orderRequest;
    var availabilityRequests = 0;
    var orderRequests = 0;
    final apiService = ApiService(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/account/addresses')) {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'address-1',
                  'title': 'Home',
                  'fullName': 'Customer',
                  'phone': '9800000000',
                  'province': 'Bagmati',
                  'city': 'Kathmandu',
                  'street': 'Main Road',
                  'latitude': 27.7172,
                  'longitude': 85.3240,
                  'isDefault': true,
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/account/delivery-quote')) {
          return http.Response(jsonEncode({'deliveryFee': 40}), 200);
        }
        if (request.url.path.endsWith('/coupons/validate')) {
          couponRequest = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'valid': true,
              'code': 'SAVE20',
              'discount': 20,
              'message': 'Coupon applied',
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/store/availability')) {
          availabilityRequests++;
          return http.Response(
            jsonEncode({
              'isOrderingEnabled': true,
              'isAcceptingOrders': true,
              'weeklyHours': [],
              'timeZone': 'Asia/Kathmandu',
              'statusMessage': 'Open',
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/orders')) {
          orderRequests++;
          orderRequest = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'error': 'Store is not accepting orders.'}),
            409,
          );
        }
        throw StateError('Unexpected endpoint: ${request.url.path}');
      }),
    );
    final cart = CartProvider()
      ..addItem(
        Product(
          id: 'product-1',
          name: 'Milk',
          categoryId: 'dairy',
          price: 100,
          weight: '1 pc',
          stock: 5,
          description: '',
          imageUrl: '',
        ),
      )
      ..suggestCouponCode('SAVE20');
    addTearDown(cart.dispose);
    final themeProvider = ThemeProvider();
    addTearDown(themeProvider.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>.value(value: apiService),
          ChangeNotifierProvider<CartProvider>.value(value: cart),
          ChangeNotifierProvider(
            create: (_) => OrderProvider(apiService: apiService),
          ),
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ],
        child: const MaterialApp(home: CheckoutScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(couponRequest?['code'], 'SAVE20');
    expect(couponRequest?['subtotal'], 100);
    expect(find.text('Coupon applied'), findsOneWidget);
    expect(cart.suggestedCouponCode, isNull);

    for (var step = 0; step < 3; step++) {
      final continueButton = find.ancestor(
        of: find.text('Continue').first,
        matching: find.byType(ElevatedButton),
      );
      await tester.ensureVisible(continueButton);
      tester.widget<ElevatedButton>(continueButton).onPressed!.call();
      await tester.pumpAndSettle();
    }

    expect(
      find.byWidgetPredicate(
        (widget) => widget is TextField && widget.controller?.text == 'SAVE20',
      ),
      findsOneWidget,
    );
    expect(find.text('Coupon discount'), findsOneWidget);
    expect(find.text('-Rs. 20'), findsOneWidget);

    final placeOrderButton = find.ancestor(
      of: find.text('Place order'),
      matching: find.byType(ElevatedButton),
    );
    tester.widget<ElevatedButton>(placeOrderButton).onPressed!.call();
    await tester.pumpAndSettle();

    expect(availabilityRequests, 0);
    expect(orderRequests, 1);
    expect(orderRequest?['couponCode'], 'SAVE20');
    expect(find.text('Store is not accepting orders.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
