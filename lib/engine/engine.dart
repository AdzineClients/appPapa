// lib/engine/engine.dart
import 'actions.dart';
import 'level_config.dart';
import 'mirrors.dart';
import 'types.dart';

class GameEngine {
  final LevelConfig cfg;
  final List<GameAction> target;

  int _expectIdx = 0;

  // Mirror state toggles that affect how EXPECTED positions are interpreted.
  bool _mirrorX = false;
  bool _mirrorY = false;
  bool _mirrorDiag = false; // TL↘︎BR diagonal

  GameEngine({required this.cfg, required this.target});

  /// Emit each target action for demo playback.
  /// We also update internal mirror flags so subsequent expected positions
  /// are mirrored while the demo is running.
  Iterable<GameAction> playback() sync* {
    for (final a in target) {
      if (a.type == ActionType.mirrorBoard) {
        _applyMirrorToggle(a.axis);
      }
      yield a;
    }
  }

  /// Validate the next player action against the ordered target.
  /// Returns true when the player’s action matches the expected one (after
  /// applying the current mirror rules to the EXPECTED position).
  bool validate(GameAction player) {
    if (_expectIdx >= target.length) return false;

    // Skip over delays automatically
    while (_expectIdx < target.length &&
        target[_expectIdx].type == ActionType.delay) {
      _expectIdx++;
    }
    if (_expectIdx >= target.length) return false;

    final exp = target[_expectIdx];

    // Mirror toggles are rule steps: accept, update state, and advance.
    if (exp.type == ActionType.mirrorBoard) {
      _applyMirrorToggle(exp.axis);
      _expectIdx++;
      // After toggling, re-run validate on the same player action (if any).
      return validate(player);
    }

    final ok = _matches(exp, player);
    if (ok) _expectIdx++;
    return ok;
  }

  bool _matches(GameAction e, GameAction p) {
    if (e.type != p.type) return false;

    switch (e.type) {
      case ActionType.spawn:
        // Players don't spawn during recall in this engine.
        return false;

      case ActionType.move: {
        final ep = _mirrorPosIfNeeded(e.pos!);
        return p.instanceId == e.instanceId &&
               p.pos?.row == ep.row && p.pos?.col == ep.col;
      }

      case ActionType.rotate:
        return p.instanceId == e.instanceId &&
               (p.quarterTurns ?? 0) % 4 == (e.quarterTurns ?? 0) % 4;

      case ActionType.setColor:
        return p.instanceId == e.instanceId && p.color == e.color;

      case ActionType.playSound:
        return p.sound == e.sound;

      case ActionType.paintCell: {
        final ep = _mirrorPosIfNeeded(e.pos!);
        return p.pos?.row == ep.row &&
               p.pos?.col == ep.col &&
               p.color == e.color;
      }

      case ActionType.mirrorBoard:
        // Handled earlier (we never get here).
        return true;

      case ActionType.delay:
        // Handled by the skipping logic above.
        return true;
    }
  }

  /// Apply a mirror toggle from a.mirrorBoard step.
  void _applyMirrorToggle(String? axis) {
    switch (axis) {
      case 'x': _mirrorX = !_mirrorX; _mirrorY = false; _mirrorDiag = false; break;
      case 'y': _mirrorY = !_mirrorY; _mirrorX = false; _mirrorDiag = false; break;
      case 'd': _mirrorDiag = !_mirrorDiag; _mirrorX = false; _mirrorY = false; break;
      default: /* no-op */ break;
    }
  }

  /// Mirrors an EXPECTED position according to current mirror flags.
  GridPos _mirrorPosIfNeeded(GridPos pos) {
    var p = pos;
    if (_mirrorDiag) p = mirrorDiag(p, cfg.rows, cfg.cols);
    if (_mirrorX)   p = mirrorX(p,   cfg.rows, cfg.cols);
    if (_mirrorY)   p = mirrorY(p,   cfg.rows, cfg.cols);
    return p;
  }

  bool get isComplete => _expectIdx >= target.length;
}
