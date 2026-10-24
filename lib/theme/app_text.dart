import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppText {
  static TextTheme get theme => GoogleFonts.manropeTextTheme(
        const TextTheme(
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
          titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          bodyLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      );
}
