import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import 'auth/login_screen.dart';

const _onboardingBackground = Color(0xFF07100D);
const _onboardingGreen = Color(0xFF16A34A);
const _onboardingBody = Color(0xFFA7B3AD);
const _onboardingDotOff = Color(0xFF1F2B26);

class _OnboardingPageData {
  final String imageAsset;
  final String title;
  final String body;

  const _OnboardingPageData({
    required this.imageAsset,
    required this.title,
    required this.body,
  });
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  static const _pages = [
    _OnboardingPageData(
      imageAsset: 'assets/onboarding/onboarding_verify_scan.png',
      title: 'Checked Before It Leaves',
      body: 'Every order is scanned and verified at the store, so what you '
          'ordered is exactly what you get.',
    ),
    _OnboardingPageData(
      imageAsset: 'assets/onboarding/onboarding_pack_dispatch.png',
      title: 'Packed Fresh, Dispatched Fast',
      body: 'Your items are packed with care and loaded onto our delivery '
          'vehicle within minutes of your order.',
    ),
    _OnboardingPageData(
      imageAsset: 'assets/onboarding/onboarding_doorstep_handover.png',
      title: 'Handed to You, Right at the Door',
      body: 'Our courier hands your parcel over in person, with live status '
          'tracking until it reaches you.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyOnboardingSeen, true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _onboardingBackground,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Align(
                alignment: Alignment.centerRight,
                child: AnimatedOpacity(
                  opacity: _currentIndex == _pages.length - 1 ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: TextButton(
                    onPressed: _currentIndex == _pages.length - 1
                        ? null
                        : _completeOnboarding,
                    child: const Text(
                      'Skip',
                      style: TextStyle(color: _onboardingBody, fontSize: 15),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _OnboardingPage(data: _pages[index]);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var index = 0; index < _pages.length; index++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: index == _currentIndex ? 28 : 8,
                          decoration: BoxDecoration(
                            color: index == _currentIndex
                                ? _onboardingGreen
                                : _onboardingDotOff,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _onboardingGreen,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        if (_currentIndex == _pages.length - 1) {
                          _completeOnboarding();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic,
                          );
                        }
                      },
                      child: Text(
                        _currentIndex == _pages.length - 1
                            ? 'Get Started'
                            : 'Next',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingPageData data;

  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageWidth =
            (MediaQuery.sizeOf(context).width * .82).clamp(240.0, 380.0);
        final imageHeight = (constraints.maxHeight * .44).clamp(150.0, 300.0);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(
                image: true,
                label: data.title,
                child: Image.asset(
                  data.imageAsset,
                  width: imageWidth.toDouble(),
                  height: imageHeight.toDouble(),
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                data.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                data.body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _onboardingBody,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
