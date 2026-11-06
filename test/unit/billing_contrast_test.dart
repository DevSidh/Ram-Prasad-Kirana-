import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshharvest_grocery/theme/app_colors.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  test(
      'billing button and text colors have strong contrast in light and dark modes',
      () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      for (final dark in [false, true]) {
        AppColors.windowsAdminDarkTheme = dark;
        expect(contrast(AppColors.action, AppColors.onAction),
            greaterThanOrEqualTo(4.5));
        expect(contrast(AppColors.surface, AppColors.primary),
            greaterThanOrEqualTo(7));
        expect(contrast(AppColors.surface, AppColors.muted),
            greaterThanOrEqualTo(4.5));
        expect(contrast(AppColors.navigationSelected, AppColors.actionText),
            greaterThanOrEqualTo(4.5));
      }
    } finally {
      AppColors.clearWindowsAdminTheme();
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
