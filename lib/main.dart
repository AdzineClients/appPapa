import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';

import 'screens/login.dart';
import 'screens/signup.dart';
import 'screens/welcome.dart';


// ---- Toggle if you want to use local emulators during dev ----
const bool _useEmulators = false; // set true only if you run emulators
const String _functionsRegion = 'us-central1';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initFirebase();
  runApp(const AppPapa());
}

Future<void> _initFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Firestore defaults
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);

  if (_useEmulators) {
    // On Android emulator, "localhost" is 10.0.2.2
    final host = defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : 'localhost';

    // These calls throw if already set; wrap to be safe.
    try {
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    } catch (_) {}
    try {
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    } catch (_) {}
    try {
      FirebaseFunctions.instanceFor(region: _functionsRegion)
          .useFunctionsEmulator(host, 5001);
    } catch (_) {}
  }
}

class AppPapa extends StatelessWidget {
  const AppPapa({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AppPapa',
      debugShowCheckedModeBanner: false,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: ThemeMode.system,
      home: const _AuthGate(),
      routes: {
        '/welcome': (_) => const WelcomeScreen(),
        '/home': (_) => const WelcomeScreen(),
        '/login':  (_) => const LoginScreen(),
        '/signup': (_) => const SignupScreen(),
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
        if (snap.data == null) return const WelcomeScreen();
        return const WelcomeScreen();
      },
    );
    // Tip: swap to a Splash screen if you prefer.
  }
}

// -------------------- THEMES --------------------

// Base seed color (your brand blue)
const _seed = Color(0xFF1E88E5);

final ThemeData _lightTheme = (() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.light),
  );
  return base.copyWith(
    textTheme: GoogleFonts.poppinsTextTheme(base.textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: base.colorScheme.surface,
      foregroundColor: base.colorScheme.onSurface,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
  );
})();

final ThemeData _darkTheme = (() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark),
  );
  return base.copyWith(
    textTheme: GoogleFonts.poppinsTextTheme(base.textTheme.apply(bodyColor: Colors.white)),
    appBarTheme: AppBarTheme(
      backgroundColor: base.colorScheme.surface,
      foregroundColor: base.colorScheme.onSurface,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
  );
})();
