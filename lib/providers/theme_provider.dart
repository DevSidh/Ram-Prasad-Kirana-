import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';

class ThemeProvider extends ChangeNotifier {
  static const _preferenceKey = 'app_theme_mode';

  ThemeMode _themeMode = ThemeMode.dark;
  int _changeRevision = 0;

  ThemeProvider() {
    unawaited(_loadSavedTheme());
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> setDarkMode(bool isDark) async {
    final mode = isDark ? ThemeMode.dark : ThemeMode.light;
    if (_themeMode == mode) return;

    final revision = ++_changeRevision;
    _themeMode = mode;
    AppConstants.setDarkTheme(isDark);
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    if (revision == _changeRevision) {
      await preferences.setString(_preferenceKey, mode.name);
    }
  }

  Future<void> _loadSavedTheme() async {
    try {
      final revision = _changeRevision;
      final preferences = await SharedPreferences.getInstance();
      if (revision != _changeRevision) return;

      final savedMode = preferences.getString(_preferenceKey);
      if (savedMode != ThemeMode.light.name &&
          savedMode != ThemeMode.dark.name) {
        return;
      }

      _themeMode = savedMode == ThemeMode.dark.name
          ? ThemeMode.dark
          : ThemeMode.light;
      AppConstants.setDarkTheme(_themeMode == ThemeMode.dark);
      notifyListeners();
    } catch (error, stackTrace) {
      debugPrint('Could not load saved theme preference: $error\n$stackTrace');
    }
  }
}
