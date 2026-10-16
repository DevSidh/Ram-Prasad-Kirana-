import 'package:flutter/material.dart';

@immutable
class AppColors {
  const AppColors({
    required this.background,
    required this.backgroundGlow,
    required this.surface,
    required this.surfaceGlass,
    required this.surfaceBorder,
    required this.glassBorder,
    required this.primary,
    required this.accentAmber,
    required this.textPrimary,
    required this.textSecondary,
    required this.success,
    required this.error,
    required this.errorBanner,
    required this.featuredStart,
    required this.featuredEnd,
    required this.navBarFill,
    required this.navBarBorder,
    required this.navBarInactiveIcon,
    required this.navBarActiveBackground,
    required this.navBarActiveIcon,
    required this.navBarShadow,
  });

  static const dark = AppColors(
    background: Color(0xFF07100D),
    backgroundGlow: Color(0xFF0F3D2A),
    surface: Color(0xFF101B15),
    surfaceGlass: Color(0x14FFFFFF),
    surfaceBorder: Color(0x1AFFFFFF),
    glassBorder: Color(0x24FFFFFF),
    primary: Color(0xFF22C55E),
    accentAmber: Color(0xFFFBBF24),
    textPrimary: Color(0xFFF1F5F2),
    textSecondary: Color(0xFF9FB3A7),
    success: Color(0xFF22C55E),
    error: Color(0xFFEF4444),
    errorBanner: Color(0x33EF4444),
    featuredStart: Color(0xFF14532D),
    featuredEnd: Color(0xFF1F7A46),
    navBarFill: Color(0x73141414),
    navBarBorder: Color(0x20FFFFFF),
    navBarInactiveIcon: Color(0xFFE5E5E5),
    navBarActiveBackground: Color(0xFFFFFFFF),
    navBarActiveIcon: Color(0xFF111111),
    navBarShadow: Color(0x44000000),
  );

  static const light = AppColors(
    background: Color(0xFFF6FAF7),
    backgroundGlow: Color(0xFFD3F2DE),
    surface: Color(0xFFFFFFFF),
    surfaceGlass: Color(0x99FFFFFF),
    surfaceBorder: Color(0x14000000),
    glassBorder: Color(0x14000000),
    primary: Color(0xFF16A34A),
    accentAmber: Color(0xFFFBBF24),
    textPrimary: Color(0xFF14201A),
    textSecondary: Color(0xFF5D6B63),
    success: Color(0xFF16A34A),
    error: Color(0xFFEF4444),
    errorBanner: Color(0x26EF4444),
    featuredStart: Color(0xFF14532D),
    featuredEnd: Color(0xFF1F7A46),
    navBarFill: Color(0x99FFFFFF),
    navBarBorder: Color(0x14000000),
    navBarInactiveIcon: Color(0xFF3A4A41),
    navBarActiveBackground: Color(0xFF16A34A),
    navBarActiveIcon: Color(0xFFFFFFFF),
    navBarShadow: Color(0x2414201A),
  );

  final Color background;
  final Color backgroundGlow;
  final Color surface;
  final Color surfaceGlass;
  final Color surfaceBorder;
  final Color glassBorder;
  final Color primary;
  final Color accentAmber;
  final Color textPrimary;
  final Color textSecondary;
  final Color success;
  final Color error;
  final Color errorBanner;
  final Color featuredStart;
  final Color featuredEnd;
  final Color navBarFill;
  final Color navBarBorder;
  final Color navBarInactiveIcon;
  final Color navBarActiveBackground;
  final Color navBarActiveIcon;
  final Color navBarShadow;

  static AppColors forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}
