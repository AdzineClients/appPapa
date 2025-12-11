import 'package:flutter/material.dart';
import 'package:app_papa/ui/widgets/themed_auth_background.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:app_papa/ui/screens/gameScreen.dart';

Route _buildGameFadeRoute(int difficulty, Map<String, dynamic> currentGame) {
  return PageRouteBuilder(
    pageBuilder: (_, __, ___) => GameScreen(
      initialDifficulty: difficulty,
      initialGame: currentGame,
    ),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 300),
  );
}

class PlayScreen extends StatelessWidget {
  const PlayScreen({super.key});

  void _showDifficultySheet(
      BuildContext rootContext,
      Map<String, dynamic> userData,
      ) {
    showModalBottomSheet(
      context: rootContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final cs = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;

        // 🔒 Unlock flags from Firestore (adjust fields as you like)
        final easyUnlocked       = userData['unlockedEasy']       as bool? ?? true;
        final mediumUnlocked     = userData['unlockedMedium']     as bool? ?? true;
        final hardUnlocked       = userData['unlockedHard']       as bool? ?? false;
        final expertUnlocked     = userData['unlockedExpert']     as bool? ?? false;
        final masterUnlocked     = userData['unlockedMaster']     as bool? ?? false;
        final extremeUnlocked    = userData['unlockedExtreme']    as bool? ?? false;
        final impossibleUnlocked = userData['unlockedImpossible'] as bool? ?? false;

        final difficulties = <_Difficulty>[
          _Difficulty(
            id: 'easy',
            label: 'Easy',
            stars: 1,
            color: Colors.green,
            unlocked: easyUnlocked,
          ),
          _Difficulty(
            id: 'medium',
            label: 'Medium',
            stars: 2,
            color: Colors.amber,
            unlocked: mediumUnlocked,
          ),
          _Difficulty(
            id: 'hard',
            label: 'Hard',
            stars: 3,
            color: Colors.red,
            unlocked: hardUnlocked,
            subtitle: 'Complete 2 medium levels to unlock',
          ),
          _Difficulty(
            id: 'expert',
            label: 'Expert',
            stars: 4,
            color: Colors.purple,
            unlocked: expertUnlocked,
            subtitle: 'Complete 4 hard levels to unlock',
          ),
          _Difficulty(
            id: 'master',
            label: 'Master',
            stars: 5,
            color: Colors.lightBlue,
            unlocked: masterUnlocked,
            subtitle: 'Complete 10 expert levels to unlock',
          ),
          _Difficulty(
            id: 'extreme',
            label: 'Extreme',
            stars: 6,
            color: Colors.grey.shade800,
            unlocked: extremeUnlocked,
            subtitle: 'Complete 14 master levels to unlock',
          ),
          _Difficulty(
            id: 'impossible',
            label: 'Impossible',
            stars: 7,
            color: Colors.black,
            unlocked: impossibleUnlocked,
            subtitle: 'Only for legends.',
          ),
        ];

        return FractionallySizedBox(
          heightFactor: 0.7,
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.6 : 0.25),
                  blurRadius: 30,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // little drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select difficulty',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: difficulties.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final diff = difficulties[index];
                      return _buildDifficultyCard(rootContext, diff); // 👈 use rootContext
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDifficultyCard(BuildContext rootContext, _Difficulty diff) {
    final base = diff.color;
    final bool unlocked = diff.unlocked;

    return Opacity(
      opacity: unlocked ? 1.0 : 0.45,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: unlocked
            ? () {
          // 1) Close the difficulty bottom sheet
          Navigator.of(rootContext).pop();

          // 2) Immediately push a blank loading screen (fade)
          Navigator.of(rootContext).push(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => GameLaunchScreen(
                diff: diff,
                rootContext: rootContext,
              ),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 250),
            ),
          );
        }
            : () {
          ScaffoldMessenger.of(rootContext).showSnackBar(
            const SnackBar(
              content: Text('This difficulty is locked.'),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                base.withOpacity(0.95),
                base.withOpacity(0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              // left: label + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      diff.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (diff.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        diff.subtitle!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // right: stars + lock
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: List.generate(7, (index) {
                      final filled = index < diff.stars;
                      return Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Icon(
                          Icons.star_rounded,
                          size: 18,
                          color: filled
                              ? Colors.white
                              : Colors.white.withOpacity(0.25),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(width: 8),
                  if (!unlocked)
                    Icon(
                      Icons.lock_outline,
                      color: Colors.white.withOpacity(0.95),
                      size: 20,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = cs.primary;
    final isDark = theme.brightness == Brightness.dark;
    const double modeCardHeight = 250; // shared height for both rectangles

    final user = FirebaseAuth.instance.currentUser;

    // Fallback if somehow not logged in
    if (user == null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Not signed in',
            style: TextStyle(color: cs.onBackground),
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? {};
        // Safely read numeric fields (default to 0)
        final int iq          = (data['iq'] as num?)?.toInt() ?? 0;
        final int coins       = (data['coins'] as num?)?.toInt() ?? 0;
        final int intyCards   = (data['intyCards'] as num?)?.toInt() ?? 0;
        final int replayCards = (data['replayCards'] as num?)?.toInt() ?? 0;
        final int skipCards   = (data['skipCards'] as num?)?.toInt() ?? 0;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            title: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _StatItem(
                      value: coins.toString(),
                      assetPath: 'assets/images/coin.png',
                      color: Colors.amber, // coins color
                    ),
                  ),
                  Expanded(
                    child: _StatItem(
                      value: intyCards.toString(),
                      assetPath: 'assets/images/inmmunityCard.png',
                      color: Colors.deepPurpleAccent, // immunity cards
                    ),
                  ),
                  Expanded(
                    child: _StatItem(
                      value: replayCards.toString(),
                      assetPath: 'assets/images/replayCard.png',
                      color: Colors.lightBlueAccent, // replay
                    ),
                  ),
                  Expanded(
                    child: _StatItem(
                      value: skipCards.toString(),
                      assetPath: 'assets/images/skipCard.png',
                      color: Colors.redAccent, // skip
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: ThemedAuthBackground(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 🔹 TOP BIG GRADIENT RECTANGLE
                    SizedBox(
                      height: modeCardHeight,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              accent.withOpacity(isDark ? 0.95 : 0.9),
                              accent.withOpacity(isDark ? 0.75 : 0.6),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withOpacity(isDark ? 0.4 : 0.25),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _ModeColumn(
                                title: 'Daily Challenges',
                                description: 'December 6th',
                                accentOnPrimary: cs.onPrimary,
                                topVisual: Image.asset(
                                  'assets/images/calendarIcon.png',
                                  fit: BoxFit.contain,
                                ),
                                rewardText: 'x15',
                                rewardIcon: Image.asset(
                                  'assets/images/coin.png',
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.contain,
                                ),
                                buttonText: 'Play',
                                onPressed: () {
                                  // TODO: open Daily Challenges
                                },
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 140,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              color: cs.onPrimary.withOpacity(0.3),
                            ),
                            Expanded(
                              child: _ModeColumn(
                                title: 'Multiplayer',
                                description: 'Try multiplayer mode.',
                                accentOnPrimary: cs.onPrimary,
                                topVisual: Image.asset(
                                  'assets/images/gameIcon.png',
                                  fit: BoxFit.contain,
                                ),
                                rewardText: 'x15',
                                rewardIcon: Image.asset(
                                  'assets/images/coin.png',
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.contain,
                                ),
                                buttonText: 'Play',
                                onPressed: () {
                                  // TODO: open Multiplayer
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 🔹 MIDDLE IQ CARD + BOTTOM BUTTONS
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(),

                      // IQ rectangle centered between top card and buttons
                      SizedBox(
                        height: modeCardHeight,
                        child: Center(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 18,
                              horizontal: 24,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: isDark
                                    ? [
                                  const Color(0xFF658DAA).withOpacity(0.98),
                                  const Color(0xFF90CAF9).withOpacity(0.80),
                                ]
                                    : [
                                  const Color(0xFFB9D8FF).withOpacity(0.98),
                                  const Color(0xFF90CAF9).withOpacity(0.85),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withOpacity(isDark ? 0.55 : 0.35),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                'IQ | $iq',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 80,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onBackground
                                      .withOpacity(0.75),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const Spacer(),

                      // 🔹 NEW: Multiplayer button (replaces Continue Game)
                      SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: () {
                            // TODO: hook up to Multiplayer screen when ready
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Multiplayer coming soon.'),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: accent,
                              width: 1.6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            backgroundColor: isDark
                                ? theme.scaffoldBackgroundColor
                                : Colors.white,
                            foregroundColor: accent,
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ).copyWith(
                            elevation: MaterialStateProperty.all(6),
                            shadowColor: MaterialStateProperty.all(
                              accent.withOpacity(0.4),
                            ),
                          ),
                          child: const Text('Multiplayer'),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // New Game button (unchanged)
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            _showDifficultySheet(context, data);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: cs.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 6,
                            shadowColor: accent.withOpacity(0.6),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          child: const Text('New Game'),
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
        );
      },
    );
  }
}

class _ModeColumn extends StatelessWidget {
  final String title;
  final String description;
  final Color accentOnPrimary;

  final Widget topVisual;
  final String rewardText;
  final Widget rewardIcon;
  final String buttonText;
  final VoidCallback onPressed;

  const _ModeColumn({
    required this.title,
    required this.description,
    required this.accentOnPrimary,
    required this.topVisual,
    required this.rewardText,
    required this.rewardIcon,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Top image / icon
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(child: topVisual),
        ),
        const SizedBox(height: 8),

        // Title
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: accentOnPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),

        // Description
        Text(
          description,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: accentOnPrimary.withOpacity(0.85),
            fontWeight: FontWeight.w400,
            fontSize: 12,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),

        // Reward row: "x15" + coin (or anything else)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              rewardText,
              style: TextStyle(
                color: accentOnPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            const SizedBox(width: 6),
            rewardIcon,
          ],
        ),
        const SizedBox(height: 8),

        // Play button (wide, slightly de-rounded)
        SizedBox(
          width: double.infinity,
          height: 40,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              shadowColor: Colors.black.withOpacity(0.35),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(buttonText),
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String assetPath;
  final Color color;

  const _StatItem({
    required this.value,
    required this.assetPath,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 45,
          height: 45,
          child: Image.asset(
            assetPath,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
}

class _Difficulty {
  final String id;        // e.g. 'easy'
  final String label;     // 'Easy'
  final int stars;        // 1–7
  final Color color;      // base color
  final bool unlocked;
  final String? subtitle; // optional unlock text

  const _Difficulty({
    required this.id,
    required this.label,
    required this.stars,
    required this.color,
    required this.unlocked,
    this.subtitle,
  });
}

class GameLaunchScreen extends StatefulWidget {
  final _Difficulty diff;
  final BuildContext rootContext; // PlayScreen context for SnackBars

  const GameLaunchScreen({
    super.key,
    required this.diff,
    required this.rootContext,
  });

  @override
  State<GameLaunchScreen> createState() => _GameLaunchScreenState();
}

class _GameLaunchScreenState extends State<GameLaunchScreen> {
  @override
  void initState() {
    super.initState();
    _startGame();
  }

  Future<void> _startGame() async {
    final functions = FirebaseFunctions.instanceFor(region: 'us-central1');

    try {
      final callable = functions.httpsCallable('startNewGame');
      final result = await callable.call(<String, dynamic>{
        'difficulty': widget.diff.id,
      });

      // Defensive parsing (same as before)
      final raw = result.data;
      if (raw is! Map) {
        if (!mounted) return;
        Navigator.of(context).pop(); // back to PlayScreen
        ScaffoldMessenger.of(widget.rootContext).showSnackBar(
          const SnackBar(content: Text('Unexpected server response.')),
        );
        return;
      }

      final data = raw.cast<String, dynamic>();
      final ok = data['ok'] == true;
      final cgRaw = data['currentGame'];

      if (!ok || cgRaw is! Map) {
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(widget.rootContext).showSnackBar(
          const SnackBar(content: Text('Could not start game. Please try again.')),
        );
        return;
      }

      final currentGame = cgRaw.cast<String, dynamic>();

      if (!mounted) return;

      // 🔹 Replace the blank screen with the actual GameScreen (fade)
      Navigator.of(context).pushReplacement(
        _buildGameFadeRoute(widget.diff.stars, currentGame),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(widget.rootContext).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Failed to start game')),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(widget.rootContext).showSnackBar(
        const SnackBar(content: Text('Unexpected error starting game')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Totally blank screen matching theme background
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: const SizedBox.expand(),
    );
  }
}

