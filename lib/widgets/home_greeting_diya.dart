import 'package:flutter/material.dart';

class HomeGreetingDiya extends StatelessWidget {
  const HomeGreetingDiya({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 54,
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: Image.asset(
            'assets/images/home_diya.webp',
            fit: BoxFit.contain,
            alignment: Alignment.center,
            gaplessPlayback: true,
            errorBuilder: (_, error, stackTrace) {
              debugPrint('Unable to load the home greeting diya: $error');
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}
