import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  late final ConfettiController _confetti;
  bool _confettiEnabled = true; // make this user-prefs driven later

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));

    // Play once after first frame so it triggers when user enters the screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_confettiEnabled) _confetti.play();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  void _replay() {
    if (!_confettiEnabled) return;
    _confetti.stop();
    _confetti.play();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
        actions: [
          IconButton(
            tooltip: 'Celebrate',
            icon: const Icon(Icons.celebration_outlined),
            onPressed: _replay,
          ),
          // Toggle (you can remove this later and drive it from Settings)
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 18),
              Switch(
                value: _confettiEnabled,
                onChanged: (v) {
                  setState(() => _confettiEnabled = v);
                  if (v) {
                    _replay();
                  } else {
                    _confetti.stop();
                  }
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),

      // 🔹 Same quilt background style as Settings
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/background2.png', // same bg as Settings
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              color: Colors.black.withOpacity(0.55),
              colorBlendMode: BlendMode.srcATop,
            ),
          ),

          // Foreground content (list + confetti), kept exactly as before
          SafeArea(
            child: Stack(
              children: [
                _body(), // your actual achievements content

                // Confetti overlay
                Align(
                  alignment: Alignment.topCenter,
                  child: ConfettiWidget(
                    confettiController: _confetti,
                    shouldLoop: false,
                    blastDirectionality: BlastDirectionality.explosive,
                    numberOfParticles: 30,
                    emissionFrequency: 0.05,
                    minBlastForce: 8,
                    maxBlastForce: 20,
                    gravity: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    final items = [
      ('First Login', true),
      ('Complete Tutorial', true),
      ('Win First Match', false),
      ('Share the App', false),
      ('7-Day Streak', false),
    ];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemBuilder: (ctx, i) {
        final (title, unlocked) = items[i];
        final t = Theme.of(ctx);
        final cs = t.colorScheme;

        // Themed colors
        final bg = unlocked ? cs.primaryContainer : cs.surface;
        final border = cs.outlineVariant; // thin border
        final iconCol = unlocked ? cs.primary : cs.outline;
        final textCol = unlocked
            ? cs.onPrimaryContainer
            : cs.onSurface.withOpacity(0.75);
        final trailing =
        unlocked ? Icon(Icons.check_circle_outline, color: cs.primary) : null;

        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border, width: 0.8),
          ),
          child: ListTile(
            leading: Icon(
              unlocked ? Icons.emoji_events : Icons.lock_outline,
              color: iconCol,
            ),
            title: Text(
              title,
              style: TextStyle(
                color: textCol,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: trailing,
            onTap: unlocked ? _replay : null, // replay confetti on unlocked tap
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: items.length,
    );
  }
}
