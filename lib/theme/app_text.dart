import 'package:flutter/material.dart';

abstract final class AppText {
  static TextTheme get theme => const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.33,
          height: 1.12,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.84,
        ),
        titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w500),
        bodyMedium: TextStyle(fontSize: 21, fontWeight: FontWeight.w500),
        bodySmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        labelLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        labelMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        labelSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      );
}
