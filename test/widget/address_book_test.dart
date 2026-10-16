import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:freshharvest_grocery/screens/profile/address_book_screen.dart';
import 'package:freshharvest_grocery/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('new address saves without a map pin and appears in the list',
      (tester) async {
    Map<String, dynamic>? savedAddress;
    final api = ApiService(
      client: MockClient((request) async {
        if (request.method == 'POST') {
          savedAddress = {
            'id': 'address-1',
            ...(jsonDecode(request.body) as Map<String, dynamic>),
          };
          return http.Response(
            jsonEncode({'data': savedAddress}),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        expect(request.url.path, endsWith('/account/addresses'));
        return http.Response(
          jsonEncode({
            'data': savedAddress == null ? [] : [savedAddress]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(
      Provider<ApiService>.value(
        value: api,
        child: const MaterialApp(home: AddressBookScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add address'));
    await tester.pumpAndSettle();

    Future<void> enterField(String label, String value) async {
      final field = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      );
      await tester.ensureVisible(field);
      await tester.enterText(field, value);
    }

    await enterField('Recipient name', 'Ram Prasad');
    await enterField('Phone number', '9800000000');
    await enterField('Ward, street, and house details', 'Ward 4, Main Road');
    await enterField('City / municipality', 'Janakpur');
    final saveButton = find.widgetWithText(FilledButton, 'Save address');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(savedAddress?['latitude'], isNull);
    expect(find.text('Ram Prasad'), findsOneWidget);
    expect(find.textContaining('Ward 4, Main Road, Janakpur'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
