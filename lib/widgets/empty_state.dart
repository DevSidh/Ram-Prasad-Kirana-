import 'package:flutter/material.dart';
import '../core/constants.dart';
import 'store_animation.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? buttonText;
  final VoidCallback? onButtonPressed;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.buttonText,
    this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isError =
        icon == Icons.cloud_off_outlined || icon == Icons.wifi_off_rounded;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isError)
              const StoreAnimation(
                assetPath: 'animations/error_404.lottie',
                size: 220,
                semanticLabel: 'Page error animation',
              )
            else
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppConstants.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 48, color: AppConstants.primaryDark),
              ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppConstants.textDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(fontSize: 13, color: AppConstants.textMuted),
              textAlign: TextAlign.center,
            ),
            if (buttonText != null && onButtonPressed != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onButtonPressed,
                child: Text(buttonText!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
