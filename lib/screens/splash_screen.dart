import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'onboarding_screen.dart';
import 'auth/login_screen.dart';
import '../navigation/app_shell_route.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _textRevealAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scaleAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _textRevealAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.22, 0.88, curve: Curves.easeOutCubic),
    );
    _controller.forward();

    _navigateNext();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    }
  }

  Future<void> _navigateNext() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final results = await Future.wait<dynamic>([
      authProvider.sessionReady,
      SharedPreferences.getInstance(),
    ]);
    if (!mounted) return;

    final prefs = results[1] as SharedPreferences;
    final onboardingSeen =
        prefs.getBool(AppConstants.keyOnboardingSeen) ?? false;

    if (authProvider.isAuthenticated) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => appShellForUser(authProvider.currentUser)),
      );
    } else if (!onboardingSeen) {
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider?>();
    final titleStyle = TextStyle(
      color: AppConstants.textDark,
      fontSize: 28,
      fontWeight: FontWeight.bold,
      letterSpacing: -0.5,
    );
    final taglineStyle = TextStyle(
      color: AppConstants.textMuted,
      fontSize: 13,
      letterSpacing: 0.2,
    );
    return Scaffold(
      backgroundColor: AppConstants.backgroundLight,
      body: Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppConstants.surfaceLight,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.storefront,
                    color: AppConstants.primary,
                    size: 52,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: (MediaQuery.sizeOf(context).width - 36)
                    .clamp(0.0, double.infinity),
                child: AnimatedBuilder(
                  animation: _textRevealAnimation,
                  builder: (context, child) {
                    final progress = _textRevealAnimation.value;
                    return Opacity(
                      opacity: progress,
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(
                          sigmaX: 8 * (1 - progress),
                          sigmaY: 8 * (1 - progress),
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(AppConstants.appName, style: titleStyle),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(AppConstants.appTagline, style: taglineStyle),
            ],
          ),
        ),
      ),
    );
  }
}
