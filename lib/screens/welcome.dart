import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Image.asset('assets/images/PaPaWelcomeBackground.png', fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.35)),

          // Foreground content
          SafeArea(
            child: Stack(
              children: [
                // ===== Content box (centered) =====
                Positioned.fill(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Welcome to',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 48,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'PáPá',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 48,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 28),
                            const _PrimaryButton(label: 'Login', routeName: '/login', fontSize: 18),
                            const SizedBox(height: 14),
                            const _PrimaryButton(label: 'Sign up', routeName: '/signup', fontSize: 18),
                            const SizedBox(height: 28),
                            Text(
                              'Test Your IQ',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 25,
                                fontWeight: FontWeight.w300,
                                color: Colors.white.withOpacity(0.95),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ===== Logo box (independent, doesn’t push content) =====
                Positioned(
                  top: 85,           // <- adjust this without moving the centered box
                  left: 24,
                  right: 24,
                  child: SizedBox(
                    height: 100,
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const FlutterLogo(size: 100),
                    ),
                  ),
                ),
              ],
            ),
          )

        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final String routeName;
  final double fontSize;                 // ← add
  const _PrimaryButton({
    required this.label,
    required this.routeName,
    this.fontSize = 18,                  // ← default bigger
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 48,
      child: ElevatedButton(
        onPressed: () => Navigator.of(context).pushNamed(routeName),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E88E5),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 3,
          textStyle: GoogleFonts.poppins(        // ← set size here
            fontWeight: FontWeight.w700,
            fontSize: fontSize,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

