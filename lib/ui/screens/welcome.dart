import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const double _horizontalPadding = 24;

  // Backgrounds for light / dark
  static const String _darkBgAsset = 'assets/images/BackgroundDarkTheme.png';
  static const String _lightBgAsset = 'assets/images/BackgroundLightTheme.png';

  // Feature cards content
  static const List<Map<String, String>> _featureCards = [
    {
      'title': 'Quick IQ Mini-Games',
      'subtitle': 'Play short challenges designed to test logic and memory.',
      'asset': 'assets/images/miniGames.png',
    },
    {
      'title': 'Track Your Progress',
      'subtitle': 'See how your IQ score evolves as you complete levels.',
      'asset': 'assets/images/trackProgress.png',
    },
    {
      'title': 'Compete With Friends',
      'subtitle': 'Climb the leaderboard and show off your best runs.',
      'asset': 'assets/images/competeWithFriends.png',
    },
  ];
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final bgImage = isDark ? _darkBgAsset : _lightBgAsset;
    final accent = colorScheme.primary;
    final onBackground = colorScheme.onBackground;
    final cardColor = theme.cardColor.withOpacity(isDark ? 0.9 : 1.0);
    final subtleBorderColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.06);

    return Scaffold(
      body: Stack(
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
          SafeArea(
            child: Center(
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: _horizontalPadding),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 48),

                      // Brain image
                      SizedBox(
                        height: 240,
                        width: 240,
                        child: OverflowBox(
                          minHeight: 160,
                          maxHeight: 240,
                          minWidth: 160,
                          maxWidth: 240,
                          child: Image.asset(
                            'assets/images/welcomeBrain.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      // "Developed by"
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Developed by',
                            style: GoogleFonts.poppins(
                              textStyle: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: onBackground.withOpacity(0.7),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            height: 24,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.04)
                                  : Colors.black.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withOpacity(0.2)
                                    : Colors.black.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/images/adzineLogo.png',
                                  height: 16,
                                  fit: BoxFit.contain,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Title
                      Text(
                        'Test Your IQ',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          textStyle: theme.textTheme.headlineSmall?.copyWith(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: onBackground,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Play Tutorial
                      SizedBox(
                        width: 250,
                        height: 50,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withOpacity(0.6),
                                blurRadius: 22,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              // TODO: navigate to tutorial flow
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: colorScheme.onPrimary,
                              shape: const StadiumBorder(),
                              elevation: 0,
                              textStyle: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: const Text('Play Tutorial'),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Everything from here down shares the remaining height:
                      // cards centered, buttons at bottom.
                      Expanded(
                        child: Column(
                          children: [
                            const Spacer(), // space from Play Tutorial down to cards

                            // --- Feature cards ---
                            SizedBox(
                              height: 140,
                              child: PageView.builder(
                                controller: PageController(
                                  viewportFraction: 0.86,
                                  initialPage: 1000,
                                ),
                                itemBuilder: (context, index) {
                                  final item =
                                  _featureCards[index % _featureCards.length];

                                  // ✅ padding on BOTH sides so there's always
                                  // space between cards (fix for point 1)
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: cardColor,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: subtleBorderColor,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          // text
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                              MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  item['title'] ?? '',
                                                  style: GoogleFonts.poppins(
                                                    textStyle: theme
                                                        .textTheme.bodyLarge
                                                        ?.copyWith(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w600,
                                                      color: onBackground
                                                          .withOpacity(0.9),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  item['subtitle'] ?? '',
                                                  style: GoogleFonts.poppins(
                                                    textStyle: theme
                                                        .textTheme.bodySmall
                                                        ?.copyWith(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w400,
                                                      color: onBackground
                                                          .withOpacity(0.75),
                                                      height: 1.3,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // feature image
                                          Container(
                                            width: 70,
                                            height: 70,
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? Colors.white.withOpacity(0.04)
                                                  : Colors.black
                                                  .withOpacity(0.03),
                                              borderRadius:
                                              BorderRadius.circular(16),
                                              border: Border.all(
                                                color: isDark
                                                    ? Colors.white
                                                    .withOpacity(0.18)
                                                    : Colors.black
                                                    .withOpacity(0.08),
                                                width: 1,
                                              ),
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                              BorderRadius.circular(14),
                                              child: Image.asset(
                                                item['asset']!,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                            const Spacer(), // ✅ centers cards between Play and buttons

                            // Bottom buttons, slightly lifted from the very bottom
                            Padding(
                              padding:
                              const EdgeInsets.only(bottom: 60), // (point 2)
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Login
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed: () => Navigator.of(context)
                                          .pushNamed('/login'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: accent,
                                        foregroundColor: colorScheme.onPrimary,
                                        shape: const StadiumBorder(),
                                        elevation: 0,
                                        textStyle: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      child: const Text('Login'),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Create Account
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.of(context)
                                          .pushNamed('/signup'),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          color: accent,
                                          width: 1.6,
                                        ),
                                        shape: const StadiumBorder(),
                                        foregroundColor: accent,
                                        backgroundColor: Colors.transparent,
                                        textStyle: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      child: const Text('Create Account'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
