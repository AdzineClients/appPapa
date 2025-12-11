import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:app_papa/ui/widgets/themed_auth_background.dart';


class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _username  = TextEditingController();
  final _email     = TextEditingController();
  final _password  = TextEditingController();
  final _confirm   = TextEditingController();

  bool _busy = false;

  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  static final Uri _termsUrl   = Uri.parse('https://example.com/terms');
  static final Uri _privacyUrl = Uri.parse('https://example.com/privacy');

  @override
  void initState() {
    super.initState();
    _termsTap   = TapGestureRecognizer()..onTap = () => _openUrl(_termsUrl);
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  }

  Future<void> _createAndFinish() async {
    if (!_formKey.currentState!.validate()) return;

    final rawUsername = _username.text.trim();
    final handle      = rawUsername.toLowerCase();
    final email       = _email.text.trim();
    final pass        = _password.text;
    final functions   = FirebaseFunctions.instance;

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
      // quick client-side username check
      final unameSnap = await FirebaseFirestore.instance
          .collection('username')
          .doc(handle)
          .get();

      if (unameSnap.exists) {
        if (!mounted) return;
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That username is already taken.')),
        );
        return;
      }

      // 1) Create auth user
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: pass);
      newUser = cred.user!;
      await newUser.sendEmailVerification();

      if (!mounted) return;

      // 2) Ask user to verify email
      final verified = await _showEmailVerificationDialog(newUser);
      if (!verified) {
        await FirebaseAuth.instance.signOut();
        return;
      }

      await newUser.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      if (refreshed == null || !refreshed.emailVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email not verified. Please try again.')),
        );
        return;
      }

      // 3) Cloud Function to create profile
      final callable = functions.httpsCallable('createUserProfile');
      try {
        await callable.call(<String, dynamic>{
          'username': rawUsername,
          'email': email,
        });
      } on FirebaseFunctionsException catch (e) {
        String msg;
        if (e.code == 'already-exists') {
          msg = 'That username is already taken.';
        } else {
          msg = 'Could not finish account setup. Please try again.';
        }
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
        }
        return;
      }

      if (!mounted) return;

      // 4) Done
      Navigator.of(context).popUntil((r) => r.isFirst);
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'That email is already in use.';
          break;
        case 'invalid-email':
          msg = 'Invalid email address.';
          break;
        case 'weak-password':
          msg = 'Password too weak.';
          break;
        default:
          msg = e.message ?? e.code;
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (_) {
      if (newUser != null) {
        try {
          await newUser.delete();
        } catch (_) {}
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not create the account. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _showEmailVerificationDialog(User user) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final cs = theme.colorScheme;
        final onBg = cs.onBackground;

        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Verify your email',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: onBg,
            ),
          ),
          content: Text(
            'We sent a verification link to ${user.email}. '
                'Tap the link in your email, then press “I verified” below.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: onBg.withOpacity(0.9),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await user.reload();
                final refreshed = FirebaseAuth.instance.currentUser;
                final ok = refreshed?.emailVerified ?? false;
                if (ok) {
                  Navigator.of(dialogContext).pop(true);
                } else {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Email not verified yet.'),
                    ),
                  );
                }
              },
              child: const Text('I verified'),
            ),
            TextButton(
              onPressed: () async {
                await user.sendEmailVerification();
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Verification email resent.'),
                  ),
                );
              },
              child: const Text('Resend email'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final onBg = cs.onBackground;
    final accent = cs.primary;

    return Scaffold(
      // backgroundColor comes from theme.scaffoldBackgroundColor
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: onBg,
          onPressed: () => Navigator.of(context).maybePop(),
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
                  // Logo

                  // Title
                  Align(
                    alignment: Alignment.center,
                    child: Text(
                      'Create your account',
                      style: GoogleFonts.poppins(
                        textStyle: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: onBg,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

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
                      border: Border.all(
                        color: accent,
                        width: 2,
                      ),
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
                            _DarkField(
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
                            _DarkField(
                              label: 'Email',
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: (v) =>
                              (v == null || !v.contains('@'))
                                  ? 'Enter a valid email'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            _DarkField(
                              label: 'Password',
                              controller: _password,
                              obscureText: true,
                              textInputAction: TextInputAction.next,
                              validator: (v) =>
                              (v == null || v.length < 8)
                                  ? 'Min 8 characters'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            _DarkField(
                              label: 'Confirm password',
                              controller: _confirm,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              validator: (v) =>
                              (v != _password.text)
                                  ? 'Passwords don’t match'
                                  : null,
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _busy ? null : _createAndFinish,
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
                                    : const Text('Create'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // “Already have an account?”
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context)
                        .pushReplacementNamed('/login'),
                    child: Text(
                      'Already have an account? Login',
                      style: GoogleFonts.poppins(
                        color: accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Legal text
                  Text.rich(
                    TextSpan(
                      text: 'By signing up you agree to the ',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: onBg.withOpacity(0.9),
                      ),
                      children: [
                        TextSpan(
                          text: 'Terms & Conditions',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                          recognizer: _termsTap,
                        ),
                        const TextSpan(text: ' and have read the '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                          recognizer: _privacyTap,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
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

class _DarkField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;

  const _DarkField({
    required this.label,
    required this.controller,
    this.textInputAction,
    this.keyboardType,
    this.validator,
    this.obscureText = false,
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
    final borderColor = cs.onSurface.withOpacity(isDark ? 0.20 : 0.16);

    return TextFormField(
      controller: controller,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: GoogleFonts.poppins(
        textStyle: theme.textTheme.bodyMedium?.copyWith(
          color: cs.onSurface,
        ),
      ),
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
          borderSide: BorderSide(color: borderColor),
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
