import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppConstants {
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

  // Primary Color Palette (Warm Neighborhood Store Amber & Brass)
  static const Color primary = Color(0xFF16825D);
  static const Color primaryDark = Color(0xFF116149);
  static const Color primaryLight = Color(0xFFE1F1E8);
  static const Color accent = Color(0xFF0D7552);

  // Neutral Canvas
  static const Color backgroundLight = Color(0xFFF5F5EF);
  static const Color surfaceLight = Color(0xFFFFFEFA);
  static const Color textDark = Color(0xFF18231E);
  static const Color textMuted = Color(0xFF69776F);
  static const Color borderLight = Color(0xFFDDE5DE);

  // Dark Canvas
  static const Color backgroundDark = Color(0xFF10231B);
  static const Color surfaceDark = Color(0xFF183126);
  static const Color textLight = Color(0xFFF1F6F1);
  static const Color borderDark = Color(0xFF335141);

  // Brand Payment Gateways
  static const Color khaltiColor = Color(0xFF5C2D91);
  static const Color esewaColor = Color(0xFF60BB46);
}
