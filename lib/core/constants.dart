import 'package:flutter/material.dart';
import 'theme/app_colors.dart';

class AppConstants {
  static bool _isDarkTheme = true;
  static bool? _themeOverride;

  static bool get isDarkTheme => _themeOverride ?? _isDarkTheme;

  static void setDarkTheme(bool isDark) => _isDarkTheme = isDark;
  static void setThemeOverride(bool? isDark) => _themeOverride = isDark;

  static const String appName = 'FastStore';
  static const String appTagline = 'Janakpur';

  // Base API URL (can be customized via build-time environment variables)
  static String get apiBaseUrl {
    const configuredUrl = String.fromEnvironment('API_BASE_URL');
    if (configuredUrl.isNotEmpty) return configuredUrl;
    return 'https://ram-prasad-kirana-backend.onrender.com/api/v1';
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
  static const double defaultDeliveryFee = 40;

  static const Color primary = Color(0xFF16A34A);
  static Color primaryFor(bool isDark) =>
      (isDark ? AppColors.dark : AppColors.light).primary;
  static Color primaryDarkFor(bool isDark) =>
      primaryFor(isDark);
  static Color primaryLightFor(bool isDark) =>
      (isDark ? AppColors.dark : AppColors.light).backgroundGlow;
  static Color backgroundFor(bool isDark) =>
      (isDark ? AppColors.dark : AppColors.light).background;
  static Color homeBackgroundFor(bool isDark) =>
      backgroundFor(isDark);
  static Color homeGlowFor(bool isDark) =>
      (isDark ? AppColors.dark : AppColors.light).backgroundGlow;
  static Color surfaceFor(bool isDark) =>
      (isDark ? AppColors.dark : AppColors.light).surface;
  static Color textFor(bool isDark) =>
      (isDark ? AppColors.dark : AppColors.light).textPrimary;
  static Color mutedTextFor(bool isDark) =>
      (isDark ? AppColors.dark : AppColors.light).textSecondary;
  static Color borderFor(bool isDark) =>
      (isDark ? AppColors.dark : AppColors.light).surfaceBorder;
  static Color glassSurfaceFor(bool isDark) =>
      (isDark ? AppColors.dark : AppColors.light).surfaceGlass;
  static Color glassBorderFor(bool isDark) =>
      (isDark ? AppColors.dark : AppColors.light).glassBorder;
  static Color get primaryDark =>
      primaryDarkFor(isDarkTheme);
  static Color get primaryLight =>
      primaryLightFor(isDarkTheme);
  static const Color accent = Color(0xFFFBBF24);
  static const Color primaryForeground = Color(0xFF07100D);

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
