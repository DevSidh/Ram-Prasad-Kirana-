import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freshharvest_grocery/core/theme.dart';
import 'package:freshharvest_grocery/providers/auth_provider.dart';
import 'package:freshharvest_grocery/providers/theme_provider.dart';
import 'package:freshharvest_grocery/screens/auth/login_screen.dart';
import 'package:freshharvest_grocery/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('login survives light and dark theme changes', (tester) async {
    final apiService = ApiService();
    final authProvider = AuthProvider(apiService: apiService);
    final themeProvider = ThemeProvider();
    addTearDown(authProvider.dispose);
    addTearDown(themeProvider.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>.value(value: apiService),
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ],
        child: Consumer<ThemeProvider>(
          builder: (context, theme, _) => MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: theme.themeMode,
            home: const LoginScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.light_mode_outlined));
    await tester.pumpAndSettle();
    expect(themeProvider.isDarkMode, isFalse);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.dark_mode_outlined));
    await tester.pumpAndSettle();
    expect(themeProvider.isDarkMode, isTrue);
    expect(tester.takeException(), isNull);
  });
}
