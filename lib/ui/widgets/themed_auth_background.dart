import 'package:flutter/material.dart';

class ThemedAuthBackground extends StatelessWidget {
  final Widget child;
  final String? darkAsset;
  final String? lightAsset;

  const ThemedAuthBackground({
    super.key,
    required this.child,
    this.darkAsset,
    this.lightAsset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Fallback to same assets used on WelcomeScreen
    final darkBg = darkAsset ?? 'assets/images/BackgroundDarkTheme.png';
    final lightBg = lightAsset ?? 'assets/images/BackgroundLightTheme.png';

    final bgImage = isDark ? darkBg : lightBg;

    return Stack(
      children: [
        // Background image
        Positioned.fill(
          child: Image.asset(
            bgImage,
            fit: BoxFit.cover,
          ),
        ),
        // Overlay for readability
        Positioned.fill(
          child: Container(
            color: isDark
                ? Colors.black.withOpacity(0.45)
                : Colors.white.withOpacity(0.18),
          ),
        ),
        // Your actual screen content
        child,
      ],
    );
  }
}
