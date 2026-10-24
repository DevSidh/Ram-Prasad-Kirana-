import 'package:flutter/material.dart';

abstract final class AppColors {
  static const pageStart = Color(0xFFF1F6F4);
  static const pageEnd = Color(0xFFDCE7E4);
  static const surface = Color(0xFFFFFFFF);
  static const primary = Color(0xFF0B0B0B);
  static const accent = Color(0xFFC6F24A);
  static const success = Color(0xFF22C55E);
  static const successBanner = Color(0xFFDDF3E4);
  static const successBannerText = Color(0xFF14633A);
  static const successText = Color(0xFF16874A);
  static const warning = Color(0xFFF5A02B);
  static const warningPill = Color(0xFFFDEBD0);
  static const warningText = Color(0xFF9A5B00);
  static const error = Color(0xFFEF4444);
  static const errorText = Color(0xFFC23B3B);
  static const errorPill = Color(0xFFFDE2E2);
  static const muted = Color(0xFF55645F);
  static const outline = Color(0xFFC9D6D2);
  static const outlinedButton = Color(0xFFAFC0BB);
  static const thumbnailAmber = Color(0xFFF8D88A);
  static const thumbnailGreen = Color(0xFFBFE8C9);
  static const thumbnailBlue = Color(0xFFC9D6F2);
  static const thumbnailLavender = Color(0xFFE4E3FB);
  static const thumbnailRed = Color(0xFFFDE2E2);
  static const darkGreen = Color(0xFF0B2A1F);
  static const cardShadow = Color(0x1228463C);

  static const thumbnailTints = [
    thumbnailAmber,
    thumbnailGreen,
    thumbnailBlue,
    thumbnailLavender,
    thumbnailRed,
  ];
}

abstract final class AppRadii {
  static const card = 22.0;
  static const row = 20.0;
  static const banner = 20.0;
  static const input = 16.0;
  static const thumbnail = 13.0;
  static const brand = 12.0;
  static const navigation = 13.0;
  static const pill = 99.0;
  static const dialog = 28.0;
}
