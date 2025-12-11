// lib/engine/generator.dart
import 'actions.dart';
import 'level_config.dart';
import 'rng.dart';
import 'state.dart';
import 'types.dart';

class SequenceGenerator {
  static List<GameAction> generate(LevelConfig cfg, {required int attempt}) {
    final seed = Rng.runSeed(baseSeed: cfg.seed, attemptIndex: attempt);
    final rng = Rng(seed);
    final actions = <GameAction>[];
    final board = BoardState(cfg.rows, cfg.cols);

    // --- Ensure at least one spawn ---
    String nextId() => String.fromCharCode(65 + board.items.length); // A,B,C...
    GridPos randCell() => GridPos(rng.nextInt(cfg.rows), rng.nextInt(cfg.cols));

    void spawnOne() {
      final id = nextId();
      final shape = rng.choice(cfg.shapePalette);
      var p = randCell();
      int guard = 0;
      while (board.occupied(p) && guard++ < 16) { p = randCell(); }
      board.items[id] = ShapeInstance(id: id, type: shape, pos: p);
      actions.add(GameAction.spawn(id, shape, p));
      if (cfg.enableColor && cfg.colorPalette.isNotEmpty && rng.chance(.8)) {
        final color = rng.choice(cfg.colorPalette);
        board.items[id]!.fill = color;
        actions.add(GameAction.setColor(id, color));
      }
      actions.add(GameAction.delay((cfg.playbackSpeedMs * 0.3).round()));
    }

    spawnOne();
    if ((cfg.rows * cfg.cols) >= 9 && rng.chance(.5)) spawnOne();

    // --- Build the rest of the sequence with constraints ---
    final allowed = <ActionType>[
      if (cfg.enableMove) ActionType.move,
      if (cfg.enableRotation) ActionType.rotate,
      if (cfg.enableColor && cfg.colorPalette.isNotEmpty) ActionType.setColor,
      if (cfg.enableColor && cfg.colorPalette.isNotEmpty) ActionType.paintCell, // ← NEW
      if (cfg.enableSound && cfg.soundPalette.isNotEmpty) ActionType.playSound,
    ];

    String pickItemId() => (board.items.keys.toList()..shuffle()).first;

    while (actions.where((a) => a.type != ActionType.delay).length < cfg.actionCount) {
      // occasional mirror (at most once)
      final hasMirror = actions.any((a) => a.type == ActionType.mirrorBoard);
      if (cfg.enableMirror && !hasMirror && rng.chance(0.12)) {
        // include diagonal sometimes
        final axis = rng.choice(<String>['x','y','d']);
        actions.add(GameAction.mirror(axis));
        actions.add(GameAction.delay((cfg.playbackSpeedMs * 0.4).round()));
        continue;
      }

      if (board.items.length < 3 && rng.chance(0.22)) {
        spawnOne();
        continue;
      }

      if (allowed.isEmpty) break;
      final type = rng.choice(allowed);
      final id = pickItemId();

      switch (type) {
        case ActionType.move:
          GridPos p = randCell();
          int guard = 0;
          while ((board.occupied(p) &&
                  !(board.items[id]!.pos.row == p.row && board.items[id]!.pos.col == p.col)) &&
                 guard++ < 16) { p = randCell(); }
          board.items[id]!.pos = p;
          actions.add(GameAction.move(id, p));
          break;

        case ActionType.rotate:
          final q = rng.choice(<int>[1, 1, 2, 3]);
          board.items[id]!.quarterTurns = (board.items[id]!.quarterTurns + q) % 4;
          actions.add(GameAction.rotate(id, q));
          break;

        case ActionType.setColor:
          final color = rng.choice(cfg.colorPalette);
          board.items[id]!.fill = color;
          actions.add(GameAction.setColor(id, color));
          break;

        case ActionType.playSound:
          final SoundId s = rng.choice(cfg.soundPalette) as SoundId;
          actions.add(GameAction.playSound(s));
          break;


        case ActionType.paintCell: // only used if you enable it above
          final p = randCell();
          final c = rng.choice(cfg.colorPalette);
          actions.add(GameAction.paintCell(p, c));
          break;

        // mirrorBoard and delay are injected separately; spawn not here.
        default: break;
      }

      actions.add(GameAction.delay((cfg.playbackSpeedMs * 0.25).round()));
    }

    return actions;
  }
}
