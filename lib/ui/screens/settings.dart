import 'package:app_papa/ui/screens/editProfile.dart';
import 'package:app_papa/ui/screens/permissions.dart';
import 'package:app_papa/ui/widgets/audio_controller.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'achivements.dart';
import 'package:app_papa/ui/widgets/privacy_policy_gate.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  User? get _user => FirebaseAuth.instance.currentUser;

  String? leagueBrainTitle(String? league, String lang) {
  if (league == null || league.trim().isEmpty) return null;

  switch (league.toLowerCase()) {
    case 'bronze':
      return _t('league_bronze', lang);
    case 'iron':
      return _t('league_iron', lang);
    case 'silver':
      return _t('league_silver', lang);
    case 'gold':
      return _t('league_gold', lang);
    case 'platinum':
      return _t('league_platinum', lang);
    case 'diamond':
      return _t('league_diamond', lang);
    case 'master':
      return _t('league_master', lang);
    default:
      return null;
  }
}

  String _languageLabel(String? code) {
    final c = (code ?? 'en').toLowerCase();

    switch (c) {
      case 'en':
      case 'english':
        return 'English';
      case 'es':
      case 'spanish':
        return 'Español';
      case 'fr':
      case 'french':
        return 'Français';
      case 'de':
      case 'german':
        return 'Deutsch';
      case 'pt':
      case 'portuguese':
        return 'Português';
      default:
        // fallback: capitalize first letter if it's something weird
        return c.isNotEmpty ? c[0].toUpperCase() + c.substring(1) : 'English';
    }
  }


  String _t(String key, String language) {
  // normalize
  final code = language.toLowerCase();

  switch (key) {
    case 'settings_title':
      if (code == 'es') return 'Configuración';
      if (code == 'fr') return 'Paramètres';
      if (code == 'de') return 'Einstellungen';
      if (code == 'pt') return 'Configurações';
      return 'Settings';

    case 'edit_profile':
      if (code == 'es') return 'Editar perfil';
      if (code == 'fr') return 'Modifier le profil';
      if (code == 'de') return 'Profil bearbeiten';
      if (code == 'pt') return 'Editar perfil';
      return 'Edit Profile';

    case 'game_settings':
      if (code == 'es') return 'Ajustes de juego';
      if (code == 'fr') return 'Paramètres de jeu';
      if (code == 'de') return 'Spieleinstellungen';
      if (code == 'pt') return 'Configurações do jogo';
      return 'Game Settings';

    case 'help_support':
      if (code == 'es') return 'Ayuda y soporte';
      if (code == 'fr') return 'Aide et support';
      if (code == 'de') return 'Hilfe & Support';
      if (code == 'pt') return 'Ajuda e suporte';
      return 'Help & Support';

    case 'how_to_play':
      if (code == 'es') return 'Cómo jugar';
      if (code == 'fr') return 'Comment jouer';
      if (code == 'de') return 'So wird gespielt';
      if (code == 'pt') return 'Como jogar';
      return 'How to Play';

        case 'permissions':
      if (code == 'es') return 'Permisos';
      if (code == 'fr') return 'Autorisations';
      if (code == 'de') return 'Berechtigungen';
      if (code == 'pt') return 'Permissões';
      return 'Permissions';

    case 'terms_conditions':
      if (code == 'es') return 'Términos y condiciones';
      if (code == 'fr') return 'Conditions générales';
      if (code == 'de') return 'Allgemeine Geschäftsbedingungen';
      if (code == 'pt') return 'Termos e condições';
      return 'Terms & Conditions';

    case 'privacy_policy':
      if (code == 'es') return 'Política de privacidad';
      if (code == 'fr') return 'Politique de confidentialité';
      if (code == 'de') return 'Datenschutzrichtlinie';
      if (code == 'pt') return 'Política de privacidade';
      return 'Privacy Policy';

    case 'logout':
      if (code == 'es') return 'Cerrar sesión';
      if (code == 'fr') return 'Se déconnecter';
      if (code == 'de') return 'Abmelden';
      if (code == 'pt') return 'Sair';
      return 'Logout';

    case 'achievements':
      if (code == 'es') return 'Logros';
      if (code == 'fr') return 'Succès';
      if (code == 'de') return 'Erfolge';
      if (code == 'pt') return 'Conquistas';
      return 'Achievements';


    case 'audio':
      if (code == 'es') return 'Sonido';
      if (code == 'fr') return 'Audio';
      if (code == 'de') return 'Audio';
      if (code == 'pt') return 'Áudio';
      return 'Audio';

    case 'language_label':
      if (code == 'es') return 'Idioma';
      if (code == 'fr') return 'Langue';
      if (code == 'de') return 'Sprache';
      if (code == 'pt') return 'Idioma';
      return 'Language';

    case 'language_title':
      if (code == 'es') return 'Idioma';
      if (code == 'fr') return 'Langue';
      if (code == 'de') return 'Sprache';
      if (code == 'pt') return 'Idioma';
      return 'Language';

    case 'close':
      if (code == 'es') return 'Cerrar';
      if (code == 'fr') return 'Fermer';
      if (code == 'de') return 'Schließen';
      if (code == 'pt') return 'Fechar';
      return 'Close';
    
        case 'league_bronze':
      if (code == 'es') return 'Cerebro diminuto';
      if (code == 'fr') return 'Petit cerveau';
      if (code == 'de') return 'Winziges Gehirn';
      if (code == 'pt') return 'Cérebro pequeno';
      return 'Tiny Brain';

    case 'league_iron':
      if (code == 'es') return 'Cerebro decente';
      if (code == 'fr') return 'Cerveau correct';
      if (code == 'de') return 'Ordentliches Gehirn';
      if (code == 'pt') return 'Cérebro decente';
      return 'Decent Brain';

    case 'league_silver':
      if (code == 'es') return 'Cerebro inteligente';
      if (code == 'fr') return 'Cerveau intelligent';
      if (code == 'de') return 'Kluges Gehirn';
      if (code == 'pt') return 'Cérebro inteligente';
      return 'Smart Brain';

    case 'league_gold':
      if (code == 'es') return 'Gran cerebro';
      if (code == 'fr') return 'Gros cerveau';
      if (code == 'de') return 'Großes Gehirn';
      if (code == 'pt') return 'Grande cérebro';
      return 'Big Brain';

    case 'league_platinum':
      if (code == 'es') return 'Cerebro arquitecto';
      if (code == 'fr') return 'Cerveau architecte';
      if (code == 'de') return 'Architektengehirn';
      if (code == 'pt') return 'Cérebro arquiteto';
      return 'Architect Brain';

    case 'league_diamond':
      if (code == 'es') return 'Cerebro genio';
      if (code == 'fr') return 'Cerveau de génie';
      if (code == 'de') return 'Genialisches Gehirn';
      if (code == 'pt') return 'Cérebro gênio';
      return 'Genius Brain';

    case 'league_master':
      if (code == 'es') return 'Cerebro trascendente';
      if (code == 'fr') return 'Cerveau transcendant';
      if (code == 'de') return 'Transzendentes Gehirn';
      if (code == 'pt') return 'Cérebro transcendental';
      return 'Transcendent Brain';



    // add more keys as needed...

    default:
      return key;
  }
}

  // Wraps any child with the settings background image
  // Wraps any child with the shared game background
  Widget _withBackground(Widget child) {
    return Stack(
      children: [
        // Background image (same as Play/Shop)
        Positioned.fill(
          child: Image.asset(
            'assets/images/background2.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),

        // Dark overlay
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.65),
          ),
        ),

        // Actual page content
        child,
      ],
    );
  }




  @override
  Widget build(BuildContext context) {
    final uid = _user?.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final avatarBgColor   =
    isDark ? const Color(0x2111318) : const Color(0xf6f7fb); // dark grey / light grey
    final avatarIconColor =
    isDark ? Colors.white70 : const Color(0xFF5A6575);          // softer light grey

  AppBar buildAppBar(String language) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 0,        // 👈 removes the vertical space
    );
  }


String? leagueAsset(String? league) {
  if (league == null || league.trim().isEmpty) return null;
  switch (league.toLowerCase()) {
    case 'bronze':
      return 'assets/leagues/tiny_brain(bronze).png';
    case 'iron':
      return 'assets/leagues/decent_brain(iron).png';
    case 'silver':
      return 'assets/leagues/smart_brain(silver).png';
    case 'gold':
      return 'assets/leagues/big_brain(gold).png';
    case 'platinum':
      return 'assets/leagues/architect_brain(platnium).png';
    case 'diamond':
      return 'assets/leagues/genius_brain(diamond).png';
    case 'master':
      return 'assets/leagues/transcendent_brain(master).png';
    default:
      return null;
  }
}

String avatarStoragePath(String? avatarKey) {
  // For now all users have "defaultBrain"
  final key = (avatarKey ?? 'defaultBrain').toLowerCase();

  switch (key) {
    case 'defaultbrain':
      return 'avatars/defaultBrain.png';
    case 'madbrain':
      return 'avatars/madBrain.png';
    case 'grinningbrain':
      return 'avatars/grinningBrain.png';
    case 'numbbrain':
      return 'avatars/numbBrain.png';
    // later you can add:
    // case 'coolhat': return 'avatars/coolHat.png';
    default:
      return 'avatars/defaultBrain.png';
  }
}




    // Main content builder
    Widget content({
      required String username,
      String? avatarKey,
      int? rank,
      String? league,
      int? iq,
      String? language,      
    }) {
        final lang = (language ?? 'en').toLowerCase();
      const double avatarRadius = 52;
      final theme = Theme.of(context);
      final dividerColor = theme.dividerColor.withOpacity(.5);
      final String? leagueImg = leagueAsset(league);
      final String? leagueTitle = leagueBrainTitle(league, lang);



      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const EditProfileScreen(),
            ),
          );
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Avatar image from Firebase Storage (based on "avatar" field)
            FutureBuilder<String>(
          future: FirebaseStorage.instance
              .ref()
      .child(avatarStoragePath(avatarKey))
      .getDownloadURL(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
      return CircleAvatar(
        radius: avatarRadius,
        backgroundColor: avatarBgColor,
        child: Icon(
          Icons.person,
          size: avatarRadius * 0.9,
          color: avatarIconColor,
        ),
      );
        }

    if (snapshot.hasError) {
      print('Avatar load error: ${snapshot.error}');
      return CircleAvatar(
        radius: avatarRadius,
        backgroundColor: avatarBgColor,
        child: Icon(
          Icons.person,
          size: avatarRadius * 0.9,
          color: avatarIconColor,
        ),
      );
    }

    final imageProvider = NetworkImage(snapshot.data!);

    return CircleAvatar(
      radius: avatarRadius,
      backgroundColor: avatarBgColor,
      backgroundImage: imageProvider,
    );
  },
),


            // Pencil badge
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
                const SizedBox(height: 12),
                Text(
                  username,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),

                // NEW: Rank + League row
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
  if (leagueImg != null)
  _LeagueBadge(
    leagueKey: league,
    assetPath: leagueImg,
    title: leagueTitle,
  ),

                    ],
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

                // NEW: full-width stat row (number + image placeholder)
                // NEW: full-width stat row (IQ + #rank + trophy)
if (rank != null || iq != null)
  _LeagueStatRow(
    rank: rank,
    iq: iq,
  ),


          const SizedBox(height: 24),

          const _SectionLabel('Profile'),
          _ThinList(dividerColor: kTileBorderColor, children: [
            _tile(
  icon: Icons.edit_outlined,
  text: _t('edit_profile', lang),
  onTap: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const EditProfileScreen(),
      ),
    );
  },
),

            _tile(
  icon: Icons.manage_accounts_outlined,
  text: _t('game_settings', lang),
  onTap: () {
    _showGameSettingsDialog(
      context,
      currentLanguage: language ?? 'english',
    );
  },
),

_tile(
  icon: Icons.emoji_events,
  text: _t('Achivements', lang),
  onTap: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AchievementsScreen(), // or _AchievementsScreen() if that's your class
      ),
    );
  },
),


            _tile(
              icon: Icons.lock_open_outlined,
              text: _t('permissions', lang),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PermissionsScreen(), // 👈 your new screen
                  ),
                );
              },
            ),
          ]),

          const SizedBox(height: 20),
          const _SectionLabel('Info'),
          _ThinList(dividerColor: kTileBorderColor, children: [
            _tile(
              icon: Icons.play_circle_outline,
              text: _t('how_to_play', lang),
              onTap: () {},
            ),
            _tile(
              icon: Icons.description_outlined,
              text: _t('terms_conditions', lang),
              onTap: () {
                _showLegalDialog(
                  context,
                  title: _t('terms_conditions', lang),
                  text: kTermsText,          // 👈 from privacy_policy_gate.dart
                );
              },
            ),
            _tile(
              icon: Icons.privacy_tip_outlined,
              text: _t('privacy_policy', lang),
              onTap: () {
                _showLegalDialog(
                  context,
                  title: _t('privacy_policy', lang),
                  text: kPrivacyPolicyText,  // 👈 from privacy_policy_gate.dart
                );
              },
            ),
          ]),

          const SizedBox(height: 20),
          const _SectionLabel('Danger Zone'),
          _ThinList(dividerColor: kTileBorderColor, children: [
            _tile(
              icon: Icons.logout,
              text: _t('logout', lang),
              isDestructive: true,
              onTap: () async {
                await FirebaseAuth.instance.signOut(); // AuthGate will handle navigation
              },
            ),
          ]),
        ],
      );
    }
    Widget screen;

    // No UID: fall back to Auth profile only
    if (uid == null) {
      final name =
      _user?.displayName?.trim().isNotEmpty == true ? _user!.displayName! : 'User';
      const fallbackLang = 'en';

      screen = Scaffold(
        appBar: buildAppBar(fallbackLang),
        body: _withBackground(
          content(
            username: name,
            avatarKey: null,
            language: fallbackLang,
          ),
        ),
      );

      return screen; // nothing to wrap, user isn't logged in
    }


    // With UID: stream from Firestore
    final future =
    FirebaseFirestore.instance.collection('users').doc(uid).get();

    screen = FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        debugPrint(
          'Settings snap: state=${snap.connectionState} '
              'hasData=${snap.hasData} exists=${snap.data?.exists}',
        );

        final fallbackName =
        _user?.displayName?.trim().isNotEmpty == true ? _user!.displayName! : 'User';

        // 1) Loading state – show spinner
        if (snap.connectionState == ConnectionState.waiting) {
          const fallbackLang = 'en';
          return Scaffold(
            appBar: buildAppBar(fallbackLang),
            body: _withBackground(
              const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        // 2) Error state
        if (snap.hasError) {
          debugPrint('Settings user snapshot error: ${snap.error}');
          const fallbackLang = 'en';
          return Scaffold(
            appBar: buildAppBar(fallbackLang),
            body: _withBackground(
              Center(
                child: Text(
                  'Error loading profile',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          );
        }

        // 3) Missing doc – fallback UI
        if (!snap.hasData || !snap.data!.exists) {
          debugPrint('Settings: doc really missing, using fallback UI');
          const fallbackLang = 'en';
          return Scaffold(
            appBar: buildAppBar(fallbackLang),
            body: _withBackground(
              content(
                username: fallbackName,
                avatarKey: null,
                language: fallbackLang,
              ),
            ),
          );
        }

        // 4) Normal data path
        final d = snap.data!.data()!;
        debugPrint('Settings user doc: $d');

        final avatarKey = d['avatar'] as String?;
        final name = (d['username'] as String?)?.trim().isNotEmpty == true
            ? d['username'] as String
            : fallbackName;

        final rawRank = d['globalRank'] ?? d['rank'];
        int? rank;
        if (rawRank is num) rank = rawRank.toInt();

        final rawIq = d['iq'];
        int? iq;
        if (rawIq is num) iq = rawIq.toInt();

        final league = (d['league'] as String?)?.trim();
        final language = (d['language'] as String?) ?? 'en';

        return _withBackground(
          Scaffold(
            backgroundColor: Colors.transparent,   // 👈 important
            appBar: buildAppBar(language),
            body: content(
              username: name,
              avatarKey: avatarKey,
              rank: rank,
              league: league,
              iq: iq,
              language: language,
            ),
          ),
        );

      },
    );



    // If we reach here, uid != null and we have a `screen` → wrap it
    return PrivacyPolicyGate(
      userId: uid!,
      child: screen,
    );
  }

      void _showGameSettingsDialog(
    BuildContext context, {
    required String currentLanguage,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color bg = isDark ? const Color(0xFF070B12) : theme.cardColor;
    final Color borderColor = isDark
        ? Colors.white.withOpacity(0.12)
        : Colors.black.withOpacity(0.08);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // (optional) title – localized as well
                Text(
                  _t('game_settings', currentLanguage),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),

                _GameSettingTile(
                  icon: Icons.volume_up_outlined,
                  label: _t('audio', currentLanguage),
                  onTap: () {
                    AudioController.toggleMuted();
                  },
                ),
                const SizedBox(height: 8),
                _GameSettingTile(
                  icon: Icons.language,
                  label: _t('language_label', currentLanguage),
                  trailing: Text(
                    _languageLabel(currentLanguage),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? Colors.white.withOpacity(0.85)
                          : const Color(0xFF1E2430),
                    ),
                  ),
                  onTap: () {
                    // close Game Settings, then open Language dialog
                    Navigator.of(ctx).pop();
                    _showLanguageDialog(context, currentLanguage);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLegalDialog(
      BuildContext context, {
        required String title,
        required String text,
      }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color dialogBg = isDark
        ? const Color(0xFF070B12)
        : theme.cardColor;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Center(
          child: Material(
            color: Colors.black.withOpacity(0.5), // backdrop
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: dialogBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                constraints: const BoxConstraints(
                  maxHeight: 600,
                  maxWidth: 600,
                ),
                child: Column(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Only ONE button: Back (same style as left/read button)
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text(
                          'Back',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }


  void _showLanguageDialog(BuildContext context, String currentLanguage) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color bg =
        isDark ? const Color(0xFF070B12) : theme.cardColor;
    final Color borderColor = isDark
        ? Colors.white.withOpacity(0.12)
        : Colors.black.withOpacity(0.08);

    final languages = <String>[
      'English',
      'Español',
      'Français',
      'Deutsch',
      'Português',
    ];

    // Helper: label -> code
    String _codeForLabel(String label) {
      switch (label) {
        case 'English':
          return 'en';
        case 'Español':
          return 'es';
        case 'Français':
          return 'fr';
        case 'Deutsch':
          return 'de';
        case 'Português':
          return 'pt';
        default:
          return 'en';
      }
    }

    final uid = _user?.uid;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _t('language_title', currentLanguage),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),

                for (final label in languages) ...[
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    title: Text(label),
                    onTap: () async {
                      if (uid != null) {
                        final code = _codeForLabel(label);
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .update({'language': code});
                      }

                      // Close language dialog
                      // also close game settings if still open
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(height: 4),
                ],

                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(_t('close', currentLanguage)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  static ListTile _tile({
    required IconData icon,
    required String text,
    VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : null),
      title: Text(
        text,
        style: TextStyle(
          color: isDestructive ? Colors.red : null,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      dense: true,
      visualDensity: const VisualDensity(horizontal: 0, vertical: -1),
    );
  }
}
const kTileBorderColor = Color(0xFF9CC8F5);

class _ThinList extends StatelessWidget {
  const _ThinList({
    super.key,
    required this.children,
    required this.dividerColor,
  });

  final List<Widget> children;
  final Color dividerColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B111B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: dividerColor, // outer border
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: i < children.length - 1
                      ? BorderSide(
                    color: dividerColor, // inner dividers
                    width: 0.6,
                  )
                      : BorderSide.none,
                ),
              ),
              child: children[i],
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: .2,
              color: isDark
                  ? Colors.white          // dark theme
                  : const Color(0xFF1E2430), // light theme (dark grey)
            ),
      ),
    );
  }
}


class _LeagueBadge extends StatefulWidget {
  const _LeagueBadge({
    required this.leagueKey,
    required this.assetPath,
    this.title,
  });

  final String? leagueKey;   // "bronze", "gold", etc.
  final String assetPath;    // e.g. assets/leagues/bronze.png
  final String? title;       // "Decent Brain", etc.

  @override
  State<_LeagueBadge> createState() => _LeagueBadgeState();
}

class _LeagueBadgeState extends State<_LeagueBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat(reverse: true); // pulse in/out
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Different glow strength / color per league
  (Color color, double minRadius, double maxRadius) _glowConfig() {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.primary;

    switch (widget.leagueKey?.toLowerCase()) {
      case 'iron':
        return (baseColor.withOpacity(0.7), 52, 64);
      case 'bronze':
        return (const Color(0xFFC77D3B), 56, 72);
      case 'silver':
        return (const Color(0xFFB0BEC5), 60, 80);
      case 'gold':
        return (const Color(0xFFFFD54F), 64, 88);
      case 'platinum':
        return (const Color(0xFF80DEEA), 68, 96);
      case 'diamond':
        return (const Color(0xFF81D4FA), 72, 104);
      case 'master':
        return (const Color(0xFFB388FF), 76, 112);
      default:
        return (baseColor.withOpacity(0.6), 56, 72);
    }
  }

  @override
Widget build(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final (glowColor, minR, maxR) = _glowConfig();
  final league = widget.leagueKey?.toLowerCase(); // 👈 we'll use this

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: maxR,
        height: maxR,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // 0..1 → pulse between minR and maxR
            final t = _controller.value;
            final radius = minR + (maxR - minR) * t;
            final opacity = 0.15 + 0.25 * t;

            // BASE GLOW
            final shadows = <BoxShadow>[
              BoxShadow(
                color: glowColor.withOpacity(opacity),
                blurRadius: radius,
                spreadRadius: radius * 0.20,
              ),
            ];

            // EXTRA WHITE GLOW FOR DIAMOND
            if (league == 'diamond') {
              shadows.add(
                BoxShadow(
                  color: Colors.white.withOpacity(opacity * 0.9),
                  blurRadius: radius * 1.1,
                  spreadRadius: radius * 0.28,
                ),
              );
            }

            // EXTRA GOLD GLOW FOR MASTER
            if (league == 'master') {
              shadows.add(
                BoxShadow(
                  color: const Color(0xFFFFD54F).withOpacity(opacity),
                  blurRadius: radius * 1.15,
                  spreadRadius: radius * 0.30,
                ),
              );
            }

            return Stack(
              alignment: Alignment.center,
              children: [
                // GLOW LAYER – uses `shadows` list
                Container(
                  width: radius,
                  height: radius,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: shadows,
                  ),
                ),

                // IMAGE LAYER
                SizedBox(
                  width: 165,
                  height: 165,
                  child: Image.asset(
                    widget.assetPath,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.shield_outlined, size: 40),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      if (widget.title != null) ...[
        const SizedBox(height: 6),
        Text(
          widget.title!,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark
                ? const Color.fromARGB(221, 255, 255, 255)
                : const Color(0xFF1E2430),
          ),
        ),
      ],
    ],
  );
}

}

class _LeagueStatRow extends StatelessWidget {
  const _LeagueStatRow({this.rank, this.iq});

  final int? rank; // e.g. global rank
  final int? iq;   // IQ from users doc

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Border is lighter than background; inner color is a bit darker.
    final borderColor = isDark
        ? Colors.white.withOpacity(0.12)
        : const Color(0xFF313847).withOpacity(0.16);

    final backgroundColor = isDark
        ? const Color(0xFF9CC8F5)
        : const Color(0xFFE8EDF4);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
  children: [
    // LEFT HALF: IQ, centered
    Expanded(
      child: Center(
        child: Text(
          iq != null ? '$iq IQ' : '-- IQ',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF111123),
          ),
        ),
      ),
    ),

    // MIDDLE: vertical divider exactly in the center
    Container(
      width: 1,
      height: 40,
      color: borderColor.withOpacity(isDark ? 0.6 : 0.5),
    ),

    // RIGHT HALF: #rank + trophy, centered
    Expanded(
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              rank != null ? '#${rank!}' : '#--',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111123),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 32,
              height: 32,
              child: Image.asset(
                'assets/images/brain_trophy.png',
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    ),
  ],
),

      ),
    );
  }
}

class _GameSettingTile extends StatelessWidget {
  const _GameSettingTile({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color bg = isDark
        ? Colors.white.withOpacity(0.04)
        : Colors.black.withOpacity(0.03);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isDark ? Colors.white : const Color(0xFF1E2430),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
