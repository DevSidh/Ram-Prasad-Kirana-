import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freshharvest_grocery/providers/auth_provider.dart';
import 'package:freshharvest_grocery/screens/auth/login_screen.dart';
import 'package:freshharvest_grocery/screens/auth/register_screen.dart';
import 'package:freshharvest_grocery/services/api_service.dart';

class _RegisterApi extends ApiService {
  final String? registrationError;

  _RegisterApi({this.registrationError});

  @override
  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    if (endpoint == '/auth/register') {
      if (registrationError != null) throw Exception(registrationError);
      return {
        'requiresEmailVerification': true,
        'email': body['email'],
      };
    }
    if (endpoint == '/auth/email-verification/request') {
      return {'message': 'A code has been sent.'};
    }
    throw StateError('Unexpected request: $endpoint');
  }
}

void main() {
  testWidgets('registration failure is shown on the create-account screen',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthProvider(
      apiService: _RegisterApi(registrationError: 'Email is already in use.'),
    );
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(home: RegisterScreen()),
      ),
    );
    await auth.sessionReady;
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Customer Name');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'customer@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), '9812345678');
    await tester.enterText(find.byType(TextFormField).at(3), 'password123');
    await tester.enterText(find.byType(TextFormField).at(4), 'password123');
    await tester.ensureVisible(find.text('Register & Continue'));
    await tester.tap(find.text('Register & Continue'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('registration-error')), findsOneWidget);
    expect(find.text('Email is already in use.'), findsOneWidget);
  });

  testWidgets('successful registration opens email verification',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthProvider(apiService: _RegisterApi());
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(home: RegisterScreen()),
      ),
    );
    await auth.sessionReady;
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Customer Name');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'customer@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), '9812345678');
    await tester.enterText(find.byType(TextFormField).at(3), 'password123');
    await tester.enterText(find.byType(TextFormField).at(4), 'password123');
    await tester.ensureVisible(find.text('Register & Continue'));
    await tester.tap(find.text('Register & Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Verify your email'), findsOneWidget);
    expect(find.text('Send a new code'), findsOneWidget);
  });

  testWidgets('login provides a route to email verification', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthProvider(apiService: _RegisterApi());
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await auth.sessionReady;
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('login-email-verification')));
    await tester.pumpAndSettle();

    expect(find.text('Verify your email'), findsOneWidget);
    expect(find.text('Send verification code'), findsOneWidget);
  });
}
