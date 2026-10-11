import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freshharvest_grocery/providers/cart_provider.dart';
import 'package:freshharvest_grocery/providers/order_provider.dart';
import 'package:freshharvest_grocery/screens/checkout/checkout_screen.dart';
import 'package:freshharvest_grocery/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('checkout only offers the supported COD payment method',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final apiService = ApiService(
      client: MockClient((request) async {
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
        ],
        child: const MaterialApp(home: CheckoutScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue').first);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'The store will confirm your delivery timing after you place the order.',
      ),
      findsOneWidget,
    );
    expect(find.text('Express 45-Min Fast Track (Today)'), findsNothing);

    await tester.tap(find.text('Continue').first);
    await tester.pumpAndSettle();

    expect(find.text('Cash on Delivery (COD)'), findsOneWidget);
    expect(find.text('Khalti Digital Wallet'), findsNothing);
    expect(find.text('eSewa Mobile Wallet'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
