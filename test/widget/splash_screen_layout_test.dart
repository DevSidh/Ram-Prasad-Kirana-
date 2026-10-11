import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freshharvest_grocery/providers/auth_provider.dart';
import 'package:freshharvest_grocery/screens/splash_screen.dart';
import 'package:freshharvest_grocery/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('splash screen tolerates zero-width startup metrics',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthProvider(apiService: ApiService());
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size.zero),
            child: SplashScreen(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
