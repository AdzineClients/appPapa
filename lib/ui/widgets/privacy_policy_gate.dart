// lib/widgets/privacy_policy_gate.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const String kPrivacyPolicyVersion = '2025-12-01';
const String kTermsVersion         = '2025-12-01';

class PrivacyPolicyGate extends StatelessWidget {
  final String userId;
  final Widget child;

  const PrivacyPolicyGate({
    Key? key,
    required this.userId,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        debugPrint(
          'PPGate snap: state=${snapshot.connectionState} '
              'hasData=${snapshot.hasData} exists=${snapshot.data?.exists} '
              'data=${snapshot.data?.data()}',
        );

        if (snapshot.hasError) {
          debugPrint('PrivacyPolicyGate snapshot error: ${snapshot.error}');
          return child;
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return child;
        }

        final data = snapshot.data!.data() ?? {};
        final acceptedPrivacy = data['acceptedPrivacy'] == true;
        final acceptedTerms   = data['acceptedTerms'] == true;

        final needsPrivacy = !acceptedPrivacy;
        final needsTerms   = !acceptedTerms;

        // Both accepted → nothing to gate.
        if (!needsPrivacy && !needsTerms) {
          return child;
        }

        return Stack(
          children: [
            child,

            // Scrim that blocks taps behind.
            Positioned.fill(
              child: IgnorePointer(
                ignoring: false,
                child: Container(
                  color: Colors.black.withOpacity(isDark ? 0.65 : 0.45),
                ),
              ),
            ),

            Align(
              alignment: Alignment.bottomCenter,
              child: _LegalOverlay(
                userId: userId,
                showPrivacy: needsPrivacy,
                showTerms: needsTerms,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LegalOverlay extends StatefulWidget {
  const _LegalOverlay({
    required this.userId,
    required this.showPrivacy,
    required this.showTerms,
  });

  final String userId;
  final bool showPrivacy;
  final bool showTerms;

  @override
  State<_LegalOverlay> createState() => _LegalOverlayState();
}

class _LegalOverlayState extends State<_LegalOverlay> {
  bool _isAcceptingPrivacy = false;
  bool _isAcceptingTerms   = false;

  bool _showPrivacyDialog  = false;
  bool _showTermsDialog    = false;

  // ---------- FIRESTORE WRITES ----------

  Future<void> _acceptPrivacy() async {
    if (_isAcceptingPrivacy) return;
    setState(() => _isAcceptingPrivacy = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final userRef   = firestore.collection('users').doc(widget.userId);
      final legalRef  = userRef.collection('legal').doc();

      final batch = firestore.batch();

      batch.set(
        userRef,
        {'acceptedPrivacy': true},
        SetOptions(merge: true),
      );

      batch.set(legalRef, {
        'type': 'privacy',
        'version': kPrivacyPolicyVersion,
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('PrivacyGate: committing accept PRIVACY batch…');
      await batch.commit();
      debugPrint('PrivacyGate: accept PRIVACY batch committed ✅');

      if (mounted) _showPrivacyDialog = false;
    } catch (e, st) {
      debugPrint('Error setting acceptedPrivacy: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAcceptingPrivacy = false);
    }
  }

  Future<void> _acceptTerms() async {
    if (_isAcceptingTerms) return;
    setState(() => _isAcceptingTerms = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final userRef   = firestore.collection('users').doc(widget.userId);
      final legalRef  = userRef.collection('legal').doc();

      final batch = firestore.batch();

      batch.set(
        userRef,
        {'acceptedTerms': true},
        SetOptions(merge: true),
      );

      batch.set(legalRef, {
        'type': 'terms',
        'version': kTermsVersion,
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('PrivacyGate: committing accept TERMS batch…');
      await batch.commit();
      debugPrint('PrivacyGate: accept TERMS batch committed ✅');

      if (mounted) _showTermsDialog = false;
    } catch (e, st) {
      debugPrint('Error setting acceptedTerms: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAcceptingTerms = false);
    }
  }

  // ---------- STYLES (THEMED) ----------

  ButtonStyle _leftButtonStyle() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return TextButton.styleFrom(
      backgroundColor: cs.surfaceVariant,
      foregroundColor: cs.onSurface,
      side: BorderSide(color: cs.outlineVariant ?? cs.outline),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  ButtonStyle _rightButtonStyle() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return TextButton.styleFrom(
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  // ---------- BUILD ----------

  @override
  Widget build(BuildContext context) {
    final showPrivacy = widget.showPrivacy;
    final showTerms   = widget.showTerms;

    return SafeArea(
      minimum: const EdgeInsets.all(16),
      child: Stack(
        children: [
          // Bottom-stacked popups
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showTerms)
                    _buildCard(
                      title:
                      "You haven't accepted the Terms & Conditions",
                      readLabel: 'Read Terms & Conditions',
                      acceptLabel: 'Accept Terms & Conditions',
                      onRead: () =>
                          setState(() => _showTermsDialog = true),
                      onAccept: _acceptTerms,
                      isAccepting: _isAcceptingTerms,
                    ),
                  if (showTerms && showPrivacy)
                    const SizedBox(height: 12),
                  if (showPrivacy)
                    _buildCard(
                      title:
                      "You haven't accepted the Privacy Policy",
                      readLabel: 'Read Privacy Policy',
                      acceptLabel: 'Accept Privacy Policy',
                      onRead: () =>
                          setState(() => _showPrivacyDialog = true),
                      onAccept: _acceptPrivacy,
                      isAccepting: _isAcceptingPrivacy,
                    ),
                ],
              ),
            ),
          ),

          // Fullscreen dialogs (one at a time)
          if (showPrivacy && _showPrivacyDialog)
            _buildFullDialog(
              title: 'Privacy Policy',
              text: _privacyPolicyText,
              isAccepting: _isAcceptingPrivacy,
              onBack: () =>
                  setState(() => _showPrivacyDialog = false),
              onAccept: _acceptPrivacy,
            ),
          if (showTerms && _showTermsDialog)
            _buildFullDialog(
              title: 'Terms & Conditions',
              text: _termsText,
              isAccepting: _isAcceptingTerms,
              onBack: () =>
                  setState(() => _showTermsDialog = false),
              onAccept: _acceptTerms,
            ),
        ],
      ),
    );
  }

  // ---------- UI HELPERS ----------

  Widget _buildCard({
    required String title,
    required String readLabel,
    required String acceptLabel,
    required VoidCallback onRead,
    required VoidCallback onAccept,
    required bool isAccepting,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(
          minHeight: 150,
          maxHeight: 188,
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  height: 60,
                  width: 60,
                  child: Image.asset(
                    'assets/images/appPapaLogo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: _leftButtonStyle(),
                    onPressed: onRead,
                    child: Text(
                      readLabel,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    style: _rightButtonStyle(),
                    onPressed: isAccepting ? null : onAccept,
                    child: isAccepting
                        ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                        : Text(
                      acceptLabel,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullDialog({
    required String title,
    required String text,
    required bool isAccepting,
    required VoidCallback onBack,
    required Future<void> Function() onAccept,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Material(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            constraints: const BoxConstraints(
              maxHeight: 600,
              maxWidth: 600,
            ),
            child: Column(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      child: Text(
                        text,
                        style: TextStyle(
                          color: cs.onSurface.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: _leftButtonStyle(),
                        onPressed: onBack,
                        child: const Text(
                          'Back',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        style: _rightButtonStyle(),
                        onPressed: isAccepting ? null : onAccept,
                        child: isAccepting
                            ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                            : const Text(
                          'Accept',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// NOTE: _privacyPolicyText and _termsText should be defined elsewhere
// (as in your existing code) and can stay unchanged.


const String _termsText = '''
PAPA – TERMS & CONDITIONS
Effective Date: December 1, 2025

These Terms & Conditions ("Terms") govern your use of the PaPa mobile application and related services (collectively, the "App"). The App is developed and operated by Adzine ("Adzine", "we", "us", "our").

By downloading, installing, accessing, or using the App, you agree to be bound by these Terms. If you do not agree, do not use the App.

If you are using the App on behalf of another person or entity, you confirm that you have authority to accept these Terms on their behalf.

1. ABOUT THE APP
PaPa is a mobile game where users:
- Play solo minigames to obtain an approximate IQ score; and
- Participate in competition modes, earning trophies and climbing rankings against other players.

The IQ results in the App are for entertainment purposes only and do not represent a medically, scientifically, or professionally validated measure of intelligence.

2. ELIGIBILITY
You may only use the App if:
- You are at least 13 years old (or the minimum age required in your country to use such services); and
- You are legally allowed to enter into a binding agreement in your country of residence.

If you are under the legal age, you must have your parent or legal guardian’s permission to use the App.

3. YOUR ACCOUNT
To use certain features of the App, you must create an account.

You agree to:
- Provide accurate and up-to-date information during registration;
- Keep your login credentials secure and confidential; and
- Be fully responsible for all activity that happens under your account.

If you believe your account has been accessed without your permission, you must notify us as soon as possible.

4. OWNERSHIP OF ACCOUNTS, DATA & GAME CONTENT

4.1 Ownership
All rights, title, and interest in and to the App, including but not limited to:
- Game code, visuals, graphics, animations, sounds, and design;
- In-game items, trophies, IQ scores, rankings, and other virtual content;
- Account structures and related game data,

are owned by Adzine or its licensors.

You do not own your account, any in-game items, trophies, or other virtual content. Subject to your compliance with these Terms, Adzine grants you a limited, personal, non-exclusive, non-transferable, revocable license to use the App for your own personal entertainment.

4.2 User-provided content
Some information or content is provided by you, for example:
- Your username;
- Profile details and any other content you submit in the App (if such features are available).

You are solely responsible for all content you provide. By submitting content, you grant Adzine a worldwide, non-exclusive, royalty-free license to use, reproduce, modify, and display that content in connection with operating and improving the App.

You confirm that you have the right to provide such content and that it does not infringe any third-party rights.

5. PROHIBITED CONDUCT
You agree that you will not:

1) Sell, trade, gift, or otherwise transfer accounts or access
- You may not sell, buy, trade, rent, or otherwise transfer your account, your login details, or access to the App, whether for money, items, or any other value, inside or outside the App.

2) Sell or trade in-game items or virtual content outside approved channels
- Any in-game items, currency, or virtual content may only be acquired through the App or through partners expressly approved by Adzine.
- You may not sell, buy, trade, or transfer in-game items, trophies, IQ results, or any other game benefits outside of methods provided or approved by Adzine.

3) Use the App for unlawful or harmful purposes
- You may not use the App for any illegal activities or to violate any laws or regulations.

4) Use offensive or infringing usernames or content
- You are responsible for any username or other content you submit. You may not submit content that is:
  - Illegal, harassing, hateful, or discriminatory;
  - Pornographic or sexually explicit;
  - Violent or threatening;
  - Infringing on someone else’s intellectual property, privacy, or other rights.

5) Cheat or interfere with the App
- You may not:
  - Use bots, scripts, hacks, or unauthorized third-party software to gain advantage in the game;
  - Reverse-engineer, decompile, or attempt to extract the source code of the App;
  - Interfere with normal operation of the App, its servers, or other users’ experience.

6) Misrepresent yourself or impersonate others
- You may not pretend to be another person or misrepresent your identity or affiliation.

Adzine reserves the right, at its sole discretion, to take action (including warnings, temporary suspension, or permanent account termination) if you violate these rules.

6. VIRTUAL ITEMS & PURCHASES

6.1 How you may purchase
You may only purchase in-app items or services:
- Through the official purchase flows inside the App (for example, Apple App Store, Google Play, or other supported store); or
- Through partners or channels explicitly approved by Adzine.

Any offers to buy or sell in-game items, accounts, or benefits outside of these approved methods are not allowed and are considered a violation of these Terms.

6.2 No cash value
Virtual items and in-game content:
- Do not have any real-world monetary value;
- Cannot be redeemed for cash or other real-world goods;
- Are licensed to you, not sold, and can be modified or removed by Adzine as needed.

6.3 Refunds
All purchases are typically final and non-refundable, except where:
- Required by applicable law; or
- A platform (such as the App Store or Google Play) offers its own refund policy.

Any refund requests should be submitted through the appropriate app store or directly to us, as applicable.

7. USER RESPONSIBILITY & SAFETY
You understand and agree that:
- You use the App at your own risk.
- You are responsible for any activity conducted under your account, including content submitted or actions taken in competitions.
- You are responsible for ensuring that your use of the App complies with all applicable laws where you live.

If you encounter other users violating these Terms, you are encouraged to report it through the support channels provided in the App (if available).

8. CHANGES TO THE APP & TO THESE TERMS
Adzine may update, modify, or discontinue parts of the App at any time, including:
- Adding or removing features, modes, or minigames;
- Adjusting balancing, scoring, or ranking systems;
- Changing the availability of virtual items.

We may also update these Terms from time to time. When we make material changes, we will update the Effective Date at the top and may provide additional notice inside the App.

Your continued use of the App after the updated Terms become effective means you accept the changes. If you do not agree to the updated Terms, you must stop using the App.

9. SUSPENSION & TERMINATION
We may, at our discretion and without prior notice, suspend or terminate your account or access to the App if:
- You violate these Terms or applicable laws;
- You engage in cheating, fraud, or harmful behavior;
- We are required to do so by law or by a platform provider;
- We discontinue the App.

If your account is suspended or terminated:
- You may lose access to your account, progress, IQ results, trophies, and virtual items; and
- You are not entitled to compensation or refunds for any lost virtual items or content, except where required by law.

You may also choose to stop using the App at any time. Some data may still be retained as described in our Privacy Policy.

10. INTELLECTUAL PROPERTY
All trademarks, logos, and brand elements related to PaPa and Adzine are owned by Adzine or its licensors.

You may not use our name, logo, or any App content in any way that could cause confusion or suggest endorsement, unless you receive written permission from us.

11. DISCLAIMERS
To the fullest extent permitted by law:
- The App is provided "as is" and "as available" without warranties of any kind, whether express or implied.
- We do not guarantee that the App will be uninterrupted, error-free, or free of harmful components.
- We do not guarantee that any IQ score, ranking, or game result is accurate, scientific, or suitable for any professional or diagnostic use. They are for entertainment only.

Some jurisdictions do not allow the exclusion of certain warranties, so some of the above exclusions may not apply to you.

12. LIMITATION OF LIABILITY
To the fullest extent permitted by law, Adzine and its affiliates, officers, employees, and partners will not be liable for:
- Any indirect, incidental, special, consequential, or punitive damages;
- Any loss of data, loss of profits, or loss of opportunity;
- Any damages arising out of or related to your use of (or inability to use) the App.

In any case, our total liability to you for all claims relating to the App will be limited to the amount you have paid to us (if any) in the 6 months immediately before the claim arose, or the minimum amount required by applicable law, whichever is higher.

Some jurisdictions do not allow certain limitations of liability, so some of these limits may not apply to you.

13. GOVERNING LAW
These Terms are governed by the laws applicable in the region where Adzine is established, without regard to conflict of law rules, unless a different law is required by your local consumer protection rules.

If any part of these Terms is found to be invalid or unenforceable, the remaining provisions will remain in full force and effect.

14. CONTACT
If you have questions or concerns about these Terms, you can contact us at:

Adzine
Email: legal@adzine.io

Please include "Legal Attention – Terms & Conditions" as the reason or subject of the email.
''';


/// Full Privacy Policy text used in the popup.
/// You can tweak wording here and the dialog will update automatically.
const String _privacyPolicyText = '''
PRIVACY POLICY – PAPA
Effective Date: December 1, 2025

This Privacy Policy explains how Adzine (“Adzine”, “we”, “us”, or “our”) collects, uses, and protects information when you use our mobile application PaPa (the “App”).

PaPa is a game where users play solo minigames to get an approximate IQ and can also participate in competition modes to earn trophies and rank up against other players.

By creating an account or using the App, you agree to this Privacy Policy. If you do not agree, please do not use the App.

1. WHO WE ARE & HOW TO CONTACT US

The App is developed and operated by:

Adzine
Email: legal@adzine.io

If you have any questions about this Privacy Policy or your personal data, you can contact us at the email above. Please include “Legal Attention” as the reason or subject of the email so we can route your request correctly.

2. SCOPE OF THIS POLICY

This Privacy Policy applies to:
- Your use of the PaPa mobile application; and
- Any in-app services, features, and content offered through PaPa.

It does not apply to third-party services you may access through external links or ads (if added in the future). Those services have their own privacy policies.

3. INFORMATION WE COLLECT

We collect two main types of information:
1) Information you provide to us directly, and
2) Information collected automatically when you use the App.

3.1 Information You Provide

When you create and use an account in PaPa, we collect:
- Email address – used to create and manage your account, send verification emails, and communicate about your account or important changes.
- Password – stored securely using industry-standard hashing via Firebase Authentication.
- Username – used to identify you in the App (e.g., in leaderboards and competition rankings).

If you contact us (for example, through support or email), we may also collect:
- The content of your message and any information you choose to provide.

3.2 Information Collected Automatically

Through our use of Firebase and similar tools, we may automatically collect:

Account and gameplay data
- Your internal user ID
- Your progress in minigames
- Scores, trophies, and ranking information
- In-app actions related to gameplay and competitions

Technical and device data (as provided by Firebase and your device)
- Device type/model and operating system version
- App version and basic performance/error information
- IP address (which may give an approximate location, such as city or country)

We use this information mainly to operate, secure, and improve the App.

4. HOW WE USE YOUR INFORMATION

We use the information we collect for the following purposes:

To operate and provide the App
- Create and manage your account
- Allow you to play solo minigames and competition modes
- Maintain leaderboards, rankings, and trophies
- Store and update your game progress

To improve and develop the App
- Monitor performance and fix bugs or crashes
- Analyze how players use different features to improve gameplay, balance, and user experience
- Develop new features, minigames, and modes

To communicate with you
- Send account-related messages (for example, verification, security alerts, important changes to the App or this policy)
- Respond to your support requests or questions

To keep the App safe and fair
- Detect and prevent cheating, fraud, abuse, and security issues
- Enforce our Terms and Conditions and other policies

To personalize your experience (now and in the future)
- Currently, personalization is limited to in-app features such as your progress and rankings.
- In the future, we may use cookies or similar technologies to provide more personalized experiences (see Section 7).

To comply with legal obligations
- Maintain records as required by law
- Respond to lawful requests from authorities where applicable

5. LEGAL BASES (IF YOU ARE IN THE EU/EEA OR SIMILAR REGIONS)

Where applicable (for example, if you are in the EU/EEA or UK), we rely on the following legal bases:
- Performance of a contract: To provide the App and its features after you create an account.
- Legitimate interests: To improve the App, keep it secure and fair, prevent abuse, and analyze aggregated usage data.
- Legal obligations: To comply with legal and regulatory requirements.
- Consent: For any optional features that require consent (for example, certain cookies or personalized features, if and when added).

6. HOW WE STORE & PROTECT YOUR INFORMATION

6.1 Storage (Firebase)

We use Google’s Firebase services to operate and store data for PaPa, including:
- Firebase Authentication – to manage accounts, emails, and passwords.
- Cloud Functions – to securely handle most writes, updates, and deletions of data.
- Firebase Firestore / Storage – to store account data, gameplay info, and related content.

We configure Firebase security rules so that:
- Direct write/delete access from the client is restricted where possible.
- Most sensitive changes are performed through secure Cloud Functions.

The exact storage location of Firebase data depends on Google’s infrastructure and region settings.

6.2 Security

We use reasonable technical and organizational measures to protect your information, including:
- Secure account management through Firebase Authentication
- Restricted access to databases
- Use of encryption in transit (HTTPS)
- Logging and monitoring to detect suspicious activity

However, no system can be 100% secure, and we cannot guarantee absolute security.

7. COOKIES & SIMILAR TECHNOLOGIES

At the moment, PaPa does not use cookies inside the app.

In the future, we may use cookies, local storage, or similar technologies (for example, if we add a web version or introduce personalization features). These may be used to:
- Remember your preferences
- Provide a smoother and more personalized experience
- Analyze how the App is used

If and when we add cookies or similar technologies:
- We will update this Privacy Policy and, where required, ask for your consent or provide an option to manage your choices.

8. HOW WE SHARE YOUR INFORMATION

We do not sell your personal data.

We may share your information in the following limited situations:

Service providers
- We share data with third-party service providers who help us operate the App (for example, Firebase/Google).
- These providers process data on our behalf and are not allowed to use it for their own independent purposes unrelated to the App.

Legal reasons
- We may disclose information if required by law, court order, or a valid legal request.
- We may also share information to protect our rights, our users, or others (for example, to prevent fraud, abuse, or security threats).

Business transfers
- If we are involved in a merger, acquisition, or sale of assets, your data may be transferred as part of that transaction. We will take reasonable steps to ensure your rights remain protected.

With your consent
- We may share information for other purposes if you explicitly allow or request it.

9. INTERNATIONAL DATA TRANSFERS

Because we use third-party services such as Firebase (provided by Google), your information may be stored or processed in countries other than your own.

Where required by law, we will take appropriate steps to ensure that any international transfers provide adequate protection for your personal data (for example, using standard contractual clauses or similar safeguards).

10. DATA RETENTION & ACCOUNT DELETION

10.1 How long we keep your data

We keep your information for as long as it is necessary to:
- Operate the App
- Provide you with your account, progress, and competition features
- Meet our legal and accounting obligations
- Resolve disputes and enforce our agreements

10.2 Deleting your account

You have the right to delete your account.

When you request account deletion, we will deactivate your account and stop using your personal data for active gameplay or ranking purposes.
However, we may keep a copy of your data in backups, logs, and internal records for a limited period of time, for reasons such as:
- Compliance with legal obligations
- Security, fraud detection, and abuse prevention
- Internal record-keeping and audits

Where possible, we will anonymize or aggregate data so that it no longer identifies you personally.

11. YOUR RIGHTS & CHOICES

Depending on your location and applicable laws, you may have the following rights:

- Access: Request a copy of the personal data we hold about you.
- Correction: Request that we correct inaccurate or incomplete data.
- Deletion: Request that we delete your personal data (subject to our legal and legitimate interests as described above).
- Restriction or objection: In some cases, request that we limit or stop certain processing.
- Withdraw consent: Where processing is based on your consent, you can withdraw it at any time (this will not affect processing done before withdrawal).

To exercise any of these rights, contact us at:

legal@adzine.io

Please include “Legal Attention” as the reason or subject of the email so we can route your request correctly.

We may ask you to verify your identity before fulfilling your request.

12. CHILDREN’S PRIVACY

PaPa is not intended for children under 13 years of age (or the minimum age required in your country), and we do not knowingly collect personal data from children under that age.

If we learn that we have collected personal data from a child under the applicable minimum age without proper consent, we will delete that information as soon as reasonably possible.
If you are a parent or guardian and believe your child has provided us with personal data, please contact us at legal@adzine.io with “Legal Attention” as the reason or subject of the email.

13. CHANGES TO THIS PRIVACY POLICY

We may update this Privacy Policy from time to time.

When we make material changes, we will update the “Effective Date” at the top and, where appropriate, provide additional notice (for example, inside the App).
Your continued use of the App after the updated Privacy Policy becomes effective means you accept the changes.

14. CONTACT

If you have questions, concerns, or requests related to this Privacy Policy or your personal data, you can contact us at:

Adzine
Email: legal@adzine.io
Please include “Legal Attention” as the reason or subject of the email.
''';

const String kPrivacyPolicyText = _privacyPolicyText;
const String kTermsText         = _termsText;