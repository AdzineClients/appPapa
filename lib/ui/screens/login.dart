import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_papa/ui/widgets/themed_auth_background.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController(); // username or email
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;

  @override
  void dispose() {
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<String?> _resolveEmail(String input) async {
    final text = input.trim();
    if (text.isEmpty) return null;

    // If user typed an email, use it directly
    if (text.contains('@')) return text;

    // Treat as username: look up handle in /username/{handle} -> { uid }
    final handle = text.toLowerCase();
    final nameDoc = await FirebaseFirestore.instance
        .collection('username')
        .doc(handle)
        .get();

    if (!nameDoc.exists) return null;

    final uid = nameDoc.data()?['uid'] as String?;
    if (uid == null) return null;

    // Load the user's email from /users/{uid}
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    return (userDoc.data()?['email'] as String?)?.trim();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _busy = true);
    try {
      final email = await _resolveEmail(_user.text);
      if (email == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
            Text('User not found. Use your email or a valid username.'),
          ),
        );
        return;
      }

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _password.text,
      );

      if (!mounted) return;

      // AuthGate sits at root; just go back to first route
      Navigator.of(context).popUntil((r) => r.isFirst);
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'invalid-email':
          msg = 'Invalid email.';
          break;
        case 'user-not-found':
          msg = 'No account found.';
          break;
        case 'wrong-password':
          msg = 'Incorrect password.';
          break;
        case 'user-disabled':
          msg = 'This account has been disabled.';
          break;
        default:
          msg = e.message ?? e.code;
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = await _resolveEmail(_user.text);
    if (email == null || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter your email (or username linked to an email) to reset.',
          ),
        ),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset email sent to $email')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send reset email.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final onBg = cs.onBackground;
    final accent = cs.primary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: onBg,
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Back',
        ),
      ),
        body: ThemedAuthBackground(
          child: SafeArea(
            child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  // Glowing card with form
                  DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: accent.withOpacity(0.5),
                          blurRadius: 28,
                          spreadRadius: 1,
                        ),
                      ],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: accent,
                          width: 2,
                        ),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Login',
                              textAlign: TextAlign.left,
                              style: GoogleFonts.poppins(
                                textStyle: theme.textTheme.titleLarge?.copyWith(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: onBg,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _Field(
                              label: 'Email or username',
                              controller: _user,
                              textInputAction: TextInputAction.next,
                              validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Enter your email or username'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _password,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              style: GoogleFonts.poppins(
                                textStyle:
                                theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurface,
                                ),
                              ),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                labelStyle: GoogleFonts.poppins(
                                  textStyle:
                                  theme.textTheme.bodySmall?.copyWith(
                                    color:
                                    cs.onSurface.withOpacity(0.7),
                                  ),
                                ),
                                filled: true,
                                fillColor: theme.brightness ==
                                    Brightness.dark
                                    ? Colors.white.withOpacity(0.03)
                                    : Colors.black.withOpacity(0.03),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: cs.onSurface.withOpacity(
                                      theme.brightness == Brightness.dark
                                          ? 0.20
                                          : 0.16,
                                    ),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: accent,
                                    width: 1.4,
                                  ),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Enter your password'
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.center,
                              child: TextButton(
                                onPressed: _busy ? null : _forgotPassword,
                                child: Text(
                                  'Forgot password?',
                                  style: GoogleFonts.poppins(
                                    color: accent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _busy ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accent,
                                  foregroundColor: cs.onPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                  textStyle: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                child: _busy
                                    ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                    AlwaysStoppedAnimation<Color>(
                                      cs.onPrimary,
                                    ),
                                  ),
                                )
                                    : const Text('Login'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Bottom "Create account" button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pushNamed('/signup'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: accent,
                          width: 1.6,
                        ),
                        shape: const StadiumBorder(),
                        backgroundColor: Colors.transparent,
                        foregroundColor: accent,
                        textStyle: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Create account'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
        ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _Field({
    required this.label,
    required this.controller,
    this.textInputAction,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final fillColor = isDark
        ? Colors.white.withOpacity(0.03)
        : Colors.black.withOpacity(0.03);
    final labelColor = cs.onSurface.withOpacity(0.7);
    final borderColor =
    cs.onSurface.withOpacity(isDark ? 0.20 : 0.16);

    return TextFormField(
      controller: controller,
      style: GoogleFonts.poppins(
        textStyle: theme.textTheme.bodyMedium?.copyWith(
          color: cs.onSurface,
        ),
      ),
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
          textStyle: theme.textTheme.bodySmall?.copyWith(
            color: labelColor,
          ),
        ),
        filled: true,
        fillColor: fillColor,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: borderColor,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: cs.primary,
            width: 1.4,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      validator: validator,
    );
  }
}
