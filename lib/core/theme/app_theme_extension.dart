import 'package:flutter/material.dart';

import 'app_colors.dart';

@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const AppThemeExtension({
    required this.backgroundGlow,
    required this.surfaceGlass,
    required this.surfaceBorder,
    required this.glassBorder,
    required this.success,
    required this.errorBanner,
    required this.accentAmber,
    required this.featuredStart,
    required this.featuredEnd,
    required this.textSecondary,
    required this.navBarFill,
    required this.navBarBorder,
    required this.navBarInactiveIcon,
    required this.navBarActiveBackground,
    required this.navBarActiveIcon,
    required this.navBarShadow,
  });

  factory AppThemeExtension.fromColors(AppColors colors) => AppThemeExtension(
        backgroundGlow: colors.backgroundGlow,
        surfaceGlass: colors.surfaceGlass,
        surfaceBorder: colors.surfaceBorder,
        glassBorder: colors.glassBorder,
        success: colors.success,
        errorBanner: colors.errorBanner,
        accentAmber: colors.accentAmber,
        featuredStart: colors.featuredStart,
        featuredEnd: colors.featuredEnd,
        textSecondary: colors.textSecondary,
        navBarFill: colors.navBarFill,
        navBarBorder: colors.navBarBorder,
        navBarInactiveIcon: colors.navBarInactiveIcon,
        navBarActiveBackground: colors.navBarActiveBackground,
        navBarActiveIcon: colors.navBarActiveIcon,
        navBarShadow: colors.navBarShadow,
      );

  final Color backgroundGlow;
  final Color surfaceGlass;
  final Color surfaceBorder;
  final Color glassBorder;
  final Color success;
  final Color errorBanner;
  final Color accentAmber;
  final Color featuredStart;
  final Color featuredEnd;
  final Color textSecondary;
  final Color navBarFill;
  final Color navBarBorder;
  final Color navBarInactiveIcon;
  final Color navBarActiveBackground;
  final Color navBarActiveIcon;
  final Color navBarShadow;

  static AppThemeExtension of(BuildContext context) {
    final extension = Theme.of(context).extension<AppThemeExtension>();
    if (extension != null) return extension;
    return AppThemeExtension.fromColors(
      AppColors.forBrightness(Theme.of(context).brightness),
    );
  }

  @override
  AppThemeExtension copyWith({
    Color? backgroundGlow,
    Color? surfaceGlass,
    Color? surfaceBorder,
    Color? glassBorder,
    Color? success,
    Color? errorBanner,
    Color? accentAmber,
    Color? featuredStart,
    Color? featuredEnd,
    Color? textSecondary,
    Color? navBarFill,
    Color? navBarBorder,
    Color? navBarInactiveIcon,
    Color? navBarActiveBackground,
    Color? navBarActiveIcon,
    Color? navBarShadow,
  }) =>
      AppThemeExtension(
        backgroundGlow: backgroundGlow ?? this.backgroundGlow,
        surfaceGlass: surfaceGlass ?? this.surfaceGlass,
        surfaceBorder: surfaceBorder ?? this.surfaceBorder,
        glassBorder: glassBorder ?? this.glassBorder,
        success: success ?? this.success,
        errorBanner: errorBanner ?? this.errorBanner,
        accentAmber: accentAmber ?? this.accentAmber,
        featuredStart: featuredStart ?? this.featuredStart,
        featuredEnd: featuredEnd ?? this.featuredEnd,
        textSecondary: textSecondary ?? this.textSecondary,
        navBarFill: navBarFill ?? this.navBarFill,
        navBarBorder: navBarBorder ?? this.navBarBorder,
        navBarInactiveIcon: navBarInactiveIcon ?? this.navBarInactiveIcon,
        navBarActiveBackground:
            navBarActiveBackground ?? this.navBarActiveBackground,
        navBarActiveIcon: navBarActiveIcon ?? this.navBarActiveIcon,
        navBarShadow: navBarShadow ?? this.navBarShadow,
      );

  @override
  AppThemeExtension lerp(
    covariant ThemeExtension<AppThemeExtension>? other,
    double t,
  ) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      backgroundGlow: Color.lerp(backgroundGlow, other.backgroundGlow, t)!,
      surfaceGlass: Color.lerp(surfaceGlass, other.surfaceGlass, t)!,
      surfaceBorder: Color.lerp(surfaceBorder, other.surfaceBorder, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      success: Color.lerp(success, other.success, t)!,
      errorBanner: Color.lerp(errorBanner, other.errorBanner, t)!,
      accentAmber: Color.lerp(accentAmber, other.accentAmber, t)!,
      featuredStart: Color.lerp(featuredStart, other.featuredStart, t)!,
      featuredEnd: Color.lerp(featuredEnd, other.featuredEnd, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      navBarFill: Color.lerp(navBarFill, other.navBarFill, t)!,
      navBarBorder: Color.lerp(navBarBorder, other.navBarBorder, t)!,
      navBarInactiveIcon:
          Color.lerp(navBarInactiveIcon, other.navBarInactiveIcon, t)!,
      navBarActiveBackground:
          Color.lerp(navBarActiveBackground, other.navBarActiveBackground, t)!,
      navBarActiveIcon:
          Color.lerp(navBarActiveIcon, other.navBarActiveIcon, t)!,
      navBarShadow: Color.lerp(navBarShadow, other.navBarShadow, t)!,
    );
  }
}
