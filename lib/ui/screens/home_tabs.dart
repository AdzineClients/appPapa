import 'package:app_papa/ui/screens/shop.dart';
import 'package:flutter/material.dart';
import 'package:app_papa/ui/widgets/privacy_policy_gate.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'competition.dart';
import 'settings.dart';
import 'achivements.dart';
import 'leaderboard.dart';
import 'play.dart'; // adjust path if needed

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Start on Play (center)
  int _current = 2;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final user = FirebaseAuth.instance.currentUser;

    // If somehow no user is logged in, fall back to ungated pages
    if (user == null) {
      final pages = <Widget>[
        const CompetitionScreen(),    // 0
        const LeaderboardScreen(),    // 1
        const PlayScreen(),           // 2
        const ShopScreen(),           // 3
        const SettingsScreen(),       // 4
      ];

      return Scaffold(
        body: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() => _current = index);
          },
          children: pages,
        ),
        bottomNavigationBar: Container(
          height: 100,
          decoration: BoxDecoration(
            color: cs.surface,
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.6)
                    : Colors.black.withOpacity(0.12),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              IgnorePointer(
                ignoring: true,
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  alignment: Alignment(-1 + _current * 0.5, 0),
                  child: FractionallySizedBox(
                    widthFactor: 1 / 5,
                    heightFactor: 1.0,
                    child: Container(
                      margin: const EdgeInsets.symmetric(),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(
                          isDark ? 0.22 : 0.12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Theme(
                data: theme.copyWith(
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  splashFactory: NoSplash.splashFactory,
                ),
                child: BottomNavigationBar(
                  type: BottomNavigationBarType.fixed,
                  currentIndex: _current,
                  onTap: (i) {
                    setState(() => _current = i);
                    _pageController.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    );
                  },
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  showSelectedLabels: false,
                  showUnselectedLabels: false,
                  selectedItemColor: cs.primary,
                  unselectedItemColor: cs.onSurface.withOpacity(0.6),
                  items: [
                    BottomNavigationBarItem(
                      icon: _navIcon(
                        icon: Icons.sports_esports_outlined,
                        selected: _current == 0,
                      ),
                      label: '',
                    ),
                    BottomNavigationBarItem(
                      icon: _navIcon(
                        icon: Icons.leaderboard_outlined,
                        selected: _current == 1,
                      ),
                      label: '',
                    ),
                    BottomNavigationBarItem(
                      icon: _navIcon(
                        icon: Icons.play_circle_fill_rounded,
                        selected: _current == 2,
                      ),
                      label: '',
                    ),
                    BottomNavigationBarItem(
                      icon: _navIcon(
                        icon: Icons.shopping_bag_outlined,
                        selected: _current == 3,
                      ),
                      label: '',
                    ),
                    BottomNavigationBarItem(
                      icon: _navIcon(
                        icon: Icons.settings_outlined,
                        selected: _current == 4,
                      ),
                      label: '',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Logged-in user → gate all pages
    final userId = user.uid;

    Widget gate(Widget child) => PrivacyPolicyGate(
      userId: userId,
      child: child,
    );

    final pages = <Widget>[
      gate(const CompetitionScreen()),    // 0
      gate(const LeaderboardScreen()),    // 1
      gate(const PlayScreen()),           // 2
      gate(const ShopScreen()),           // 3
      gate(const SettingsScreen()),       // 4
    ];

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() => _current = index);
        },
        children: pages,
      ),
      bottomNavigationBar: Container(
        height: 100,
        decoration: BoxDecoration(
          color: cs.surface,
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.6)
                  : Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            IgnorePointer(
              ignoring: true,
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment: Alignment(-1 + _current * 0.5, 0),
                child: FractionallySizedBox(
                  widthFactor: 1 / 5,
                  heightFactor: 1.0,
                  child: Container(
                    margin: const EdgeInsets.symmetric(),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(
                        isDark ? 0.22 : 0.12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Theme(
              data: theme.copyWith(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
              ),
              child: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                currentIndex: _current,
                onTap: (i) {
                  setState(() => _current = i);
                  _pageController.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                  );
                },
                backgroundColor: Colors.transparent,
                elevation: 0,
                showSelectedLabels: false,
                showUnselectedLabels: false,
                selectedItemColor: cs.primary,
                unselectedItemColor: cs.onSurface.withOpacity(0.6),
                items: [
                  BottomNavigationBarItem(
                    icon: _navIcon(
                      icon: Icons.sports_esports_outlined,
                      selected: _current == 0,
                    ),
                    label: '',
                  ),
                  BottomNavigationBarItem(
                    icon: _navIcon(
                      icon: Icons.leaderboard_outlined,
                      selected: _current == 1,
                    ),
                    label: '',
                  ),
                  BottomNavigationBarItem(
                    icon: _navIcon(
                      icon: Icons.play_circle_fill_rounded,
                      selected: _current == 2,
                    ),
                    label: '',
                  ),
                  BottomNavigationBarItem(
                    icon: _navIcon(
                      icon: Icons.shopping_bag_outlined,
                      selected: _current == 3,
                    ),
                    label: '',
                  ),
                  BottomNavigationBarItem(
                    icon: _navIcon(
                      icon: Icons.settings_outlined,
                      selected: _current == 4,
                    ),
                    label: '',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navIcon({required IconData icon, required bool selected}) {
    final double size = selected ? 36 : 32; // grow a bit
    final double yOffset = selected ? -4 : 0; // move up a bit

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: Alignment.center,
      transform: Matrix4.translationValues(0, yOffset, 0),
      child: Icon(
        icon,
        size: size,
        // no explicit color -> inherits from BottomNavigationBar's
        // selectedItemColor / unselectedItemColor
      ),
    );
  }
}
