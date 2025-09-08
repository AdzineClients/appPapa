import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login.dart';
import 'welcome.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {

  Route _slideTo(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );


  bool _busy = false;

  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  static final Uri _termsUrl = Uri.parse('https://example.com/terms');
  static final Uri _privacyUrl = Uri.parse('https://example.com/privacy');

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()..onTap = () => _openUrl(_termsUrl);
    _privacyTap = TapGestureRecognizer()..onTap = () => _openUrl(_privacyUrl);
  }

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  Future<void> _openUrl(Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  }

  Future<void> _createAndFinish() async {
    if (!_formKey.currentState!.validate()) return;

    final rawUsername = _username.text.trim();
    final handle = rawUsername.toLowerCase();
    final email = _email.text.trim();
    final pass  = _password.text;

    if (rawUsername.isEmpty || rawUsername.length > 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username must be 1–15 characters.')),
      );
      return;
    }
    if (pass.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 8 characters.')),
      );
      return;
    }

    setState(() => _busy = true);
    User? newUser;
    try {
      // Check username uniqueness (top-level: username/{handle})
      final unameRef = FirebaseFirestore.instance.collection('username').doc(handle);
      if ((await unameRef.get()).exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That username is already taken.')),
        );
        return;
      }

      // Create auth user (throws if email already used)
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );
      newUser = cred.user!;
      final uid = newUser.uid;

      // Write user and reserve username
      final batch = FirebaseFirestore.instance.batch();
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      batch.set(userRef, {
        'uid': uid,
        'username': rawUsername,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(unameRef, {
        'uid': uid,
        'username': rawUsername,
        'reservedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();

      // Optional: send verification mail (we'll handle the flow later)
      try { await newUser.sendEmailVerification(); } catch (_) {}

      if (!mounted) return;

      // Return to root so your AuthGate shows the signed-in screen
      Navigator.of(context).pushAndRemoveUntil(
        _slideTo(const WelcomeScreen()),
            (r) => false,
      );
      // If you prefer explicit: Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'email-already-in-use': msg = 'That email is already in use.'; break;
        case 'invalid-email': msg = 'Invalid email address.'; break;
        case 'weak-password': msg = 'Password too weak.'; break;
        default: msg = e.message ?? e.code;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      // If Firestore fails after user creation, try to clean up the auth user
      if (newUser != null) { try { await newUser.delete(); } catch (_) {} }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create the account. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onGoogleTap() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Google sign-in coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.white,
          onPressed: () => Navigator.of(context).maybePop(),   // <- fixed extra brace
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/PaPaBackgroundLS.png', fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.35)),

          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Create your Account',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Single white card (no AnimatedSwitcher / steps)
                      _StepCard(
                        height: 400,
                        child: _buildForm(),
                      ),

                      const SizedBox(height: 12),

                      // (Optional) Google button under the card
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: _GoogleButton(onPressed: _onGoogleTap),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Legal
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Text.rich(
                  TextSpan(
                    text: 'By signing up to PaPa you are agreeing to the ',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.95),
                    ),
                    children: [
                      TextSpan(
                        text: 'Terms & Conditions',
                        style: const TextStyle(
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w600,
                        ),
                        recognizer: _termsTap,
                      ),
                      const TextSpan(text: ', and you have read the '),
                      TextSpan(
                        text: 'Privacy policy',
                        style: const TextStyle(
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w600,
                        ),
                        recognizer: _privacyTap,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Form UI ----
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Field(
            label: 'Username',
            controller: _username,
            textInputAction: TextInputAction.next,
            validator: (v) {
              final s = v?.trim() ?? '';
              if (s.isEmpty) return 'Enter a username';
              if (s.length > 15) return 'Max 15 characters';
              return null;
            },
          ),
          const SizedBox(height: 12),
          _Field(
            label: 'Email',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 12),
          _Field(
            label: 'Password',
            controller: _password,
            obscureText: true,
            textInputAction: TextInputAction.next,
            validator: (v) => (v == null || v.length < 8) ? 'Min 8 characters' : null,
          ),
          const SizedBox(height: 12),
          _Field(
            label: 'Confirm password',
            controller: _confirm,
            obscureText: true,
            textInputAction: TextInputAction.done,
            validator: (v) => (v != _password.text) ? 'Passwords don’t match' : null,
          ),
          const Spacer(),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _busy ? null : _createAndFinish,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
              child: _busy ? const CircularProgressIndicator() : const Text('Create'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- Reusable widgets ----------------

class _StepCard extends StatelessWidget {
  final Widget child;
  final double height;
  final EdgeInsetsGeometry margin;
  const _StepCard({
    super.key,
    required this.child,
    required this.height,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        margin: margin,
        width: double.infinity,
        height: height,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26, blurRadius: 24, spreadRadius: 2, offset: Offset(0, 12),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;

  const _Field({
    required this.label,
    required this.controller,
    this.textInputAction,
    this.keyboardType,
    this.validator,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: validator,
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _GoogleButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/googleIcon.png',
            width: 22,
            height: 22,
            errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 22),
          ),
          const SizedBox(width: 10),
          const Text('Sign in with Google'),
        ],
      ),
    );
  }
}
