import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import 'onboarding_screen.dart';
import 'auth/login_screen.dart';
import '../navigation/app_shell_route.dart';
import '../widgets/scooter_loading_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _onboardingSeen = false;
  Object? _startupError;

  Future<void> _prepareStartup() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final productProvider = Provider.of<ProductProvider>(
      context,
      listen: false,
    );
    unawaited(productProvider.loadCatalog());
    final results = await Future.wait<dynamic>([
      authProvider.sessionReady,
      SharedPreferences.getInstance(),
    ]);
    final prefs = results[1] as SharedPreferences;
    _onboardingSeen = prefs.getBool(AppConstants.keyOnboardingSeen) ?? false;
  }

  void _onLoadingFinished(Object? error) {
    if (!mounted) return;
    if (error != null) {
      setState(() => _startupError = error);
      return;
    }
    _navigateNext();
  }

  void _navigateNext() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.isAuthenticated) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => appShellForUser(authProvider.currentUser)),
      );
    } else if (!_onboardingSeen) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_startupError case final error?) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 42,
                  color: AppConstants.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Could not finish starting the app.',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                SelectableText(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ScooterLoadingScreen(
      init: _prepareStartup,
      onFinished: _onLoadingFinished,
      title: AppConstants.appName,
      subtitle: AppConstants.appTagline,
      minDuration: const Duration(milliseconds: 1500),
    );
  }
}
