import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

abstract final class AppColors {
  // Admin desktop appearance is deliberately scoped to the Windows admin
  // shell. The consumer app and mobile staff screens keep their existing colors.
  static bool _windowsAdminDarkTheme = false;
  static bool _windowsAdminThemeActive = false;

  static bool get isWindowsAdminDarkTheme =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.windows &&
      _windowsAdminDarkTheme;

  static bool get isWindowsAdminTheme =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.windows &&
      _windowsAdminThemeActive;

  static set windowsAdminDarkTheme(bool value) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      _windowsAdminDarkTheme = value;
      _windowsAdminThemeActive = true;
    }
  }

  static void clearWindowsAdminTheme() {
    _windowsAdminDarkTheme = false;
    _windowsAdminThemeActive = false;
  }

  static Color get sidebar => isWindowsAdminTheme
      ? (isWindowsAdminDarkTheme
          ? const Color(0xFF1D1D1D)
          : const Color(0xFFFFFFFF))
      : surface;
  static Color get header =>
      isWindowsAdminTheme ? const Color(0xFF203D60) : primary;
  static Color get navigationSelected => isWindowsAdminTheme
      ? (isWindowsAdminDarkTheme
          ? const Color(0xFF29323F)
          : const Color(0xFFE9EEF8))
      : successBanner;
  static Color get action =>
      isWindowsAdminTheme ? const Color(0xFF5D91F8) : success;
  static Color get onAction =>
      isWindowsAdminTheme ? const Color(0xFF071A38) : accent;
  static Color get pageStart => isWindowsAdminTheme
      ? (isWindowsAdminDarkTheme
          ? const Color(0xFF111111)
          : const Color(0xFFF4F4F4))
      : (isWindowsAdminDarkTheme
          ? const Color(0xFF000000)
          : const Color(0xFFF1F6F4));
  static Color get pageEnd => isWindowsAdminTheme
      ? (isWindowsAdminDarkTheme
          ? const Color(0xFF111111)
          : const Color(0xFFF4F4F4))
      : (isWindowsAdminDarkTheme
          ? const Color(0xFF000000)
          : const Color(0xFFDCE7E4));
  static Color get surface => isWindowsAdminTheme
      ? (isWindowsAdminDarkTheme
          ? const Color(0xFF1F1F1F)
          : const Color(0xFFFFFFFF))
      : (isWindowsAdminDarkTheme
          ? const Color(0xFF101010)
          : const Color(0xFFFFFFFF));
  static Color get primary => isWindowsAdminTheme
      ? (isWindowsAdminDarkTheme
          ? const Color(0xFFE7E7E7)
          : const Color(0xFF202124))
      : (isWindowsAdminDarkTheme
          ? const Color(0xFFF5F5F5)
          : const Color(0xFF0B0B0B));
  static Color get accent => isWindowsAdminTheme
      ? const Color(0xFF5D91F8)
      : (isWindowsAdminDarkTheme
          ? const Color(0xFF00271C)
          : const Color(0xFFC6F24A));
  static Color get success => isWindowsAdminDarkTheme
      ? const Color(0xFF10B981)
      : const Color(0xFF22C55E);
  static Color get successBanner => isWindowsAdminDarkTheme
      ? const Color(0xFF0B2A1F)
      : const Color(0xFFDDF3E4);
  static Color get successBannerText => isWindowsAdminDarkTheme
      ? const Color(0xFF10B981)
      : const Color(0xFF14633A);
  static Color get successText => isWindowsAdminDarkTheme
      ? const Color(0xFF10B981)
      : const Color(0xFF16874A);
  static Color get warning => isWindowsAdminDarkTheme
      ? const Color(0xFFFBBF24)
      : const Color(0xFFF5A02B);
  static Color get warningPill => isWindowsAdminDarkTheme
      ? const Color(0xFF33270B)
      : const Color(0xFFFDEBD0);
  static Color get warningText => isWindowsAdminDarkTheme
      ? const Color(0xFFFBBF24)
      : const Color(0xFF9A5B00);
  static Color get error => isWindowsAdminDarkTheme
      ? const Color(0xFFEF4444)
      : const Color(0xFFEF4444);
  static Color get errorText => isWindowsAdminDarkTheme
      ? const Color(0xFFF87171)
      : const Color(0xFFC23B3B);
  static Color get errorPill => isWindowsAdminDarkTheme
      ? const Color(0xFF2D1111)
      : const Color(0xFFFDE2E2);
  static Color get muted => isWindowsAdminTheme
      ? (isWindowsAdminDarkTheme
          ? const Color(0xFF9B9B9B)
          : const Color(0xFF777A80))
      : (isWindowsAdminDarkTheme
          ? const Color(0xFFA3A3A3)
          : const Color(0xFF55645F));
  static Color get outline => isWindowsAdminTheme
      ? (isWindowsAdminDarkTheme
          ? const Color(0xFF333333)
          : const Color(0xFFE1E1E1))
      : (isWindowsAdminDarkTheme
          ? const Color(0xFF282828)
          : const Color(0xFFC9D6D2));
  static Color get outlinedButton => isWindowsAdminTheme
      ? (isWindowsAdminDarkTheme
          ? const Color(0xFF454545)
          : const Color(0xFFD1D5DB))
      : (isWindowsAdminDarkTheme
          ? const Color(0xFF343434)
          : const Color(0xFFAFC0BB));
  static Color get thumbnailAmber => isWindowsAdminDarkTheme
      ? const Color(0xFF33270B)
      : const Color(0xFFF8D88A);
  static Color get thumbnailGreen => isWindowsAdminDarkTheme
      ? const Color(0xFF0B2A1F)
      : const Color(0xFFBFE8C9);
  static Color get thumbnailBlue => isWindowsAdminDarkTheme
      ? const Color(0xFF102638)
      : const Color(0xFFC9D6F2);
  static Color get thumbnailLavender => isWindowsAdminDarkTheme
      ? const Color(0xFF241D36)
      : const Color(0xFFE4E3FB);
  static Color get thumbnailRed => isWindowsAdminDarkTheme
      ? const Color(0xFF2D1111)
      : const Color(0xFFFDE2E2);
  static Color get darkGreen => isWindowsAdminDarkTheme
      ? const Color(0xFF05261D)
      : const Color(0xFF0B2A1F);
  static Color get cardShadow => isWindowsAdminTheme
      ? const Color(0x00000000)
      : (isWindowsAdminDarkTheme
          ? const Color(0x00000000)
          : const Color(0x1228463C));

  static List<Color> get thumbnailTints => [
        thumbnailAmber,
        thumbnailGreen,
        thumbnailBlue,
        thumbnailLavender,
        thumbnailRed,
      ];
}

abstract final class AppRadii {
  static double get card => AppColors.isWindowsAdminTheme ? 14.0 : 22.0;
  static double get row => AppColors.isWindowsAdminTheme ? 12.0 : 20.0;
  static double get banner => AppColors.isWindowsAdminTheme ? 14.0 : 20.0;
  static double get input => AppColors.isWindowsAdminTheme ? 12.0 : 16.0;
  static double get thumbnail => AppColors.isWindowsAdminTheme ? 10.0 : 13.0;
  static double get brand => AppColors.isWindowsAdminTheme ? 10.0 : 12.0;
  static double get navigation => AppColors.isWindowsAdminTheme ? 8.0 : 13.0;
  static const pill = 99.0;
  static double get dialog => AppColors.isWindowsAdminTheme ? 16.0 : 28.0;
}
