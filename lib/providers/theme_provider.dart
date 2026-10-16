import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';

class ThemeProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const _preferenceKey = 'app_theme_mode';

  ThemeMode _themeMode = ThemeMode.dark;
  int _changeRevision = 0;

  ThemeProvider() {
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadSavedTheme());
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  Future<void> setDarkMode(bool isDark) =>
      setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    final revision = ++_changeRevision;
    _themeMode = mode;
    AppConstants.setDarkTheme(isDarkMode);
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    if (revision == _changeRevision) {
      await preferences.setString(_preferenceKey, mode.name);
    }
  }

  @override
  void didChangePlatformBrightness() {
    if (_themeMode != ThemeMode.system) return;
    AppConstants.setDarkTheme(isDarkMode);
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadSavedTheme() async {
    try {
      final revision = _changeRevision;
      final preferences = await SharedPreferences.getInstance();
      if (revision != _changeRevision) return;

      final savedMode = preferences.getString(_preferenceKey);
      final restoredMode = ThemeMode.values.where(
        (mode) => mode.name == savedMode,
      );
      if (restoredMode.isEmpty) {
        return;
      }

      _themeMode = restoredMode.first;
      AppConstants.setDarkTheme(isDarkMode);
      notifyListeners();
    } catch (error, stackTrace) {
      debugPrint('Could not load saved theme preference: $error\n$stackTrace');
    }
  }
}
