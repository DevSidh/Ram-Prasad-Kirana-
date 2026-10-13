import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppConstants {
  static bool _isDarkTheme = true;
  static bool? _themeOverride;

  static bool get isDarkTheme => _themeOverride ?? _isDarkTheme;

  static void setDarkTheme(bool isDark) => _isDarkTheme = isDark;
  static void setThemeOverride(bool? isDark) => _themeOverride = isDark;

  static const String appName = 'Ram Prasad General Store';
  static const String appTagline = 'Your Trusted Neighborhood General Store';

  // Base API URL (can be customized via build-time environment variables)
  static String get apiBaseUrl {
    const configuredUrl = String.fromEnvironment('API_BASE_URL');
    if (configuredUrl.isNotEmpty) return configuredUrl;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:4000/api/v1';
    }
    return 'http://localhost:4000/api/v1';
  }

  static void validateApiConfiguration() {
    const isReleaseBuild = bool.fromEnvironment('dart.vm.product');
    if (!isReleaseBuild) return;

    if (!isProductionApiUrl(apiBaseUrl)) {
      throw StateError(
        'Release builds require the deployed HTTPS API_BASE_URL, not a local or placeholder URL.',
      );
    }
  }

  static bool isProductionApiUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return false;

    final host = uri.host.toLowerCase();
    return host != 'localhost' &&
        host != '127.0.0.1' &&
        host != '::1' &&
        host != '0.0.0.0' &&
        host != 'example.com' &&
        host != 'example.net' &&
        host != 'example.org' &&
        !host.endsWith('.invalid') &&
        !host.endsWith('.test') &&
        !host.endsWith('.example') &&
        !host.endsWith('.localhost') &&
        !host.contains('your-api-host');
  }

  // Storage Keys
  static const String keyToken = 'auth_token';
  static const String keyUser = 'user_data';
  static const String keyOnboardingSeen = 'onboarding_seen';
  static const String keyCart = 'cart_cache';
  static const String keySearchHistory = 'search_history';

  // Currency
  static const String currencySymbol = 'Rs. ';

  // Spotify Glass palette.
  static const Color primary = Color(0xFF1DB954);
  static Color primaryDarkFor(bool isDark) =>
      isDark ? const Color(0xFF4FE080) : const Color(0xFF147E3D);
  static Color primaryLightFor(bool isDark) =>
      isDark ? const Color(0xFF153220) : const Color(0xFFDDF2E2);
  static Color backgroundFor(bool isDark) =>
      isDark ? const Color(0xFF080A09) : const Color(0xFFE7EFE8);
  static Color homeBackgroundFor(bool isDark) =>
      isDark ? backgroundFor(true) : const Color(0xFFF5F7F4);
  static Color homeGlowFor(bool isDark) =>
      isDark ? const Color(0xFF10251A) : const Color(0xFFEAF4EC);
  static Color surfaceFor(bool isDark) =>
      isDark ? const Color(0xFF171A18) : const Color(0xFFF9FBF9);
  static Color textFor(bool isDark) =>
      isDark ? const Color(0xFFF4F6F4) : const Color(0xFF122017);
  static Color mutedTextFor(bool isDark) =>
      isDark ? const Color(0xFFA7AEA9) : const Color(0xFF58685E);
  static Color borderFor(bool isDark) =>
      isDark ? const Color(0xFF303633) : const Color(0xFFD2DFD4);
  static Color glassSurfaceFor(bool isDark) =>
      isDark ? const Color(0xCC1B201E) : const Color(0xCCFFFFFF);
  static Color glassBorderFor(bool isDark) =>
      isDark ? const Color(0x33FFFFFF) : const Color(0x33121D16);
  static Color get primaryDark =>
      primaryDarkFor(isDarkTheme);
  static Color get primaryLight =>
      primaryLightFor(isDarkTheme);
  static const Color accent = Color(0xFF1DB954);
  static const Color primaryForeground = Color(0xFF062611);

  static Color get backgroundLight => backgroundFor(isDarkTheme);
  static Color get surfaceLight => surfaceFor(isDarkTheme);
  static Color get textDark => textFor(isDarkTheme);
  static Color get textMuted => mutedTextFor(isDarkTheme);
  static Color get borderLight => borderFor(isDarkTheme);

  static Color get backgroundDark => backgroundLight;
  static Color get surfaceDark => surfaceLight;
  static Color get textLight => textDark;
  static Color get borderDark => borderLight;

  // Brand Payment Gateways
  static const Color khaltiColor = Color(0xFF5C2D91);
  static const Color esewaColor = Color(0xFF60BB46);
}
