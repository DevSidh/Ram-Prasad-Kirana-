import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freshharvest_grocery/core/constants.dart';
import 'package:freshharvest_grocery/providers/cart_provider.dart';
import 'package:freshharvest_grocery/providers/theme_provider.dart';
import 'package:freshharvest_grocery/screens/cart/cart_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppConstants.setDarkTheme(true);
  });

  test('theme selection updates the active palette and persists', () async {
    final provider = ThemeProvider();
    await provider.setDarkMode(false);

    expect(provider.isDarkMode, isFalse);
    expect(AppConstants.isDarkTheme, isFalse);
    expect(
      (await SharedPreferences.getInstance()).getString('app_theme_mode'),
      'light',
    );

    provider.dispose();
  });

  test('saved theme is restored when the provider is recreated', () async {
    SharedPreferences.setMockInitialValues({'app_theme_mode': 'light'});
    final provider = ThemeProvider();

    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(provider.isDarkMode, isFalse);
    expect(AppConstants.isDarkTheme, isFalse);
    provider.dispose();
  });

  test('system theme mode is persisted and restored', () async {
    final provider = ThemeProvider();
    await provider.setThemeMode(ThemeMode.system);

    expect(provider.themeMode, ThemeMode.system);
    expect(
      (await SharedPreferences.getInstance()).getString('app_theme_mode'),
      'system',
    );
    provider.dispose();

    final restoredProvider = ThemeProvider();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(restoredProvider.themeMode, ThemeMode.system);
    restoredProvider.dispose();
  });

  test('light and dark palettes use distinct readable surfaces', () {
    expect(
      AppConstants.backgroundFor(false),
      isNot(AppConstants.backgroundFor(true)),
    );
    expect(
      AppConstants.textFor(false),
      isNot(AppConstants.textFor(true)),
    );
  });

  test('home uses a soft light canvas while preserving its dark palette', () {
    expect(AppConstants.homeBackgroundFor(false), const Color(0xFFF6FAF7));
    expect(AppConstants.homeGlowFor(false), const Color(0xFFD3F2DE));
    expect(AppConstants.homeBackgroundFor(true), const Color(0xFF07100D));
    expect(AppConstants.homeGlowFor(true), const Color(0xFF0F3D2A));
  });

  test('staff appearance can stay light without changing saved user choice',
      () {
    AppConstants.setDarkTheme(true);
    AppConstants.setThemeOverride(false);

    expect(AppConstants.isDarkTheme, isFalse);
    expect(
      AppConstants.backgroundLight,
      AppConstants.backgroundFor(false),
    );

    AppConstants.setThemeOverride(null);
    expect(AppConstants.isDarkTheme, isTrue);
    expect(
      AppConstants.backgroundLight,
      AppConstants.backgroundFor(true),
    );
  });

  testWidgets('cart refreshes its palette when the theme changes',
      (tester) async {
    final themeProvider = ThemeProvider();
    final cartProvider = CartProvider();
    addTearDown(themeProvider.dispose);
    addTearDown(cartProvider.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ChangeNotifierProvider<CartProvider>.value(value: cartProvider),
        ],
        child: const MaterialApp(home: CartScreen()),
      ),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, const Color(0xFF07100D));
    DecoratedBox cartBackdrop() => tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(Scaffold),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
    expect(
      ((cartBackdrop().decoration as BoxDecoration).gradient! as LinearGradient)
          .colors
          .first,
      const Color(0xFF101812),
    );

    await themeProvider.setDarkMode(false);
    await tester.pumpAndSettle();

    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      const Color(0xFFF6FAF7),
    );
    expect(
      ((cartBackdrop().decoration as BoxDecoration).gradient! as LinearGradient)
          .colors
          .first,
      const Color(0xFFE2F4E7),
    );
  });
}
