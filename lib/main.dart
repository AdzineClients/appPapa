import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app_papa/ui/widgets/audio_controller.dart';
import 'dart:math' as math; // if not already imported
import 'package:app_papa/ui/screens/gameScreen.dart';

import 'firebase_options.dart';

import 'ui/screens/login.dart';
import 'ui/screens/signup.dart';
import 'ui/screens/welcome.dart';
import 'ui/screens/home_tabs.dart';

import 'ui/screens/app_theme.dart';
import 'ui/screens/theme_controller.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Make SFX audible even on iOS Silent switch and use sane Android focus
  AudioPlayer.global.setAudioContext(const AudioContext(
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: [AVAudioSessionOptions.duckOthers],
    ),
    android: AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.assistanceSonification,
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
      isSpeakerphoneOn: true,
    ),
  ));

  await AudioController.init();

  await _initFirebase();
  runApp(
    const AppPapa(), // your root widget
  );
}

Future<void> _initFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Firestore defaults
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
}

class AppPapa extends StatelessWidget {
  const AppPapa({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (_, mode, __) {
        final light = AppTheme.light;
        final dark  = AppTheme.dark;

        return MaterialApp(
          title: 'AppPapa',
          debugShowCheckedModeBanner: false,
          theme: light.copyWith(textTheme: GoogleFonts.poppinsTextTheme(light.textTheme)),
          darkTheme: dark.copyWith(textTheme: GoogleFonts.poppinsTextTheme(dark.textTheme)),
          themeMode: ThemeMode.light,
          // Quick switch: harness vs normal app flow
            home: const _AuthGate(),
            routes: {
              '/welcome': (_) => const WelcomeScreen(),
              '/home':    (_) => const HomeScreen(),
              '/login':   (_) => const LoginScreen(),
              '/signup':  (_) => const SignupScreen(),
              // '/engine-test': (_) => const EngineHarnessScreen(), // optional: remove
            }
        );
      },
    );
  }
}

/// Listens to auth state and shows the right screen.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snap.data;

        // If no user OR anonymous user → show Welcome
        if (user == null || user.isAnonymous) {
          return const WelcomeScreen();
        }

        // Only real (non-anonymous) users get Home
        return const HomeScreen();
      },
    );
  }
}

