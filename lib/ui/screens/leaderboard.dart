import 'package:flutter/material.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

enum _Mode { globalCompetitive, regionalCompetitive, byLevel }

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  _Mode _mode = _Mode.globalCompetitive;
  int _level = 1;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final data = _generateEntries(_mode, _level);
    final meIndex = data.indexWhere((e) => e.name == 'You');
    final myRank = meIndex >= 0 ? meIndex + 1 : null;

    return Scaffold(
      appBar: AppBar(toolbarHeight: 0, elevation: 0, automaticallyImplyLeading: false),
      body: Column(
        children: [
          // ------- Header: Title ABOVE selectors -------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Leaderboard',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        )),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _ModeDropdown(
                        mode: _mode,
                        onChanged: (m) => setState(() => _mode = m),
                      ),
                    ),
                    if (_mode == _Mode.byLevel) ...[
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 130,
                        child: _LevelDropdown(
                          level: _level,
                          onChanged: (v) => setState(() => _level = v),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // ------- List -------
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemBuilder: (ctx, i) {
                final row = data[i];
                final isMe = row.name == 'You';

                return Container(
                  decoration: BoxDecoration(
                    color: isMe ? cs.primaryContainer : cs.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outlineVariant, width: 0.8),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isMe ? cs.primary : cs.primary.withOpacity(.15),
                      foregroundColor: isMe ? cs.onPrimary : cs.primary,
                      child:
                          Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    title: Text(
                      row.name,
                      style: TextStyle(
                        fontWeight: isMe ? FontWeight.w700 : FontWeight.w600,
                        color: isMe ? cs.onPrimaryContainer : cs.onSurface,
                      ),
                    ),
                    subtitle: Text('${row.points} pts'),
                    trailing: isMe ? Icon(Icons.person_outline, color: cs.primary) : null,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemCount: data.length,
            ),
          ),

          // ------- Your rank bar -------
          SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant, width: 0.8),
              ),
              child: Row(
                children: [
                  Icon(Icons.account_circle, color: cs.onSecondaryContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('You',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cs.onSecondaryContainer)),
                  ),
                  Text(
                    myRank != null ? '#$myRank' : '--',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: cs.onSecondaryContainer),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- mock data ----------
  List<_Entry> _generateEntries(_Mode mode, int level) {
    final modeBias = switch (mode) {
      _Mode.globalCompetitive => 0,
      _Mode.regionalCompetitive => 1,
      _Mode.byLevel => 2 + level,
    };
    final List<_Entry> rows = [];
    final base = 2400 + modeBias * 37;
    final step = 57 + modeBias * 3;
    for (int i = 0; i < 20; i++) {
      rows.add(_Entry('Player ${i + 1}', base - i * step));
    }
    final youIndex = 5 + (modeBias % 6);
    rows.insert(youIndex.clamp(0, rows.length), _Entry('You', base - youIndex * step - 12));
    return rows;
  }
}

class _Entry {
  final String name;
  final int points;
  _Entry(this.name, this.points);
}

// ---------- pretty dropdowns ----------

InputDecoration _outlined(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return InputDecoration(
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    filled: true,
    fillColor: cs.surface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: cs.outlineVariant, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: cs.primary, width: 1.2),
    ),
  );
}

class _ModeDropdown extends StatelessWidget {
  const _ModeDropdown({required this.mode, required this.onChanged});
  final _Mode mode;
  final ValueChanged<_Mode> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<_Mode>(
      value: mode,
      decoration: _outlined(context),
      icon: const Icon(Icons.arrow_drop_down),
      onChanged: (m) => onChanged(m ?? mode),
      items: const [
        DropdownMenuItem(value: _Mode.globalCompetitive, child: Text('Global Competitive')),
        DropdownMenuItem(value: _Mode.regionalCompetitive, child: Text('Regional Competitive')),
        DropdownMenuItem(value: _Mode.byLevel, child: Text('By Level')),
      ],
    );
  }
}

class _LevelDropdown extends StatelessWidget {
  const _LevelDropdown({required this.level, required this.onChanged});
  final int level;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      value: level,
      decoration: _outlined(context),
      icon: const Icon(Icons.arrow_drop_down),
      onChanged: (v) => onChanged(v ?? level),
      items: List.generate(
        10,
        (i) => DropdownMenuItem(value: i + 1, child: Text('Level ${i + 1}')),
      ),
    );
  }
}
