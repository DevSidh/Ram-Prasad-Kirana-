import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text.dart';

abstract final class AppTheme {
  static ThemeData get data {
    final isDark = AppColors.isWindowsAdminDarkTheme;
    final scheme = isDark
        ? ColorScheme.dark(
            primary: AppColors.action,
            onPrimary: AppColors.onAction,
            secondary: AppColors.action,
            onSecondary: AppColors.onAction,
            surface: AppColors.surface,
            onSurface: AppColors.primary,
            onSurfaceVariant: AppColors.muted,
            outline: AppColors.outline,
            outlineVariant: AppColors.outline,
            error: AppColors.error,
            onError: AppColors.surface,
          )
        : ColorScheme.light(
            primary: AppColors.action,
            onPrimary: AppColors.onAction,
            secondary: AppColors.action,
            onSecondary: AppColors.onAction,
            surface: AppColors.surface,
            onSurface: AppColors.primary,
            onSurfaceVariant: AppColors.muted,
            outline: AppColors.outline,
            outlineVariant: AppColors.outline,
            error: AppColors.error,
            onError: AppColors.surface,
          );
    final textTheme = AppText.theme.apply(
      bodyColor: AppColors.primary,
      displayColor: AppColors.primary,
    );
    final pillShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.pill),
    );
    final inputRadius = BorderRadius.circular(AppRadii.input);

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: AppColors.surface,
      textTheme: textTheme.copyWith(
        bodyMedium: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        bodySmall: textTheme.bodySmall?.copyWith(color: AppColors.muted),
        labelSmall: textTheme.labelSmall?.copyWith(
          color: AppColors.muted,
          letterSpacing: 0.72,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.primary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 1,
        margin: EdgeInsets.zero,
        shadowColor: AppColors.cardShadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide.none,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.dialog),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.outline,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          backgroundColor: AppColors.action,
          foregroundColor: AppColors.onAction,
          disabledBackgroundColor: AppColors.action.withValues(alpha: 0.35),
          disabledForegroundColor: isDark ? AppColors.muted : AppColors.surface,
          elevation: 0,
          shape: pillShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.outlinedButton),
          shape: pillShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: textTheme.labelLarge,
          shape: pillShape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: AppColors.surface,
          minimumSize: const Size(40, 40),
          shape: pillShape,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        border: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: AppColors.success, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: AppColors.error),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.accent
                : AppColors.surface),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.success
                : AppColors.outline),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        trackOutlineWidth: WidgetStateProperty.all(0),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.accent,
        disabledColor: AppColors.pageEnd,
        side: BorderSide(color: AppColors.outline),
        shape: pillShape,
        labelStyle: textTheme.labelMedium,
        secondaryLabelStyle:
            textTheme.labelMedium?.copyWith(color: AppColors.primary),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.outline : AppColors.primary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: isDark ? AppColors.primary : Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: AppColors.pageEnd,
      ),
    );
  }
}
