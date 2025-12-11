import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

// Engine + data
import 'package:app_papa/engine/level_config.dart';
import 'package:app_papa/engine/types.dart';
import 'package:app_papa/engine/engine.dart';
import 'package:app_papa/engine/actions.dart';
import 'package:app_papa/engine/generator.dart';
import 'package:app_papa/data/sources/local_levels_source.dart';
import 'package:app_papa/data/repositories/level_repository_impl.dart';
import 'package:app_papa/ui/widgets/themed_auth_background.dart';

const List<ColorId> kAllColors = [
  ColorId.red,
  ColorId.green,
  ColorId.blue,
  ColorId.orange,
  ColorId.pink,
  ColorId.purple,
  // whatever you actually use
];

const List<ShapeType> kAllShapes = [
  ShapeType.square,
  ShapeType.rectangle,
  ShapeType.circle,
  ShapeType.triangle,
  ShapeType.squareOutline,
  ShapeType.rectangleOutline,
  ShapeType.circleOutline,
  ShapeType.triangleOutline,
];

const List<SoundId> kAllSounds = [
  SoundId.drums,
  SoundId.guitar,
  SoundId.flute,
  SoundId.piano,
];


class _Piece {
  _Piece({
    required this.id,
    required this.shape,
    required this.pos,
    this.color,
    this.qTurns = 0,
  });

  final String id;
  ShapeType shape;
  GridPos pos;
  ColorId? color;
  int qTurns; // 0,1,2,3 quarter turns
}

Color _mapColor(ColorId c, ColorScheme cs) {
  switch (c) {
    case ColorId.red:     return Colors.red;
    case ColorId.blue:    return const Color(0xFF2196F3);
    case ColorId.green:   return Colors.green;
    case ColorId.yellow:  return Colors.amber;
    case ColorId.purple:  return Colors.purple;
    case ColorId.orange:  return Colors.orange;
    case ColorId.ligthBlue: return Colors.lightBlueAccent;
    case ColorId.pink: return Colors.pinkAccent;
  }
}

Color _renderPieceColor(ColorId? color, ColorScheme cs) {
  if (color == null) return Colors.grey;
  return _mapColor(color, cs);
}

class GameScreen extends StatefulWidget {
  /// difficulty from PlayScreen / cloud function (1–7)
  final int initialDifficulty;

  /// Optional state from currentGame (for Continue Game)
  final Map<String, dynamic>? initialGame;

  const GameScreen({
    super.key,
    required this.initialDifficulty,
    this.initialGame,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();  // 👈 ADD THIS
}

class _GameScreenState extends State<GameScreen> {

  // NEW: multi-sequence support
  int _sequenceCount = 1;                // 1, 2, or 3 depending on difficulty
  int _currentSequenceIndex = 0;         // 0-based: which sequence we're on
  List<int> _sequenceStepCounts = [];
  int _incorrects = 0;
  int _currentMove = 0;     // how many user moves have been attempted
  int _elapsedSeconds = 0;  // total seconds the game has been “running”
  Timer? _timer;// cumulative user steps per sequence
  bool _hasRisked = false;          // user tapped "Continue playing" at least once
  bool _reachedFirstDouble = false; // has hit the 2× threshold
  bool _hasFinishedRun = false;
  // Countdown overlay before first demo
  bool _showCountdown = false;
  int _countdownValue = 3;
// guard against double finishGame calls

  // 🔹 End-of-run overlay state
  bool _showEndOverlay = false;          // whole overlay visible
  bool _endTitleVisible = true;          // blinking "You Won/Lost"
  bool _endIsWin = true;                 // true => "You Won", false => "You Lost"
  bool _showEndResultsSheet = false;     // bottom sheet slid in

  int _endIqTarget = 0;                  // final IQ to show
  int _endIqDisplay = 0;                 // animated counting IQ

  int _endCoinsReward = 0;
  int _endIntyReward = 0;
  int _endSkipReward = 0;
  int _endReplayReward = 0;

  int _endRewardRevealCount = 0;         // how many reward tiles are “on”
  Timer? _iqCounterTimer;

  int _movesAtFirstWin = 0;         // _currentMove value at first full level win
  static const int _movesForFirstDouble = 5;

  bool _isUserAction(GameAction a) {
    switch (a.type) {
      case ActionType.spawn:
      case ActionType.move:
      case ActionType.setColor:
      case ActionType.rotate:
      case ActionType.mirrorBoard:
      case ActionType.paintCell:
      case ActionType.playSound:
        return true;
      case ActionType.delay:
        return false;
    }
  }

  Future<void> _startInitialCountdownAndSequence() async {
    if (_engine == null || _sequenceStepCounts.isEmpty) return;

    setState(() {
      _showCountdown = true;
      _countdownValue = 3;
    });

    // 3 → 2 → 1 (one second each)
    for (int v = 3; v >= 1; v--) {
      if (!mounted) return;
      setState(() {
        _countdownValue = v;
      });
      await Future.delayed(const Duration(seconds: 1));
    }

    // 🔹 Hide overlay *before* the extra second
    if (!mounted) return;
    setState(() {
      _showCountdown = false;
    });

    // 🔹 Extra 1 second pause with NO overlay
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    // Now actually start the first sequence
    await _startSequence(0);
  }

  Future<void> _runWinLoseBlink() async {
    for (int i = 0; i < 2; i++) {
      if (!mounted || !_showEndOverlay) return;
      setState(() => _endTitleVisible = true);
      await Future.delayed(const Duration(milliseconds: 250));

      if (!mounted || !_showEndOverlay) return;
      setState(() => _endTitleVisible = false);
      await Future.delayed(const Duration(milliseconds: 180));
    }

    if (!mounted || !_showEndOverlay) return;
    setState(() => _endTitleVisible = true); // end visible
  }

// 🔸 IQ count-up
  void _startIqCountUp() {
    _iqCounterTimer?.cancel();
    _endIqDisplay = 0;

    final target = _endIqTarget;
    if (target <= 0) {
      setState(() {});
      return;
    }

    const totalMs = 900;
    const tickMs = 40;
    final steps = (totalMs / tickMs).ceil();
    final double increment = target / steps;
    double current = 0;
    int ticks = 0;

    _iqCounterTimer = Timer.periodic(
      const Duration(milliseconds: tickMs),
          (timer) {
        if (!mounted || !_showEndOverlay) {
          timer.cancel();
          return;
        }
        ticks++;
        current += increment;

        if (ticks >= steps) {
          _endIqDisplay = target;
          setState(() {});
          timer.cancel();
        } else {
          setState(() {
            _endIqDisplay = current.round();
          });
        }
      },
    );
  }
  List<GameAction> _extendTargetRandom(
      LevelConfig cfg,
      List<GameAction> base, {
        required int extraUserSteps,
      }) {
    // Use a seed derived from base length so the extension is stable-ish but still random.
    final r = Random(cfg.seed ^ (base.length * 104729));

    final actions = List<GameAction>.from(base);

    // Reconstruct board-tracking info from the existing script.
    final ids = <String>{};
    final lastPos = <String, GridPos>{};
    final pieceColors = <String, ColorId?>{};
    final cellColors = <String, ColorId>{};

    String cellKey(GridPos p) => '${p.row}:${p.col}';

    for (final a in base) {
      switch (a.type) {
        case ActionType.spawn:
          if (a.instanceId != null && a.pos != null) {
            ids.add(a.instanceId!);
            lastPos[a.instanceId!] = a.pos!;
            pieceColors[a.instanceId!] = null; // will be overwritten by setColor
          }
          break;

        case ActionType.move:
          if (a.instanceId != null && a.pos != null) {
            lastPos[a.instanceId!] = a.pos!;
          }
          break;

        case ActionType.setColor:
          if (a.instanceId != null && a.color != null) {
            pieceColors[a.instanceId!] = a.color;
          }
          break;

        case ActionType.paintCell:
          if (a.pos != null && a.color != null) {
            cellColors[cellKey(a.pos!)] = a.color!;
          }
          break;
        case ActionType.mirrorBoard:
          if (a.axis == 'x') {
            // horizontal
            lastPos.updateAll(
                  (id, pos) => GridPos(cfg.rows - 1 - pos.row, pos.col),
            );

            final next = <String, ColorId>{};
            cellColors.forEach((key, value) {
              final parts = key.split(':');
              final rr = int.parse(parts[0]);
              final cc = int.parse(parts[1]);
              final m = GridPos(cfg.rows - 1 - rr, cc);
              next['${m.row}:${m.col}'] = value;
            });
            cellColors
              ..clear()
              ..addAll(next);
          } else if (a.axis == 'y') {
            // vertical
            lastPos.updateAll(
                  (id, pos) => GridPos(pos.row, cfg.cols - 1 - pos.col),
            );

            final next = <String, ColorId>{};
            cellColors.forEach((key, value) {
              final parts = key.split(':');
              final rr = int.parse(parts[0]);
              final cc = int.parse(parts[1]);
              final m = GridPos(rr, cfg.cols - 1 - cc);
              next['${m.row}:${m.col}'] = value;
            });
            cellColors
              ..clear()
              ..addAll(next);
          }
          break;


        default:
        // rotate / mirror / delay / sound don't change our tracked state here
          break;
      }
    }

    if (ids.isEmpty) {
      // Should never happen because genRandomTarget always spawns at least 1 piece,
      // but guard just in case.
      return actions;
    }

    // Build allowed kinds exactly like genRandomTarget.
    final allowedKinds = <String>[];
    if (cfg.enableColor)    allowedKinds.addAll(['color', 'paint']);
    if (cfg.enableMove)     allowedKinds.add('move');
    if (cfg.enableRotation) allowedKinds.add('rot');
    if (cfg.enableMirror)   allowedKinds.add('mirror');
    if (cfg.enableSound && cfg.soundPalette.isNotEmpty) {
      allowedKinds.add('sound');
    }

    int addedUserSteps = 0;
    final idsList = ids.toList();

    while (addedUserSteps < extraUserSteps &&
        allowedKinds.isNotEmpty &&
        idsList.isNotEmpty) {
      final id = idsList[r.nextInt(idsList.length)];
      final kind = allowedKinds[r.nextInt(allowedKinds.length)];

      switch (kind) {
        case 'color': {
          final currentColor = pieceColors[id];

          final availableColors = cfg.colorPalette
              .where((c) => c != currentColor)
              .toList();

          if (availableColors.isEmpty) {
            // No non-redundant color for this piece right now.
            continue;
          }

          final c = availableColors[r.nextInt(availableColors.length)];
          actions.add(GameAction.setColor(id, c));
          pieceColors[id] = c;
          addedUserSteps++;
          break;
        }


        case 'move': {
          final from = lastPos[id] ?? GridPos(
            r.nextInt(cfg.rows),
            r.nextInt(cfg.cols),
          );
          GridPos to;
          do {
            to = GridPos(r.nextInt(cfg.rows), r.nextInt(cfg.cols));
          } while (to == from);
          lastPos[id] = to;
          actions.add(GameAction.move(id, to));
          addedUserSteps++;
          break;
        }

        case 'rot': {
          final pos = lastPos[id];
          if (pos != null) {
            final pc = pieceColors[id];
            final cc = cellColors[cellKey(pos)];
            final blocked = pc != null && cc != null && pc == cc;
            if (blocked) {
              // Same rule as genRandomTarget: skip this rotate if blocked
              continue;
            }
          }
          final qTurns = r.nextBool() ? 1 : 3;
          actions.add(GameAction.rotate(id, qTurns));
          addedUserSteps++;
          break;
        }

        case 'mirror': {
          final axis = r.nextBool() ? 'x' : 'y';
          actions.add(GameAction.mirror(axis));

          // 🔹 Keep lastPos + cellColors consistent
          if (axis == 'x') {
            lastPos.updateAll(
                  (id, pos) => GridPos(cfg.rows - 1 - pos.row, pos.col),
            );

            final next = <String, ColorId>{};
            cellColors.forEach((key, value) {
              final parts = key.split(':');
              final rr = int.parse(parts[0]);
              final cc = int.parse(parts[1]);
              final m = GridPos(cfg.rows - 1 - rr, cc);
              next['${m.row}:${m.col}'] = value;
            });
            cellColors
              ..clear()
              ..addAll(next);
          } else {
            lastPos.updateAll(
                  (id, pos) => GridPos(pos.row, cfg.cols - 1 - pos.col),
            );

            final next = <String, ColorId>{};
            cellColors.forEach((key, value) {
              final parts = key.split(':');
              final rr = int.parse(parts[0]);
              final cc = int.parse(parts[1]);
              final m = GridPos(rr, cfg.cols - 1 - cc);
              next['${m.row}:${m.col}'] = value;
            });
            cellColors
              ..clear()
              ..addAll(next);
          }

          addedUserSteps++;
          break;
        }

        case 'paint': {
          const int maxAttempts = 10;
          GridPos pos;
          ColorId c;
          int attempts = 0;

          while (true) {
            pos = GridPos(r.nextInt(cfg.rows), r.nextInt(cfg.cols));
            c = cfg.colorPalette[r.nextInt(cfg.colorPalette.length)];
            attempts++;

            final existing = cellColors[cellKey(pos)];
            if (existing == null || existing != c) break;

            if (attempts >= maxAttempts) {
              pos = GridPos(0, 0); // dummy
              break;
            }
          }

          final existing = cellColors[cellKey(pos)];
          if (existing != null && existing == c) {
            // Still redundant; skip this paint action
            continue;
          }

          cellColors[cellKey(pos)] = c;
          actions.add(GameAction.paintCell(pos, c));
          addedUserSteps++;
          break;
        }


        case 'sound': {
          final s = cfg.soundPalette[r.nextInt(cfg.soundPalette.length)];
          actions.add(GameAction.playSound(s));
          addedUserSteps++;
          break;
        }
      }
    }

    return actions;
  }

  LevelConfig _upgradeConfigForRisk(int newDifficulty) {
    // We base upgrades on the *current* config of this run
    final currentCfg = _engine!.cfg;

    final profile =
        kDifficultyProfiles[newDifficulty] ?? kDifficultyProfiles[1]!;

    final r = Random(DateTime.now().millisecondsSinceEpoch);

    List<T> growList<T>(
        List<T> current,
        List<T> universe,
        int max,
        ) {
      if (max <= 0) return const [];

      // Start with what we already have
      final result = List<T>.from(current);

      // If current has MORE than the allowed max, just truncate (keeps old ones)
      if (result.length > max) {
        return result.sublist(0, max);
      }

      // Otherwise, add new unique items from the universe
      final candidates =
      universe.where((x) => !result.contains(x)).toList()..shuffle(r);

      while (result.length < max && candidates.isNotEmpty) {
        result.add(candidates.removeLast());
      }

      return result;
    }

    // Full universe of options
    final allShapes = ShapeType.values.toList();
    final allColors = ColorId.values.toList();
    final allSounds = SoundId.values.toList();

    final newShapes =
    growList(currentCfg.shapePalette, allShapes, profile.maxShapes);
    final newColors =
    growList(currentCfg.colorPalette, allColors, profile.maxColors);
    final newSounds =
    growList(currentCfg.soundPalette, allSounds, profile.maxSounds);

    return LevelConfig(
      worldId: currentCfg.worldId,
      levelId: 'D$newDifficulty',
      rows: profile.rows,
      cols: profile.cols,
      shapePalette: newShapes,
      colorPalette: newColors,
      soundPalette: newSounds,
      actionCount: profile.actionCount,
      playbackSpeedMs: profile.demoStepMs,
      allowedMistakes: profile.allowedMistakes,
      enableRotation: profile.enableRotation,
      enableMove: profile.enableMove,
      enableColor: profile.enableColor,
      enableSound: profile.enableSound,
      enableMirror: profile.enableMirror,
      hideAfterMs: profile.hideAfterMs,
      seed: DateTime.now().millisecondsSinceEpoch,
    );
  }

  _DifficultyVisual _difficultyVisualFor(int difficulty) {
    // Clamp 1–7
    final d = difficulty.clamp(1, 7);
    final fraction = d / 7.0; // 1/7 ≈ 14.3% for Easy

    switch (d) {
      case 1:
        return _DifficultyVisual('Easy', Colors.green, fraction);
      case 2:
        return _DifficultyVisual('Medium', Colors.amber, fraction);
      case 3:
        return _DifficultyVisual('Hard', Colors.red, fraction);
      case 4:
        return _DifficultyVisual('Expert', Colors.purple, fraction);
      case 5:
        return _DifficultyVisual('Master', Colors.lightBlue, fraction);
      case 6:
        return _DifficultyVisual('Extreme', Colors.grey.shade800, fraction);
      case 7:
      default:
        return _DifficultyVisual('Impossible', Colors.black, fraction);
    }
  }

  Future<void> _extendRunWithMoreSteps() async {
    if (_engine == null || _target.isEmpty) {
      await _startWithDifficulty(_difficulty);
      return;
    }

    // 2) Build an upgraded config for the *new* difficulty,
    //    based on the current config's palettes.
    final upgradedCfg = _upgradeConfigForRisk(_difficulty);

    // 3) Extend the existing script using the upgraded capabilities
    final extended = _extendTargetRandom(
      upgradedCfg,
      _target,
      extraUserSteps: _extraUserStepsPerContinue,
    );

    final totalUserSteps = extended.where(_isUserAction).length;

    setState(() {
      _target = extended;
      _engine = GameEngine(cfg: upgradedCfg, target: extended);

      // Palettes now match the upgraded config
      _availableShapes = List<ShapeType>.from(upgradedCfg.shapePalette);
      _availableColors = List<ColorId>.from(upgradedCfg.colorPalette);
      _availableSounds = List<SoundId>.from(upgradedCfg.soundPalette);

      _goal.clear();
      _steps.clear();
      _stepIndex = 0;
      _demoToUserId.clear();
      _pieces.clear();
      _cellColors.clear();
      _selectedId = null;
      _completed = false;
      _playedDemo = false;

      // For the extended run, single combined sequence
      _sequenceCount = 1;
      _currentSequenceIndex = 0;
      _sequenceStepCounts = [totalUserSteps];
    });

    // 4) Play the whole script as a single demo
    await _startSequence(0);
  }

  int _sequenceCountForDifficulty(int d) {
    if (d <= 2) return 1;     // Easy / Medium
    if (d <= 4) return 2;     // Hard-ish
    return 3;                 // 5–7: advanced
  }

  int get _maxMistakesForCurrentDifficulty {
    // Prefer the live engine cfg if we already built it
    final cfg = _engine?.cfg;
    if (cfg != null && cfg.allowedMistakes > 0) {
      return cfg.allowedMistakes;
    }

    // Fallback: read from DifficultyProfile map
    final profile = kDifficultyProfiles[_difficulty];
    if (profile != null && profile.allowedMistakes > 0) {
      return profile.allowedMistakes;
    }

    // Sensible default if something is missing
    return 3;
  }



  late final AudioPlayer _sfx;
  bool _posEq(GridPos? a, int r, int c) => a != null && a.row == r && a.col == c;
  bool _expect(ActionType t) {
    if (!_enforceOrder || _steps.isEmpty) return true;
    if (_stepIndex >= _steps.length) return false;
    return _steps[_stepIndex].type == t;
  }
  List<ShapeType> _availableShapes = [];
  final bool _enforceOrder = true;
  int _userSpawnCounter = 1;
  String _nextUserId() => 'U${_userSpawnCounter++}';
  final Map<String, _Piece> _pieces = {};
  List<ColorId> _availableColors = [];
  final _repo = LevelRepository(LocalLevelsSource());
  GameEngine? _engine;
  List<GameAction> _target = [];
  LevelConfig? _baseConfig;
  final List<String> _log = [];
  String? _error;
  int _attempt = 0;
  bool _isPlaying = false;
  bool _playedDemo = false;
  late int _difficulty;
  String? _selectedId;
  bool _completed = false;
  final Map<String, ColorId> _cellColors = {};
  List<SoundId> _availableSounds = [];
  String _k(int r, int c) => '$r:$c';
  String? _mirrorFlashAxis;
  int _intyCards = 0;     // immunity
  int _skipCards = 0;
  int _replayCards = 0;
  double _endOverlayOpacity = 0.0;
  String _formatElapsedTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // 🔹 Card usage within this run (for finishGame / IQ calc)
  int _intysUsed = 0;
  int _skipsUsed = 0;
  int _replaysUsed = 0;
  int _shimmerCycle = 0;

  // 🔹 Whether an immunity is currently active for NEXT mistake
  bool _immunityActive = false;

  int _readInt(dynamic value, {int? fallback}) {
    if (value == null) return fallback ?? 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    return fallback ?? 0;
  }

  String _assetForSound(SoundId s) {
    switch (s) {
      case SoundId.drums:   return 'sfx/drums.wav';
      case SoundId.guitar:  return 'sfx/guitar.wav';
      case SoundId.flute: return 'sfx/trumpet.wav';
      case SoundId.piano:   return 'sfx/piano.wav';
    }
  }

  void _registerIncorrect() {
    // If immunity is active, consume it and DO NOT increment incorrects.
    if (_immunityActive) {
      _immunityActive = false;
      _log.add('🛡️ Immunity protected you from this mistake.');
      return;
    }

    _incorrects++;

    if (_incorrects >= _maxMistakesForCurrentDifficulty) {
      _handleLose();
    }
  }

  Map<String, _Piece> _clonePieces(Map<String, _Piece> source) {
    return source.map((key, p) {
      return MapEntry(
        key,
        _Piece(
          id: p.id,
          shape: p.shape,
          pos: GridPos(p.pos.row, p.pos.col),
          color: p.color,
          qTurns: p.qTurns,
        ),
      );
    });
  }

  List<_RewardTileData> _buildRewardData() {
    final list = <_RewardTileData>[];

    if (_endCoinsReward > 0) {
      list.add(_RewardTileData(
        label: 'Coins',
        value: _endCoinsReward,
        asset: 'assets/images/coin.png',
      ));
    }
    if (_endIntyReward > 0) {
      list.add(_RewardTileData(
        label :'Immunity',
        value: _endIntyReward,
        asset: 'assets/images/inmmunityCard.png',
      ));
    }
    if (_endSkipReward > 0) {
      list.add(_RewardTileData(
        label: 'Skip',
        value: _endSkipReward,
        asset:'assets/images/skipCard.png',
      ));
    }
    if (_endReplayReward > 0) {
      list.add(_RewardTileData(
        label: 'Replay',
        value: _endReplayReward,
        asset: 'assets/images/replayCard.png',
      ));
    }

    return list;
  }

// 🔸 Staggered reveal of reward tiles
  void _startRewardReveal() {
    final rewardsCount = _buildRewardData().length;
    if (rewardsCount == 0) return;

    _endRewardRevealCount = 0;

    for (int i = 0; i < rewardsCount; i++) {
      Future.delayed(Duration(milliseconds: 220 * (i + 1)), () {
        if (!mounted || !_showEndOverlay) return;
        setState(() {
          _endRewardRevealCount = i + 1;
        });
      });
    }
  }

  Future<void> _playDemoHintUpToSteps(int stepsToShow) async {
    if (_engine == null) return;

    // 🔹 Snapshot player state
    final savedPieces = _clonePieces(_pieces);
    final savedCellColors = Map<String, ColorId>.from(_cellColors);
    final savedSelectedId = _selectedId;
    final savedCompleted = _completed;
    final savedStepIndex = _stepIndex;
    final savedPlayedDemo = _playedDemo;

    // 🔹 Clear board just for the visual demo
    setState(() {
      _pieces.clear();
      _cellColors.clear();
      _isPlaying = true;
      // keep _playedDemo effectively true; we don't want to block interaction later
    });

    final int stepMs = _demoStepMsForDifficulty(_difficulty);
    int userSeen = 0;

    for (final a in _engine!.playback()) {
      if (_isUserAction(a)) {
        userSeen++;
        if (userSeen > stepsToShow) break;
      }

      _log.add('DEMO (hint): ${a.type.name}'
          '${a.instanceId != null ? ' id=${a.instanceId}' : ''}'
          '${a.pos != null ? ' @${a.pos}' : ''}'
          '${a.quarterTurns != null ? ' q=${a.quarterTurns}' : ''}'
          '${a.color != null ? ' color=${a.color}' : ''}'
          '${a.sound != null ? ' sound=${a.sound}' : ''}'
          '${a.axis != null ? ' axis=${a.axis}' : ''}');

      _applyToRenderer(
        a,
        rows: _engine!.cfg.rows,
        cols: _engine!.cfg.cols,
      );

      if (a.type == ActionType.playSound && a.sound != null) {
        await _playSfx(a.sound!);
      }
      if (a.type == ActionType.mirrorBoard && a.axis != null) {
        unawaited(_flashMirror(a.axis!));
      }

      if (!mounted) return;
      setState(() {});
      await Future.delayed(_delayFor(a, stepMs));
    }

    if (!mounted) return;

    // 🔹 Restore the player's board + progress
    setState(() {
      _pieces
        ..clear()
        ..addAll(savedPieces);
      _cellColors
        ..clear()
        ..addAll(savedCellColors);

      _selectedId = savedSelectedId;
      _completed = savedCompleted;
      _stepIndex = savedStepIndex;
      _isPlaying = false;
      _playedDemo = savedPlayedDemo; // stays true
    });

    _log.add('--- Hint replay complete. Continue from step $_stepIndex ---');
  }

  Future<void> _useImmunityCard() async {
    if (_intyCards <= 0) {
      _log.add('No immunity cards left.');
      setState(() {});
      return;
    }

    if (_immunityActive) {
      _log.add('Immunity already active for the next mistake.');
      setState(() {});
      return;
    }

    _intyCards--;
    _intysUsed++;
    _immunityActive = true;
    _log.add('🛡️ Immunity activated for the next mistake.');

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({
        'intyCards': FieldValue.increment(-1),
        'currentGame.intysUsed': _intysUsed,
      }, SetOptions(merge: true));
    }

    setState(() {});
  }

  Future<void> _useSkipCard() async {
    if (_skipCards <= 0) {
      _log.add('No skip cards left.');
      setState(() {});
      return;
    }

    if (!_playedDemo || _isPlaying || _completed) {
      _log.add('You can only use Skip during your turn.');
      setState(() {});
      return;
    }

    if (_stepIndex >= _steps.length) {
      _log.add('Nothing to skip – you are past the last step.');
      setState(() {});
      return;
    }

    _skipCards--;
    _skipsUsed++;

    // Apply skip on the *current* expected step
    _applySkipOnCurrentStep();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({
        'skipCards': FieldValue.increment(-1),
        'currentGame.skipsUsed': _skipsUsed,
      }, SetOptions(merge: true));
    }

    setState(() {});
  }

  Future<void> _useReplayCard() async {
    // No stock
    if (_replayCards <= 0) {
      _log.add('No replay cards left.');
      setState(() {});
      return;
    }

    // No sequence ready yet
    if (_engine == null || _sequenceStepCounts.isEmpty || !_playedDemo) {
      _log.add('No sequence to replay yet.');
      setState(() {});
      return;
    }

    // Don’t fight with an ongoing demo
    if (_isPlaying) {
      _log.add('Wait for the current demo to finish before replaying.');
      setState(() {});
      return;
    }

    _replayCards--;
    _replaysUsed++;
    _log.add('🔁 Replay card used – showing the demo again.');

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({
        'replayCards': FieldValue.increment(-1),
        'currentGame.replaysUsed': _replaysUsed,
      }, SetOptions(merge: true));
    }

    setState(() {});
    await _replaySame();
  }

  Future<void> _handleLose() async {
    String reason;

    if (_hasRisked) {
      if (!_reachedFirstDouble) {
        reason =
        'You lost before reaching the 2× prize. The system will give you 0.5× of the base reward for this difficulty.';
      } else {
        reason =
        'You had already reached the 2× prize. Losing now gives you half of that (1× the base reward).';
      }
    } else {
      reason =
      'You did not complete a full level in this run, so there is no reward.';
    }

    await _finishRunAndCollectRewards(
      riskMode: _hasRisked,
      walkedAway: false,
      lost: true,
      reasonText: reason,
    );
  }

  static const int _extraUserStepsPerContinue = 5;

  void _registerMove() {
    _currentMove++;
    _log.add('➡️ Move $_currentMove');  // simple debug line

    if (_hasRisked && !_reachedFirstDouble) {
      final extraMoves = _currentMove - _movesAtFirstWin;
      if (extraMoves >= _movesForFirstDouble) {
        _reachedFirstDouble = true;
        _log.add('🎯 You reached the 2× prize threshold!');
        setState(() {});
      }
    }
  }

  void _applySkipOnCurrentStep() {
    if (_stepIndex >= _steps.length) return;

    final s = _steps[_stepIndex];

    switch (s.type) {
      case ActionType.spawn:
        if (s.shape != null && s.pos != null) {
          final id = _nextUserId();
          _pieces[id] = _Piece(
            id: id,
            shape: s.shape!,
            pos: s.pos!,
          );
          if (s.demoId != null) {
            _demoToUserId[s.demoId!] = id;
            s.boundUserId = id;
          }
        }
        break;

      case ActionType.move:
        {
          final demoId = s.demoId;
          final mappedId =
              s.boundUserId ?? (demoId != null ? _demoToUserId[demoId] : null);
          if (mappedId != null && s.pos != null) {
            final p = _pieces[mappedId];
            if (p != null) {
              p.pos = s.pos!;
            }
          }
        }
        break;

      case ActionType.setColor:
        {
          final demoId = s.demoId;
          final mappedId =
              s.boundUserId ?? (demoId != null ? _demoToUserId[demoId] : null);
          if (mappedId != null && s.color != null) {
            final p = _pieces[mappedId];
            if (p != null) {
              p.color = s.color!;
            }
          }
        }
        break;

      case ActionType.paintCell:
        if (s.pos != null && s.color != null) {
          _cellColors[_k(s.pos!.row, s.pos!.col)] = s.color!;
        }
        break;

      case ActionType.playSound:
      // For now: treat as auto-complete, no sound needed.
        break;

      case ActionType.mirrorBoard:
      // For now we just mark it as done without changing the board.
        break;

      case ActionType.rotate:
      // For skip we just auto-complete the rotation; no board change needed
        break;

      case ActionType.delay:
      // No-op, but we rarely create delay steps in _steps.
        break;
    }

    _log.add('⏭️ Skipped a step: ${s.type.name}.');
    _stepIndex++;
    _checkGoalSatisfied();
  }

  void _startTimerIfNeeded() {
    if (_timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_completed) return; // stop counting once finished
      setState(() {
        _elapsedSeconds++;
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }


  void _computeSequenceStepCounts() {
    // Count user-meaningful steps from the full target
    final userActions = _target.where(_isUserAction).toList();
    final totalSteps = userActions.length;

    _sequenceCount = _sequenceCountForDifficulty(_difficulty);
    _currentSequenceIndex = 0;
    _sequenceStepCounts = [];

    if (_sequenceCount == 1) {
      _sequenceStepCounts = [totalSteps];
      return;
    }

    if (_sequenceCount == 2) {
      final half = (totalSteps / 2).ceil();
      _sequenceStepCounts = [half, totalSteps];
      return;
    }

    // 3 sequences: ~1/3, ~2/3, full
    final third = (totalSteps / 3).ceil();
    final twoThird = (2 * totalSteps / 3).ceil();
    _sequenceStepCounts = [third, twoThird, totalSteps];
  }

  Future<void> _confirmQuit() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color bg =
    isDark ? const Color(0xFF070B12) : theme.cardColor;
    final Color borderColor = isDark
        ? Colors.white.withOpacity(0.12)
        : Colors.black.withOpacity(0.08);

    final result = await showDialog<bool>(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quit puzzle?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to quit?',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 20),

                // Buttons row
                Row(
                  children: [
                    // Cancel (left): transparent bg, white border, white text
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 12),
                          backgroundColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                              color: Colors.white,
                              width: 1.4,
                            ),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Quit (right): solid red, no border
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 12),
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Quit',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == true && mounted) {
      _stopTimer();
      Navigator.of(context).pop();// back to PlayScreen
    }
  }


  Future<void> _playSfx(SoundId s) async {
    final src = _assetForSound(s);
    try {
      await _sfx.stop();
      await _sfx.play(AssetSource(src));   // returns Future<void>

      // Log the current state instead of using the (void) result
      final st = _sfx.state;               // PlayerState.playing / paused / stopped
      _log.add('🔊 play $src -> ${st.name}');
    } catch (e) {
      _log.add('⚠️ audio error for $src: $e');
    }
    setState(() {});
  }

  Future<void> _flashMirror(String axis) async {
    _mirrorFlashAxis = axis;
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _mirrorFlashAxis = null);
  }


  void _onMirror(String axis) {
    if (_engine == null || !_playedDemo) {
      _log.add('Play the demo first.');
      setState(() {});
      return;
    }

    if (_enforceOrder && !_expect(ActionType.mirrorBoard)) {
      _log.add('❌ Wrong move: expected ${_steps[_stepIndex].type.name}.');
      _registerIncorrect();
      setState(() {});
      return;
    }

    final a = GameAction.mirror(axis);

    // Replicate mode: just apply to renderer
    _applyToRenderer(a, rows: _engine!.cfg.rows, cols: _engine!.cfg.cols);
    _log.add('MIRROR axis=$axis ✓');
    _registerMove();

    if (_enforceOrder) _stepIndex++;
    _checkGoalSatisfied();

    // quick visual flash (optional)
    _flashMirror(axis);

    setState(() {});
  }

  void _mirrorPaints(GridPos Function(int r, int c) mapFn) {
    final next = <String, ColorId>{};
    _cellColors.forEach((k, v) {
      final parts = k.split(':');
      final r = int.parse(parts[0]);
      final c = int.parse(parts[1]);
      final m = mapFn(r, c);
      next[_k(m.row, m.col)] = v;
    });
    _cellColors
      ..clear()
      ..addAll(next);
  }

  int _runCoins = 0;

  // Simple helper – keep in sync with your backend difficultyConfig
  int _baseCoinsForDifficulty(int d) {
    const baseByDifficulty = <int, int>{
      1: 30, // Easy
      2: 60, // Medium
      3: 90, // Hard
      4: 140, // Expert
      5: 200, // Master
      6: 500, // Extreme
      7: 1000, // Impossible
    };
    return baseByDifficulty[d.clamp(1, 7)] ?? 30;
  }

  Future<void> _startWithDifficulty(int d) async {
    _stopTimer();

    setState(() {
      _difficulty = d;
      _log.clear();
      _error = null;

      _pieces.clear();
      _cellColors.clear();
      _selectedId = null;
      _completed = false;
      _playedDemo = false;
      _isPlaying = false;

      // reset run meta
      _incorrects = 0;
      _currentMove = 0;
      _elapsedSeconds = 0;
      _hasRisked = false;
      _reachedFirstDouble = false;
      _hasFinishedRun = false;
      _movesAtFirstWin = 0;
    });

    await _load();   // 🔹 will now generate a brand-new random target
  }

  void _prepareInputPhaseForSteps(int stepsToShow) {
    _steps = [];
    _stepIndex = 0;
    _demoToUserId.clear();
    _selectedId = null;
    _completed = false;

    int taken = 0;

    for (final a in _target) {
      if (!_isUserAction(a)) continue; // skip delays etc.

      taken++;
      if (taken > stepsToShow) break;

      _steps.add(
        _Step(
          type: a.type,
          demoId: a.instanceId,
          shape: a.shape,
          pos: a.pos,
          color: a.color,
        ),
      );
    }
  }

  LevelConfig scaleConfigForDifficulty(LevelConfig base, int d) {
    final profile = kDifficultyProfiles[d.clamp(1, 8)] ?? kDifficultyProfiles[1]!;

    // new: use time-based seed so palette varies each load
    final int seed = DateTime.now().millisecondsSinceEpoch;
    final r = Random(seed);

    final allShapes = ShapeType.values.toList()..shuffle(r);
    final allColors = ColorId.values.toList()..shuffle(r);
    final allSounds = SoundId.values.toList()..shuffle(r);

    final shapePal = allShapes.take(profile.maxShapes).toList();
    final colorPal = allColors.take(profile.maxColors).toList();
    final soundPal = allSounds.take(profile.maxSounds).toList();

    return LevelConfig(
      worldId: base.worldId,
      levelId: 'D$d',
      rows: profile.rows,
      cols: profile.cols,
      shapePalette: shapePal,
      colorPalette: colorPal,
      soundPalette: soundPal,
      actionCount: profile.actionCount,
      playbackSpeedMs: profile.demoStepMs,
      allowedMistakes: profile.allowedMistakes,
      enableRotation: profile.enableRotation,
      enableMove: profile.enableMove,
      enableColor: profile.enableColor,
      enableSound: profile.enableSound,
      enableMirror: profile.enableMirror,
      hideAfterMs: profile.hideAfterMs,
      seed: seed, // you can also reuse `seed` here
    );
  }

  List<GameAction> genRandomTarget(LevelConfig cfg, {required int attempt}) {
    final r = Random(cfg.seed ^ (attempt * 104729));
    final actions = <GameAction>[];
    final Map<String, GridPos> piecePos = {};

    // Decide how many spawns (1 at low difficulty, maybe 2+ later)
    final spawnCount = (cfg.rows >= 3 && cfg.cols >= 3 && cfg.actionCount >= 6)
        ? (r.nextInt(2) + 1) // 1..2
        : 1;

    // Create spawn ids A, B, ...
    final ids = List.generate(spawnCount, (i) => String.fromCharCode(65 + i));
    final taken = <String>{};

    GridPos rndCell() {
      GridPos p;
      do {
        p = GridPos(r.nextInt(cfg.rows), r.nextInt(cfg.cols));
      } while (taken.contains('${p.row}:${p.col}'));
      taken.add('${p.row}:${p.col}');
      return p;
    }

    // --- 🔹 Board tracking for rule enforcement ---
    // Last known position of each piece
    final lastPos = <String, GridPos>{};

    // Current color of each piece (if any)
    final pieceColors = <String, ColorId?>{
      for (final id in ids) id: null,
    };

    // Background color of each cell (from paintCell actions)
    final cellColors = <String, ColorId>{};
    String cellKey(GridPos p) => '${p.row}:${p.col}';

    // --- Spawn each piece + optional initial color ---
    for (final id in ids) {
      final shape = cfg.shapePalette[r.nextInt(cfg.shapePalette.length)];
      final pos = rndCell();
      actions.add(GameAction.spawn(id, shape, pos));
      lastPos[id] = pos;

      // Optional: color at spawn time
      if (cfg.enableColor && r.nextBool()) {
        final c = cfg.colorPalette[r.nextInt(cfg.colorPalette.length)];
        actions.add(GameAction.setColor(id, c));
        pieceColors[id] = c;
      }
    }

    // --- Build allowed step kinds based on toggles ---
    final allowedKinds = <String>[];
    if (cfg.enableColor)    allowedKinds.addAll(['color', 'paint']);
    if (cfg.enableMove)     allowedKinds.add('move');
    if (cfg.enableRotation) allowedKinds.add('rot');
    if (cfg.enableMirror)   allowedKinds.add('mirror');
    if (cfg.enableSound && cfg.soundPalette.isNotEmpty) {
      allowedKinds.add('sound');
    }

    // Make the rest of the sequence up to actionCount
    int userSteps = 0;
    final targetUserSteps = max(0, cfg.actionCount - actions.length);

    while (userSteps < targetUserSteps) {
      final id = ids[r.nextInt(ids.length)];
      final kind = allowedKinds[r.nextInt(allowedKinds.length)];

      switch (kind) {
        case 'color': {
          final currentColor = pieceColors[id];

          // Build list of colors different from currentColor
          final availableColors = cfg.colorPalette
              .where((c) => c != currentColor)
              .toList();

          // If there's no alternative color (e.g. palette size 1 and already that color),
          // skip this action and try another kind.
          if (availableColors.isEmpty) {
            continue;
          }

          final c = availableColors[r.nextInt(availableColors.length)];
          actions.add(GameAction.setColor(id, c));
          pieceColors[id] = c; // track piece color
          userSteps++;
          break;
        }

        case 'move': {
          final current = lastPos[id];
          GridPos to;

          while (true) {
            to = GridPos(r.nextInt(cfg.rows), r.nextInt(cfg.cols));

            final sameCell = current != null &&
                current.row == to.row &&
                current.col == to.col;

            if (!sameCell) break;
          }

          lastPos[id] = to;
          actions.add(GameAction.move(id, to));
          userSteps++;
          break;
        }
        case 'rot': {
          // 🔹 RULE: cannot rotate if piece color == cell color under it
          final pos = lastPos[id]!;
          final pc = pieceColors[id];
          final cc = cellColors[cellKey(pos)];

          final blocked = pc != null && cc != null && pc == cc;
          if (blocked) {
            // Skip this rotate, try another random action in the next loop
            continue;
          }

          final qTurns = r.nextBool() ? 1 : 3;
          actions.add(GameAction.rotate(id, qTurns));
          userSteps++;
          break;
        }
        case 'mirror': {
          final axis = r.nextBool() ? 'x' : 'y';
          actions.add(GameAction.mirror(axis));
          userSteps++;

          // 🔹 Keep lastPos + cellColors in sync with mirrored board
          if (axis == 'x') {
            // horizontal mirror: flip rows
            lastPos.updateAll((id, pos) => GridPos(cfg.rows - 1 - pos.row, pos.col));

            final next = <String, ColorId>{};
            cellColors.forEach((key, value) {
              final parts = key.split(':');
              final rr = int.parse(parts[0]);
              final cc = int.parse(parts[1]);
              final m = GridPos(cfg.rows - 1 - rr, cc);
              next['${m.row}:${m.col}'] = value;
            });
            cellColors
              ..clear()
              ..addAll(next);
          } else {
            // axis == 'y' → vertical mirror: flip cols
            lastPos.updateAll((id, pos) => GridPos(pos.row, cfg.cols - 1 - pos.col));

            final next = <String, ColorId>{};
            cellColors.forEach((key, value) {
              final parts = key.split(':');
              final rr = int.parse(parts[0]);
              final cc = int.parse(parts[1]);
              final m = GridPos(rr, cfg.cols - 1 - cc);
              next['${m.row}:${m.col}'] = value;
            });
            cellColors
              ..clear()
              ..addAll(next);
          }

          break;
        }
        case 'paint': {
          const int maxAttempts = 10;
          GridPos pos;
          ColorId c;
          int attempts = 0;

          // Try a few times to find a (pos, color) combo that actually changes something.
          while (true) {
            pos = GridPos(r.nextInt(cfg.rows), r.nextInt(cfg.cols));
            c = cfg.colorPalette[r.nextInt(cfg.colorPalette.length)];
            attempts++;

            final existing = cellColors[cellKey(pos)];

            // Accept only if this cell is either unpainted, or painted a different color.
            if (existing == null || existing != c) break;

            if (attempts >= maxAttempts) {
              // Couldn’t find a non-redundant paint; skip and let the loop try another kind.
              pos = GridPos(0, 0); // dummy
              break;
            }
          }

          final existing = cellColors[cellKey(pos)];
          if (existing != null && existing == c) {
            // Still redundant, give up on this paint step
            continue;
          }

          actions.add(GameAction.paintCell(pos, c));
          cellColors[cellKey(pos)] = c; // track cell color
          userSteps++;
          break;
        }
        case 'sound': {
          final s = cfg.soundPalette[r.nextInt(cfg.soundPalette.length)];
          actions.add(GameAction.playSound(s));
          userSteps++;
          break;
        }
      }
    }

    return actions;
  }

  Future<void> _resumeFromSavedGame(Map<String, dynamic> g) async {
    setState(() {
      _log.clear();
      _error = null;
      _completed = false;
      _selectedId = null;
      _cellColors.clear();
      _pieces.clear();
    });

    try {
      final loaded = await _repo
          .loadFirstLevelW1()
          .timeout(const Duration(seconds: 6));

      final baseCfg = loaded.cfg;
      final cfg = scaleConfigForDifficulty(baseCfg, _difficulty);

      final rawTarget = g['target'];
      if (rawTarget is! List) {
        // No script → fallback to fresh level
        await _startWithDifficulty(_difficulty);
        return;
      }

      final target = _deserializeTarget(rawTarget);

      setState(() {
        _target = target;
        _engine = GameEngine(cfg: cfg, target: target);
      });

      _log.add(
          'Resumed saved game: ${cfg.rows}x${cfg.cols} | steps≈${cfg.actionCount} | d=$_difficulty');

      _computeSequenceStepCounts();
      await _startSequence(0); // restart from sequence 1, but SAME script
    } on TimeoutException catch (e) {
      _error = 'Timed out loading level config';
      _log.add('⚠️ $_error: $e');
      setState(() {});
    } catch (e, st) {
      _error = 'Resume load error: $e';
      _log.add('❌ $_error\n$st');
      setState(() {});
      // fallback: new level
      await _startWithDifficulty(_difficulty);
    }
  }

  @override
  void initState() {
    super.initState();

    _sfx = AudioPlayer()
      ..setReleaseMode(ReleaseMode.stop)
      ..setVolume(1.0);

    // Pull values from currentGame if provided (for resume)
    final g = widget.initialGame;
    _difficulty = _readInt(
      g?['difficulty'],
      fallback: widget.initialDifficulty,
    );

    _incorrects     = _readInt(g?['incorrects'],   fallback: 0);
    _currentMove    = _readInt(g?['currentMove'],  fallback: 0);
    _elapsedSeconds = _readInt(g?['time'],         fallback: 0);

    // Also restore how many cards were already used in this run (if present)
    _intysUsed   = (g?['intysUsed'] as int?) ?? 0;
    _skipsUsed   = (g?['skipsUsed'] as int?) ?? 0;
    _replaysUsed = (g?['replaysUsed'] as int?) ?? 0;

    // 🔹 Load card inventory from the user doc (intyCards / skipCards / replayCards)
    _loadUserCards();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (g != null && g['target'] != null) {
        _resumeFromSavedGame(g);
      } else {
        _startWithDifficulty(_difficulty);
      }
    });

  }
  String _bonusTextForDifficulty(int d) {
    // Base rule: coins double every 5 extra correct moves
    final base =
        '• Every 5 extra correct moves will double your coins for this run.';

    if (d <= 2) {
      // Easy / Medium
      return base;
    } else if (d <= 4) {
      // Hard / Expert
      return [
        base,
        '• Every 10 extra moves also gives you an INTY (Immunity) card.',
      ].join('\n');
    } else if (d == 5) {
      // Master
      return [
        base,
        '• Every 10 extra moves gives you:\n'
            '   – 1 INTY (Immunity) card\n'
            '   – 1 SKIP card',
      ].join('\n');
    } else {
      // Extreme / Impossible (6–7)
      return [
        base,
        '• Every 10 extra moves gives you a Replay card.',
      ].join('\n');
    }
  }

  String _riskRulesText() {
    return [
      '• If you lose before reaching the 2× prize, you only get 0.5× of the base reward for this difficulty.',
      '• If you reach 2× and then lose, you get half of that (1× the base reward).',
      '• You can walk away at any time and keep your current prize.',
    ].join('\n');
  }

  Future<void> _showWinDialog() async {
    if (!mounted) return;

    // Stop timer so time doesn't keep ticking on the dialog
    _stopTimer();

    final theme = Theme.of(context);
    final bonusText = _bonusTextForDifficulty(_difficulty);
    final riskText = _riskRulesText();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('You win!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nice job, you completed this level!',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'If you continue playing in this run, you can earn extra rewards:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                bonusText,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'But be careful:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                riskText,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          actions: [
            // 1) Finish now: base reward, no risk
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _finishRunAndCollectRewards(
                  riskMode: false,       // did not risk, just taking base prize
                  walkedAway: false,
                  lost: false,
                  reasonText:
                  'You chose to collect the base reward for this difficulty.',
                );
              },
              child: const Text('Finish & collect'),
            ),

            // 2) Continue in risk mode
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _continueRunFromWin();
              },
              child: const Text('Continue playing'),
            ),
          ],
        );
      },
    );
  }

  Map<String, dynamic> _serializeAction(GameAction a) {
    return {
      'type': a.type.name,               // spawn, move, setColor, rotate, ...
      'id': a.instanceId,
      'row': a.pos?.row,
      'col': a.pos?.col,
      'shape': a.shape?.name,
      'color': a.color?.name,
      'sound': a.sound?.name,
      'axis': a.axis,
      'ms': a.ms,
    };
  }

  List<Map<String, dynamic>> _serializeTarget(List<GameAction> target) {
    return target.map(_serializeAction).toList();
  }

  Future<void> _continueRunFromWin() async {
    // Enter risk mode: future losses will apply penalties in finishGame
    _hasRisked = true;

    // 🔹 Increase *effective* difficulty by 1 each time we continue playing,
    // capped at your max difficulty.
    if (_difficulty < 7) {
      _difficulty++;
    }

    // We keep _incorrects, _currentMove, _elapsedSeconds so extra moves
    // are counted in the same run.
    setState(() {
      _completed = false;
      _selectedId = null;
    });

    await _extendRunWithMoreSteps();
  }

  /// Read the current card balances from users/{uid}
  Future<void> _loadUserCards() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final data = snap.data();
      if (data == null) return;

      setState(() {
        _intyCards   = (data['intyCards'] as int?) ?? 0;
        _skipCards   = (data['skipCards'] as int?) ?? 0;
        _replayCards = (data['replayCards'] as int?) ?? 0;
      });
    } catch (e) {
      // Optional: log or show a snackbar in debug mode
      // debugPrint('Failed to load card counts: $e');
    }
  }


  @override
  void dispose() {
    _stopTimer();
    _iqCounterTimer?.cancel();
    _sfx.dispose();
    super.dispose();
  }

  GameAction _deserializeAction(Map<String, dynamic> m) {
    final typeName = m['type'] as String?;
    final id = m['id'] as String?;
    final row = m['row'] as int?;
    final col = m['col'] as int?;
    final shapeName = m['shape'] as String?;
    final colorName = m['color'] as String?;
    final soundName = m['sound'] as String?;
    final axis = m['axis'] as String?;
    final ms = m['ms'] as int?;

    GridPos? pos;
    if (row != null && col != null) {
      pos = GridPos(row, col);
    }

    ShapeType? shape;
    if (shapeName != null) {
      shape = ShapeType.values.firstWhere(
            (s) => s.name == shapeName,
        orElse: () => ShapeType.square,
      );
    }

    ColorId? color;
    if (colorName != null) {
      color = ColorId.values.firstWhere(
            (c) => c.name == colorName,
        orElse: () => ColorId.red,
      );
    }

    SoundId? sound;
    if (soundName != null) {
      sound = SoundId.values.firstWhere(
            (s) => s.name == soundName,
        orElse: () => SoundId.drums,
      );
    }

    switch (typeName) {
      case 'spawn':
        if (id != null && shape != null && pos != null) {
          return GameAction.spawn(id, shape, pos);
        }
        break;
      case 'move':
        if (id != null && pos != null) {
          return GameAction.move(id, pos);
        }
        break;
      case 'setColor':
        if (id != null && color != null) {
          return GameAction.setColor(id, color);
        }
        break;
      case 'rotate':
        final q = ms ?? m['q'] as int? ?? 1;
        if (id != null) {
          return GameAction.rotate(id, q);
        }
        break;
      case 'paintCell':
        if (pos != null && color != null) {
          return GameAction.paintCell(pos, color);
        }
        break;
      case 'playSound':
        if (sound != null) {
          return GameAction.playSound(sound);
        }
        break;
      case 'mirrorBoard':
        if (axis != null) {
          return GameAction.mirror(axis);
        }
        break;
      case 'delay':
        final d = ms ?? 300;
        return GameAction.delay(d);
    }

    // Fallback no-op if something is malformed
    return GameAction.delay(0);
  }

  List<GameAction> _deserializeTarget(List<dynamic> raw) {
    return raw
        .whereType<Map>() // keep only maps
        .map((m) => _deserializeAction(m.cast<String, dynamic>()))
        .toList();
  }

  Future<void> _finishRunAndCollectRewards({
    required bool riskMode,
    required bool walkedAway,
    required bool lost,
    String? reasonText,
  }) async {
    if (!mounted || _hasFinishedRun) return;
    _hasFinishedRun = true;

    _stopTimer();
    setState(() {
      _completed = true;
    });

    final functions = FirebaseFunctions.instanceFor(region: 'us-central1');

    try {
      final callable = functions.httpsCallable('finishGame');

      debugPrint('finishGame sending: '
          'currentMove=$_currentMove, '
          'incorrects=$_incorrects, '
          'timeSeconds=$_elapsedSeconds, '
          'riskMode=$riskMode, walkedAway=$walkedAway, lost=$lost');

      final resp = await callable.call(<String, dynamic>{
        'riskMode': riskMode,
        'walkedAway': walkedAway,
        'lost': lost,
        'currentMove': _currentMove,
        'incorrects': _incorrects,
        'timeSeconds': _elapsedSeconds,
        'hasCompletedBase': true,
      });
      debugPrint('finishGame resp.data = ${resp.data}');

      final data = (resp.data as Map?) ?? {};

      // NOTE: iqReward here is your “Estimated IQ” value from the function
      final int finalIq =
          (data['finalIq'] as num?)?.toInt() ?? 0;
      final int coinsReward =
          (data['coinsReward'] as num?)?.toInt() ?? 0;
      final int intyReward =
          (data['intyCardsReward'] as num?)?.toInt() ?? 0;
      final int skipReward =
          (data['skipCardsReward'] as num?)?.toInt() ?? 0;
      final int replayReward =
          (data['replayCardsReward'] as num?)?.toInt() ?? 0;

      // 🔹 Store values for the overlay
      setState(() {
        _endIsWin = !lost;

        _showEndOverlay = true;
        _endOverlayOpacity = 0.0;
        _endTitleVisible = true;
        _showEndResultsSheet = false;

        // show the *absolute* IQ as "Estimated IQ"
        _endIqTarget = finalIq;
        _endIqDisplay = 0;

        _endCoinsReward = coinsReward;
        _endIntyReward = intyReward;
        _endSkipReward = skipReward;
        _endReplayReward = replayReward;
        _endRewardRevealCount = 0;
      });

      Future.microtask(() {
        if (!mounted) return;
        setState(() {
          _endOverlayOpacity = 1.0;
        });
      });

      // Blink “You Won/Lost” twice
      _runWinLoseBlink();

      // After 1.5s, slide in the results sheet and start animations
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted || !_showEndOverlay) return;
        setState(() {
          _showEndResultsSheet = true;
        });
        _startIqCountUp();
        _startRewardReveal();
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Failed to finish game')),
      );
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Unexpected error while finishing game')),
      );
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  void _rotateSelected(int qTurns) {
    final id = _selectedId;
    if (id == null) {
      _log.add('Select a piece first.');
      setState(() {});
      return;
    }

    // 🔹 RULE: cannot rotate if piece color == cell color
    final p = _pieces[id];
    if (p != null) {
      final cellColor = _cellColors[_k(p.pos.row, p.pos.col)];
      if (cellColor != null && p.color != null && cellColor == p.color) {
        _log.add('❌ You can\'t rotate a piece on a same-colored tile.');
        setState(() {}); // refresh any log UI
        return;
      }
    }

    // (Optional) order enforcement for rotate
    if (_enforceOrder && !_expect(ActionType.rotate)) {
      _log.add('❌ Wrong move: expected ${_steps[_stepIndex].type.name}.');
      _registerIncorrect();
      setState(() {});
      return;
    }

    if (_replicateMode) {
      final p = _pieces[id];
      if (p != null) {
        p.qTurns = (p.qTurns + qTurns) % 4;
        _log.add('ROTATE $id q=$qTurns ✓');

        _registerMove();                // ✅ count this move

        if (_enforceOrder) _stepIndex++;
        _checkGoalSatisfied();
        setState(() {});
      }
      return;
    }

    // Engine-validated path (kept for completeness)
    if (_engine == null) return;
    final action = GameAction.rotate(id, qTurns);
    final ok = _engine!.validate(action);
    _log.add('ROTATE $id q=$qTurns ${ok ? "✓" : "✗"}');

    if (ok) {
      _applyToRenderer(action, rows: _engine!.cfg.rows, cols: _engine!.cfg.cols);
      _registerMove();                  // ✅ only count successful rotates
      if (_enforceOrder) _stepIndex++;
      _checkGoalSatisfied();
    } else {
      // optional: mark incorrect if you want
      // _registerIncorrect();
    }

    setState(() {});
  }

  void _checkGoalSatisfied() {
    if (_goal.isEmpty || _completed) return;

    // Must finish the ordered script first
    if (_enforceOrder && _stepIndex < _steps.length) {
      return; // not all steps done yet
    }

    final ok =
        _goal.every((g) =>
            _pieces.values.any((p) =>
            p.shape == g.shape &&
                p.color == g.color &&
                p.pos.row == g.pos.row &&
                p.pos.col == g.pos.col)) &&
            _pieces.length == _goal.length;

    if (ok) {
      _completed = true;
      _selectedId = null;
      _log.add('🎉 You matched the demo layout!');
      _stopTimer();

      // 🔹 NEW: sequence progression
      final lastSequenceIndex = _sequenceCount - 1;
      if (_currentSequenceIndex < lastSequenceIndex) {
        // More sequences remain -> start the next one
        _log.add('➡️ Sequence ${_currentSequenceIndex + 1} complete. Starting next sequence...');
        // Small delay so the user sees success before new demo
        Future.microtask(() async {
          if (!mounted) return;
          await _startSequence(_currentSequenceIndex + 1);
        });
      } else {
        _log.add('🏁 All sequences complete! (Difficulty $_difficulty)');

        // 🔹 First full level completion for this run
        _movesAtFirstWin = _currentMove;
        _hasRisked = false;
        _reachedFirstDouble = false;

        // 🔹 Set base coins preview for this run
        _runCoins = _baseCoinsForDifficulty(_difficulty);

        // Show win dialog with "continue playing" option
        _showWinDialog();
      }

      setState(() {});
    }
  }

  void _onPaintCell(int r, int c, ColorId color) {
    if (_enforceOrder) {
      if (!_expect(ActionType.paintCell)) {
        _log.add('❌ Wrong move: expected ${_steps[_stepIndex].type.name}.');
        _registerIncorrect();
        setState(() {}); return;
      }
      final s = _steps[_stepIndex];
      if (!_posEq(s.pos, r, c)) {
        _log.add('❌ Expected paint at (${s.pos?.row},${s.pos?.col}).');
        _registerIncorrect();
        setState(() {}); return;
      }
      if (s.color != color) {
        _log.add('❌ Expected color ${s.color}.');
        _registerIncorrect();
        setState(() {}); return;
      }
    }

    // record paint
    _cellColors[_k(r, c)] = color;
    _log.add('PAINT ($r,$c) → $color ✓');
    _registerMove();
    if (_enforceOrder) _stepIndex++;
    _checkGoalSatisfied();
    setState(() {});
  }


  void _onSpawnShape(ShapeType shape, int r, int c) {
    if (_enforceOrder) {
      if (!_expect(ActionType.spawn)) {
        _log.add('❌ Wrong move: expected ${_steps[_stepIndex].type.name}.');
        _registerIncorrect();
        setState(() {}); return;
      }
      final s = _steps[_stepIndex];
      if (s.shape != shape || !_posEq(s.pos, r, c)) {
        _log.add('❌ Expected spawn ${s.shape} at (${s.pos?.row},${s.pos?.col}).');
        _registerIncorrect();
        setState(() {}); return;
      }
    }

    if (_engine == null) return;
    if (!_playedDemo) { _log.add('Play demo first.'); setState(() {}); return; }

    // Don’t stack
    if (_pieces.values.any((p) => p.pos.row == r && p.pos.col == c)) {
      _log.add('Cell ($r,$c) already occupied.');
      _registerIncorrect();
      setState(() {});
      return;
    }

    final id = _nextUserId();

    if (_replicateMode) {
      // renderer only
      _pieces[id] = _Piece(id: id, shape: shape, pos: GridPos(r, c));
      if (_enforceOrder) {
        final s = _steps[_stepIndex];
        if (s.demoId != null) {
          _demoToUserId[s.demoId!] = id;
          s.boundUserId = id;
        }
        _stepIndex++;
      }

      _log.add('SPAWN $shape @($r,$c) ✓');
      _registerMove();
      _checkGoalSatisfied();
      setState(() {});
      return;
    }

    // original step-by-step validation
    final ok = _engine!.validate(GameAction.spawn(id, shape, GridPos(r, c)));
    _log.add('SPAWN $shape @($r,$c) id=$id ${ok ? "✓" : "✗"}');
    if (ok) {
      _applyToRenderer(GameAction.spawn(id, shape, GridPos(r, c)),
          rows: _engine!.cfg.rows, cols: _engine!.cfg.cols);
      if (_engine!.isComplete) _log.add('🎉 Level complete!');
      _registerMove();
    }
    setState(() {});
  }

  Future<void> _onPlaySound(SoundId snd) async {
    if (_enforceOrder && !_expect(ActionType.playSound)) {
      _log.add('❌ Wrong move: expected ${_steps[_stepIndex].type.name}.');
      _registerIncorrect();
      setState(() {});
      return;
    }

    // audible feedback
    await _playSfx(snd);

    _log.add('SOUND ${snd.name} ✓');
    _registerMove();
    if (_enforceOrder) _stepIndex++;
    _checkGoalSatisfied();
    setState(() {});
  }


  void _onMovePiece(String id, int r, int c) {
    if (_enforceOrder) {
      if (!_expect(ActionType.move)) {
        _log.add('❌ Wrong move: expected ${_steps[_stepIndex].type.name}.');
        _registerIncorrect();
        setState(() {}); return;
      }
      final s = _steps[_stepIndex];

      // If the demo referenced a specific id, require the mapped user id:
      if (s.demoId != null) {
        final expectedUserId = _demoToUserId[s.demoId!];
        if (expectedUserId != null && expectedUserId != id) {
          _log.add('❌ Move the piece from the previous step.');
          _registerIncorrect();
          setState(() {}); return;
        }
      }
      if (!_posEq(s.pos, r, c)) {
        _log.add('❌ Expected move to (${s.pos?.row},${s.pos?.col}).');
        _registerIncorrect();
        setState(() {}); return;
      }
    }

    if (_engine == null) return;
    if (!_playedDemo) { _log.add('Play demo first.'); setState(() {}); return; }

    if (_replicateMode) {
      final p = _pieces[id];
      if (p != null) {
        p.pos = GridPos(r, c);
        _log.add('MOVE $id → ($r,$c) ✓');
        _registerMove();
        if (_enforceOrder) _stepIndex++;     // <-- advance step here
        _checkGoalSatisfied();
        setState(() {});
      }
      return;
    }

    final action = GameAction.move(id, GridPos(r, c));
    final ok = _engine!.validate(action);
    _log.add('MOVE $id → ($r,$c) ${ok ? "✓" : "✗"}');
    if (ok) {
      _applyToRenderer(action, rows: _engine!.cfg.rows, cols: _engine!.cfg.cols);
      if (_engine!.isComplete) _log.add('🎉 Level complete!');
      _registerMove();
    }
    if (_enforceOrder) _stepIndex++;
    setState(() {});
  }

  void _onColorPiece(String id, ColorId color) {
    if (_enforceOrder) {
      if (!_expect(ActionType.setColor)) {
        _log.add('❌ Wrong move: expected ${_steps[_stepIndex].type.name}.');
        _registerIncorrect();
        setState(() {});
        return;
      }
      final s = _steps[_stepIndex];

      // Must color the same logical piece from the demo
      if (s.demoId != null) {
        final expectedUserId = _demoToUserId[s.demoId!];
        if (expectedUserId != null && expectedUserId != id) {
          _log.add('❌ Color the piece placed in the previous step.');
          _registerIncorrect();
          setState(() {});
          return;
        }
      }
      if (s.color != color) {
        _log.add('❌ Expected color ${s.color}.');
        _registerIncorrect();
        setState(() {});
        return;
      }
    }

    if (_engine == null) return;
    if (!_playedDemo) {
      _log.add('Play demo first.');
      setState(() {});
      return;
    }

    if (_replicateMode) {
      final p = _pieces[id];
      if (p != null) {
        p.color = color;
        _log.add('COLOR $id → $color ✓');

        _registerMove();                     // ✅ count this action

        if (_enforceOrder) _stepIndex++;
        _checkGoalSatisfied();
        setState(() {});
      }
      return;
    }

    final action = GameAction.setColor(id, color);
    final ok = _engine!.validate(action);
    _log.add('COLOR $id → $color ${ok ? "✓" : "✗"}');

    if (ok) {
      _applyToRenderer(action, rows: _engine!.cfg.rows, cols: _engine!.cfg.cols);
      if (_engine!.isComplete) _log.add('🎉 Level complete!');
      _registerMove();                       // ✅ already correct here
      if (_enforceOrder) _stepIndex++;
      _checkGoalSatisfied();
    }

    setState(() {});
  }

  Future<void> _startSequence(int index) async {
    if (_engine == null) return;
    if (index < 0 || index >= _sequenceStepCounts.length) return;

    _currentSequenceIndex = index;
    final stepsToShow = _sequenceStepCounts[index];

    // 1) Play demo up to this many user actions
    await _playDemoUpToSteps(stepsToShow);

    // 2) Prepare input phase for exactly that many steps
    _prepareInputPhaseForSteps(stepsToShow);
  }

  Future<void> _load() async {
    setState(() {
      _log.clear();
      _isPlaying = false;
      _playedDemo = false;
      _error = null;
      _completed = false;
      _selectedId = null;
      _cellColors.clear();
    });

    try {
      final loaded = await _repo
          .loadFirstLevelW1()
          .timeout(const Duration(seconds: 6));

      // 👇 Save the full, original config once
      _baseConfig ??= loaded.cfg;

      final cfg = scaleConfigForDifficulty(_baseConfig!, _difficulty);

      // 🔹 NEW: unique attempt seed per load
      final int attemptSeed = DateTime.now().millisecondsSinceEpoch;

      final target = genRandomTarget(
        cfg,
        attempt: attemptSeed,
      );

      setState(() {
        _target = target;
        _engine = GameEngine(cfg: cfg, target: target);

        _availableShapes  = List<ShapeType>.from(cfg.shapePalette);
        _availableColors  = List<ColorId>.from(cfg.colorPalette);
        _availableSounds  = List<SoundId>.from(cfg.soundPalette);
      });

      _pieces.clear();

      _log.add(
          'Loaded ${cfg.rows}x${cfg.cols} | steps≈${cfg.actionCount} | d=$_difficulty');

      _computeSequenceStepCounts();
      await _startInitialCountdownAndSequence();
    } on TimeoutException catch (e) {
      _error = 'Timed out loading level config';
      _log.add('⚠️ $_error: $e');
      setState(() {});
    } catch (e, st) {
      _error = 'Load error: $e';
      _log.add('❌ $_error\n$st');
      setState(() {});
    }
  }

  int _demoStepMsForDifficulty(int d) {
    final profile = kDifficultyProfiles[d.clamp(1, 8)] ?? kDifficultyProfiles[1]!;
    return profile.demoStepMs;
  }

  Duration _delayFor(GameAction a, int stepMs) {
    // never go *faster* than the stepMs pacing
    if (a.type == ActionType.delay) {
      final d = a.ms ?? stepMs;
      return Duration(milliseconds: d >= stepMs ? d : stepMs);
    }
    return Duration(milliseconds: stepMs);
  }


  Future<void> _playDemoUpToSteps(int stepsToShow) async {
    if (_engine == null) return;

    _cellColors.clear();
    _pieces.clear();
    setState(() {
      _isPlaying = true;
      _playedDemo = false;
    });

    final int stepMs = _demoStepMsForDifficulty(_difficulty);
    int userSeen = 0;

    for (final a in _engine!.playback()) {
      // Stop once we've shown the desired number of user actions
      if (_isUserAction(a)) {
        userSeen++;
        if (userSeen > stepsToShow) break;
      }

      _log.add('DEMO: ${a.type.name}'
          '${a.instanceId != null ? ' id=${a.instanceId}' : ''}'
          '${a.pos != null ? ' @${a.pos}' : ''}'
          '${a.quarterTurns != null ? ' q=${a.quarterTurns}' : ''}'
          '${a.color != null ? ' color=${a.color}' : ''}'
          '${a.sound != null ? ' sound=${a.sound}' : ''}'
          '${a.axis != null ? ' axis=${a.axis}' : ''}');
      _applyToRenderer(
        a,
        rows: _engine!.cfg.rows,
        cols: _engine!.cfg.cols,
      );

      if (a.type == ActionType.playSound && a.sound != null) {
        await _playSfx(a.sound!);
      }
      if (a.type == ActionType.mirrorBoard && a.axis != null) {
        _log.add('— mirror ${a.axis} —');
        unawaited(_flashMirror(a.axis!));
      }

      setState(() {});
      await Future.delayed(_delayFor(a, stepMs));
    }

    // Snapshot goal AFTER this partial demo
    final goalSnapshot = _pieces.values
        .map((p) => _GoalPiece(p.shape, p.color, p.pos))
        .toList();

    // Now clear board for input phase
    _goal = goalSnapshot;
    _pieces.clear();
    _cellColors.clear();

    setState(() {
      _isPlaying = false;
      _playedDemo = true;
    });
    _startTimerIfNeeded();

    _log.add('--- Demo sequence ${_currentSequenceIndex + 1}/${_sequenceCount} complete. Input phase ---');
  }

  void _applyToRenderer(GameAction a, {required int rows, required int cols}) {
    switch (a.type) {
      case ActionType.spawn:
        if (a.instanceId != null && a.shape != null && a.pos != null) {
          _pieces[a.instanceId!] = _Piece(
            id: a.instanceId!,
            shape: a.shape!,
            pos: a.pos!,
            color: null,
          );
        }
        break;

      case ActionType.move:
        final id = a.instanceId;
        final p = (id != null) ? _pieces[id] : null;
        if (p != null && a.pos != null) p.pos = a.pos!;
        break;

      case ActionType.rotate:
        final id = a.instanceId;
        final p = (id != null) ? _pieces[id] : null;
        if (p != null) p.qTurns = (p.qTurns + (a.quarterTurns ?? 0)) % 4;
        break;

      case ActionType.setColor:
        final id = a.instanceId;
        final p = (id != null) ? _pieces[id] : null;
        if (p != null && a.color != null) p.color = a.color!;
        break;

    // ✅ NEW: paint the background of a grid cell
      case ActionType.paintCell:
        if (a.pos != null && a.color != null) {
          _cellColors[_k(a.pos!.row, a.pos!.col)] = a.color!;
        }
        break;

    // ✅ REPLACE your old mirrorBoard case with this (adds diagonal & paints)
      case ActionType.mirrorBoard:
        final axis = a.axis; // "x" | "y" | "d"
        if (axis == 'x') {
          for (final p in _pieces.values) {
            p.pos = GridPos(rows - 1 - p.pos.row, p.pos.col);
          }
          _mirrorPaints((r, c) => GridPos(rows - 1 - r, c));
        } else if (axis == 'y') {
          for (final p in _pieces.values) {
            p.pos = GridPos(p.pos.row, cols - 1 - p.pos.col);
          }
          _mirrorPaints((r, c) => GridPos(r, cols - 1 - c));
        } else if (axis == 'd') { // TL↘︎BR diagonal
          for (final p in _pieces.values) {
            p.pos = GridPos(
              p.pos.col.clamp(0, rows - 1),
              p.pos.row.clamp(0, cols - 1),
            );
          }
          _mirrorPaints((r, c) => GridPos(
            c.clamp(0, rows - 1),
            r.clamp(0, cols - 1),
          ));
        }
        break;

      case ActionType.delay:
      case ActionType.playSound:
      // no visible state change here
        break;
    }
  }

// Put this helper anywhere inside _EngineHarnessScreenState

  Future<void> _replaySame() async {
    if (_engine == null || _sequenceStepCounts.isEmpty) return;

    final index = _currentSequenceIndex.clamp(0, _sequenceStepCounts.length - 1);
    final stepsToShow = _sequenceStepCounts[index];

    await _playDemoHintUpToSteps(stepsToShow);
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _engine?.cfg;
    final bool canInteract = _playedDemo && !_isPlaying && !_completed;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );
    final maxMistakes = _maxMistakesForCurrentDifficulty;

    return Stack(
      children: [
        // 🔹 Main app (AppBar + body)
        Scaffold(
          drawer: _buildPauseDrawer(context),
          appBar: AppBar(
            automaticallyImplyLeading: true,
            titleSpacing: 0,
            title: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _RunCoinsBadge(coins: _runCoins),
            ),
            actions: [
              if (_hasRisked && !_completed)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: TextButton(
                    onPressed: () {
                      _finishRunAndCollectRewards(
                        riskMode: true,
                        walkedAway: true,
                        lost: false,
                        reasonText: _reachedFirstDouble
                            ? 'You walked away after reaching at least the 2× prize.'
                            : 'You walked away keeping your current prize.',
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      backgroundColor: Colors.green.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Walk away',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              // Difficulty bar under app bar
              _buildDifficultyBar(context),
              const SizedBox(height: 4),

              // Existing content, animated
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _error != null && cfg == null
                      ? _buildErrorState(theme)
                      : (cfg == null
                      ? _buildBlankLoading(theme)
                      : _buildGameContent(
                    context,
                    cfg,
                    canInteract,
                    cs,
                    buttonShape,
                    maxMistakes,
                  )),
                ),
              ),
            ],
          ),
        ),

        // 🔹 Countdown overlay ABOVE app bar + body
        if (_showCountdown)
           Positioned.fill(
            child: _CountdownOverlay(
              // remove const if value is not const:
              value: _countdownValue,
            ),
          ),

        // 🔹 Win/lose overlay ABOVE everything
        if (_showEndOverlay)
          Positioned.fill(
            child: _buildEndOfRunOverlay(theme),
          ),
      ],
    );
  }

  Widget _buildTimer(ThemeData theme) {
    final cs = theme.colorScheme;
    final text = _formatElapsedTime(_elapsedSeconds);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
          ),
          child: Text(
            text,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 40,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEndOfRunOverlay(ThemeData theme) {
    final text = _endIsWin ? 'You Won!' : 'You Lost';
    final rewards = _buildRewardData();
    final cs = theme.colorScheme;

    return AnimatedOpacity(
      opacity: _endOverlayOpacity,
      duration: const Duration(milliseconds: 600), // slower
      curve: Curves.easeOutCubic,
      child: IgnorePointer(
        ignoring: false, // overlay is clickable
        child: Container(
          color: Colors.black.withOpacity(0.55),
          child: Stack(
            children: [
              // Center "You Won / You Lost" that blinks
              Center(
                child: AnimatedOpacity(
                  opacity: _endTitleVisible ? 1 : 0.25,
                  duration: const Duration(milliseconds: 220),
                  child: Text(
                    text,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 34,
                    ),
                  ),
                ),
              ),

              // Bottom sheet: we’ll let _EndRewardsSheet handle everything
              Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedSlide(
                  offset: _showEndResultsSheet ? Offset.zero : const Offset(0, 1),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  child: _EndRewardsSheet(
                    iqDelta: _endIqTarget,           // <-- use this
                    coins: _endCoinsReward,
                    inty: _endIntyReward,
                    skip: _endSkipReward,
                    replay: _endReplayReward,
                    difficulty: _difficulty,
                    onClose: () {
                      setState(() {
                        _showEndOverlay = false;
                      });
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlankLoading(ThemeData theme) {
    return Container(
      key: const ValueKey('blank'),
      color: theme.scaffoldBackgroundColor,  // respects light/dark theme
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Container(
      key: const ValueKey('error'),
      color: theme.scaffoldBackgroundColor,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Couldn\'t load level',
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (_error != null)
            Text(
              _error!,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => _startWithDifficulty(_difficulty),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyBar(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final visual = _difficultyVisualFor(_difficulty);
    final label = visual.label;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          // 🔹 The filling bar
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final totalWidth = constraints.maxWidth;
                final targetWidth = totalWidth * visual.fillFraction;

                return Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: cs.surfaceVariant.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      width: targetWidth,
                      // We’ll stack the color + shimmer inside
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: Stack(
                          children: [
                            // Base difficulty color
                            Container(color: visual.color),

                            // 🔹 Shimmer sweep every ~2s
                            if (targetWidth > 0)
                              TweenAnimationBuilder<double>(
                                key: ValueKey(_shimmerCycle),
                                tween: Tween<double>(begin: -0.5, end: 1.5),
                                duration: const Duration(seconds: 2),
                                onEnd: () {
                                  if (!mounted) return;
                                  setState(() {
                                    _shimmerCycle++;
                                  });
                                },
                                builder: (context, t, child) {
                                  final shimmerWidth = targetWidth * 0.4;
                                  final left =
                                      (targetWidth + shimmerWidth) * t - shimmerWidth;

                                  return Positioned(
                                    left: left,
                                    top: 0,
                                    bottom: 0,
                                    child: Transform.rotate(
                                      angle: -0.35, // tilted a bit
                                      child: Container(
                                        width: shimmerWidth,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Colors.white.withOpacity(0.0),
                                              Colors.white.withOpacity(0.22),
                                              Colors.white.withOpacity(0.0),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(width: 12),

          // 🔹 Difficulty label with slide/fade animation
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, animation) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              );

              final isIncoming =
                  (child.key as ValueKey?)?.value == label;

              if (isIncoming) {
                // New label: fade in + slide from ABOVE
                final offsetIn = Tween<Offset>(
                  begin: const Offset(0, -0.4),
                  end: Offset.zero,
                ).animate(curved);
                return FadeTransition(
                  opacity: curved,
                  child: SlideTransition(
                    position: offsetIn,
                    child: child,
                  ),
                );
              } else {
                // Old label: fade out + slide DOWN
                final offsetOut = Tween<Offset>(
                  begin: Offset.zero,
                  end: const Offset(0, 0.4),
                ).animate(curved);
                return FadeTransition(
                  opacity: ReverseAnimation(curved),
                  child: SlideTransition(
                    position: offsetOut,
                    child: child,
                  ),
                );
              }
            },
            child: Text(
              label,
              key: ValueKey(label),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: visual.color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameContent(
      BuildContext context,
      LevelConfig cfg,
      bool canInteract,
      ColorScheme cs,
      ShapeBorder buttonShape,
      int maxMistakes,
      ) {
    final theme = Theme.of(context);

    return SafeArea(
      key: const ValueKey('game'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 32,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Error / loading states (only when cfg is null)
                  if (_error != null && cfg == null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 8),
                    const Text('Tip: check asset path / repository loader.'),
                    const SizedBox(height: 16),
                  ] else if (cfg == null) ...[
                    const Text('Loading config...'),
                    const SizedBox(height: 16),
                  ],

                  // Main game UI once config is ready
                  if (cfg != null) ...[
                    _buildTimer(theme),
                    const SizedBox(height: 12),
                    // 🔹 Mistake tracker: big boxes with animated X icons
                    _buildMistakeTrack(theme, cs, maxMistakes),
                    const SizedBox(height: 12),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _CardButton(
                            assetPath: 'assets/images/inmmunityCard.png',
                            count: _intyCards,
                            color: Colors.deepPurple,
                            onPressed: canInteract ? _useImmunityCard : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _CardButton(
                            assetPath: 'assets/images/skipCard.png',
                            count: _skipCards,
                            color: const Color(0xFFFA3434),
                            onPressed: canInteract ? _useSkipCard : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _CardButton(
                            assetPath: 'assets/images/replayCard.png',
                            count: _replayCards,
                            color: const Color(0xFF0090D8),
                            onPressed: (_engine != null &&
                                _playedDemo &&
                                !_isPlaying &&
                                _replayCards > 0)
                                ? _useReplayCard
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Rotate buttons row
                    if (cfg.enableRotation) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: canInteract
                                  ? () => _rotateSelected(1)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                                minimumSize: const Size(0, 46),
                              ),
                              icon: const Icon(Icons.rotate_right),
                              label: const Text('Rotate'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: canInteract
                                  ? () => _rotateSelected(3)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                                minimumSize: const Size(0, 46),
                              ),
                              icon: const Icon(Icons.rotate_left),
                              label: const Text('Rotate'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Colors | Grid | Shapes
                    // Colors | Grid | Shapes – NEW LAYOUT
                    LayoutBuilder(
                      builder: (context, innerConstraints) {
                        // Use ~90% of the available width (outer padding already applied)
                        final double gridWidth =
                        (innerConstraints.maxWidth * 0.80).clamp(180.0, innerConstraints.maxWidth);

                        return Center(
                          child: SizedBox(
                            width: gridWidth,
                            child: BoardGrid(
                              rows: cfg.rows,
                              cols: cfg.cols,
                              pieces: _pieces.values.toList(),
                              onMove: _onMovePiece,
                              onColor: _onColorPiece,
                              onSpawn: _onSpawnShape,
                              cellColors: _cellColors,
                              onPaintCell: _onPaintCell,
                              selectedId: _selectedId,
                              onTapPiece: (id) => setState(() => _selectedId = id),
                              enabled: canInteract && !_completed,
                              mirrorAxis: _mirrorFlashAxis,
                              wantPaintHere: (r, c) {
                                if (!_enforceOrder) return false;
                                if (_stepIndex >= _steps.length) return false;
                                final s = _steps[_stepIndex];
                                return s.type == ActionType.paintCell &&
                                    s.pos?.row == r &&
                                    s.pos?.col == c;
                              },
                              onPlaySound: cfg.enableSound ? _onPlaySound : null,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),

// Color palette row (centered)
                    if (cfg.enableColor && _availableColors.isNotEmpty) ...[
                      Center(
                        child: _ColorPalette(
                          colors: _availableColors,
                          enabled: canInteract && cfg.enableColor,
                          cs: cs,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

// Shape palette row (centered)
                    Center(
                      child: _ShapePalette(
                        shapes: _availableShapes,
                        enabled: canInteract,
                        cs: cs,
                      ),
                    ),

                    const SizedBox(height: 16),
                    if (cfg.enableSound && _availableSounds.isNotEmpty) ...[
                      Center(
                        child: Builder(
                          builder: (context) {
                            final count = _availableSounds.length;
                            final double spacing =
                            count <= 3 ? 16.0 : (count <= 6 ? 12.0 : 8.0);
                            final double runSpacing =
                            count <= 3 ? 12.0 : (count <= 6 ? 10.0 : 6.0);

                            return Wrap(
                              alignment: WrapAlignment.center,
                              spacing: spacing,
                              runSpacing: runSpacing,
                              children: [
                                for (final s in _availableSounds)
                                  Draggable<SoundId>(
                                    maxSimultaneousDrags: canInteract ? 1 : 0,
                                    data: s,
                                    feedback: Material(
                                      color: Colors.transparent,
                                      child: _SoundBubble(sound: s),
                                    ),
                                    childWhenDragging: Opacity(
                                      opacity: 0.4,
                                      child: _SoundBubble(sound: s),
                                    ),
                                    child: _SoundBubble(sound: s),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    const SizedBox(height: 16),

                    // Mirror controls
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (cfg.enableMirror && canInteract) ...[
                          ActionChip(
                            avatar: const Icon(Icons.swap_vert),
                            label: const Text('Mirror X'),
                            onPressed: () => _onMirror('x'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.swap_horiz),
                            label: const Text('Mirror Y'),
                            onPressed: () => _onMirror('y'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.change_history),
                            label: const Text('Mirror D'),
                            onPressed: () => _onMirror('d'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMistakeTrack(ThemeData theme, ColorScheme cs, int maxMistakes) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: List.generate(maxMistakes, (index) {
          final filled = index < _incorrects;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: AspectRatio(
                aspectRatio: 3 / 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                        color: const Color(0xFFEDEDED),   // pure white// white card
                      boxShadow: [
                        // Looks like an INNER glow once clipped
                        BoxShadow(
                          color: Colors.black.withOpacity(0.30),
                          blurRadius: 18,
                          spreadRadius: 8,
                          offset: Offset.zero,
                        ),
                      ],
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        transitionBuilder: (child, animation) {
                          final curved = CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutBack,
                          );
                          return ScaleTransition(
                            scale: curved,
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: filled
                            ? Image.asset(
                          'assets/images/incorrectIcon.png',
                          key: ValueKey('incorrect_$index'),
                          width: 100,
                          height: 100,
                        )
                            : SizedBox(
                          key: ValueKey('empty_$index'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPauseDrawer(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Pause',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: cs.primary),
              title: const Text('Quit to menu'),
              onTap: () async {
                // close drawer first
                Navigator.of(context).pop();
                // reuse the existing quit confirmation dialog
                await _confirmQuit();
              },
            ),
            ListTile(
              leading: Icon(Icons.refresh, color: cs.primary),
              title: const Text('Retry'),
              onTap: () {
                // close drawer first
                Navigator.of(context).pop();
                // restart same difficulty -> new sequence + countdown overlay
                _startWithDifficulty(_difficulty);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Simple grid widget ----------

class BoardGrid extends StatefulWidget {
  const BoardGrid({
    super.key,
    required this.rows,
    required this.cols,
    required this.pieces,
    required this.onMove,
    required this.onColor,
    required this.onSpawn,
    required this.cellColors,           // NEW
    required this.onPaintCell,
    this.mirrorAxis, // 'x' | 'y' | 'd' | null
    this.selectedId,
    this.onTapPiece,
    this.wantPaintHere,
    this.animDuration = const Duration(milliseconds: 260),
    this.animCurve = Curves.easeInOut,
    this.gap = 6.0,
    this.enabled = true,
    this.onPlaySound,

  });

  final bool enabled;
  final bool Function(int r, int c)? wantPaintHere;
  final String? mirrorAxis;
  final int rows;
  final int cols;
  final List<_Piece> pieces;
  final Map<String, ColorId> cellColors;                 // NEW
  final void Function(int r, int c, ColorId color) onPaintCell;
  final void Function(String id, int r, int c) onMove;
  final void Function(String id, ColorId color) onColor;
  final void Function(ShapeType shape, int r, int c) onSpawn;

  final String? selectedId;
  final void Function(String id)? onTapPiece;

  final Duration animDuration;
  final Curve animCurve;
  final double gap; // spacing between cells
  final void Function(SoundId sound)? onPlaySound;

  @override
  State<BoardGrid> createState() => _BoardGridState();
}

class _BoardGridState extends State<BoardGrid> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AspectRatio(
      aspectRatio: widget.cols / widget.rows,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Compute cell size from available box + gap
          final totalGapW = widget.gap * (widget.cols - 1);
          final totalGapH = widget.gap * (widget.rows - 1);
          final cellW = (constraints.maxWidth  - totalGapW) / widget.cols;
          final cellH = (constraints.maxHeight - totalGapH) / widget.rows;

          double leftFor(int c) => c * (cellW + widget.gap);
          double topFor (int r) => r * (cellH + widget.gap);

          // --- Grid (drag targets) + animated piece layer ---
          return Stack(
            children: [
              // 1) GRID CELLS LAYER (DragTarget per cell)
              for (int r = 0; r < widget.rows; r++)
                for (int c = 0; c < widget.cols; c++)
                  Positioned(
                    left: leftFor(c),
                    top: topFor(r),
                    width: cellW,
                    height: cellH,
                    child: _GridCellTarget(
                      r: r,
                      c: c,
                      cs: cs,
                      enabled: widget.enabled,
                      onAcceptPiece: (id) => widget.onMove(id, r, c),
                      onAcceptColor: (color) {
                        final forcePaint = widget.wantPaintHere?.call(r, c) ?? false;

                        if (forcePaint) {
                          widget.onPaintCell(r, c, color);
                          return;
                        }

                        final inCell = widget.pieces
                            .where((p) => p.pos.row == r && p.pos.col == c)
                            .toList();
                        if (inCell.isNotEmpty) {
                          widget.onColor(inCell.last.id, color);
                        } else {
                          widget.onPaintCell(r, c, color);
                        }
                      },
                      onAcceptShape: (shape) => widget.onSpawn(shape, r, c),
                      onAcceptSound: widget.onPlaySound,   // 🔹 NEW
                    ),
                  ),

              // 2) PIECE LAYER (absolute, animated positions)
              for (final p in widget.pieces)
                AnimatedPositioned(
                  key: ValueKey(p.id),
                  duration: widget.animDuration,
                  curve: widget.animCurve,
                  left: leftFor(p.pos.col),
                  top:  topFor(p.pos.row),
                  width: cellW,
                  height: cellH,
                  child: _AnimatedPiece(
                    piece: p,
                    selected: widget.selectedId == p.id,
                    onTap: () => widget.onTapPiece?.call(p.id),
                    enabled: widget.enabled,
                    onAcceptColor: (color) {
                      final mustPaint = widget.wantPaintHere?.call(p.pos.row, p.pos.col) ?? false;
                      if (mustPaint) {
                        widget.onPaintCell(p.pos.row, p.pos.col, color); // 🎨 paint wins
                      } else {
                        widget.onColor(p.id, color);                     // 🎯 color the piece
                      }
                    },
                    allowColorDrop: true, // keep the DragTarget on the piece active
                  ),

                ),
              if (widget.mirrorAxis != null)
                Positioned.fill(child: _MirrorLines(axis: widget.mirrorAxis!)),

            ],
          );
        },
      ),
    );
  }
}

/// Single cell drag target with highlight
class _GridCellTarget extends StatefulWidget {
  const _GridCellTarget({
    required this.r,
    required this.c,
    required this.cs,
    required this.onAcceptPiece,
    required this.onAcceptColor,
    required this.onAcceptShape,
    required this.enabled,
    this.onAcceptSound,
  });

  final bool enabled;
  final int r, c;
  final ColorScheme cs;
  final void Function(String id) onAcceptPiece;
  final void Function(ColorId color) onAcceptColor;
  final void Function(ShapeType shape) onAcceptShape;
  final void Function(SoundId sound)? onAcceptSound;

  @override
  State<_GridCellTarget> createState() => _GridCellTargetState();
}

class _GridCellTargetState extends State<_GridCellTarget> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return DragTarget<Object>(
      onWillAccept: (data) {
        final will = widget.enabled &&
            (data is _DragPiece ||
                data is _DragColor ||
                data is _DragShape ||
                (data is SoundId && widget.onAcceptSound != null));
        setState(() => _hover = will);
        return will;
      },
      onLeave: (_) => setState(() => _hover = false),
      onAccept: (data) {
        if (!widget.enabled) return;
        setState(() => _hover = false);

        if (data is _DragPiece) {
          widget.onAcceptPiece(data.id);
        } else if (data is _DragColor) {
          widget.onAcceptColor(data.color);
        } else if (data is _DragShape) {
          widget.onAcceptShape(data.shape);
        } else if (data is SoundId && widget.onAcceptSound != null) { // 🔹
          widget.onAcceptSound!(data);
        }
      },
      builder: (_, __, ___) {
        // resolve painted bg color
        final key = '${widget.r}:${widget.c}';
        final board = context.findAncestorWidgetOfExactType<BoardGrid>()!;
        final paintColor = board.cellColors[key];

        return Container(
          decoration: BoxDecoration(
            color: paintColor != null
                ? _mapColor(paintColor, widget.cs)
                : widget.cs.surface.withOpacity(0.25), // subtle base
            borderRadius: BorderRadius.circular(6),    // squarer cells
            border: Border.all(
              color: Colors.white.withOpacity(0.5), // 👈 white grid lines
              width: _hover ? 2.0 : 1.4,               // a bit thicker on hover
            ),
          ),
        );
      },
    );
  }
}

/// A draggable, selectable, color/rotation-animated piece that fits in one cell.
class _AnimatedPiece extends StatelessWidget {
  const _AnimatedPiece({
    required this.piece,
    required this.selected,
    required this.onTap,
    required this.enabled,
    required this.onAcceptColor,
    this.allowColorDrop = true,    // NEW
  });

  final bool allowColorDrop;
  final bool enabled;
  final _Piece piece;
  final bool selected;
  final VoidCallback onTap;
  final void Function(ColorId color) onAcceptColor;  //

  String _shapeFillAsset(ShapeType shape) {
    switch (shape) {
      case ShapeType.square:
        return 'assets/images/square.png';
      case ShapeType.rectangle:
        return 'assets/images/rectangle.png';
      case ShapeType.circle:
        return 'assets/images/circle.png';
      case ShapeType.triangle:
        return 'assets/images/triangle.png';

      case ShapeType.squareOutline:
        return 'assets/images/squareOutline.png';
      case ShapeType.rectangleOutline:
        return 'assets/images/rectangleOutline.png';
      case ShapeType.circleOutline:
        return 'assets/images/circleOutline.png';
      case ShapeType.triangleOutline:
        return 'assets/images/triangleOutline.png';
    }
  }

  String _shapeMarkAsset(ShapeType shape) {
    switch (shape) {
      case ShapeType.square:
      case ShapeType.squareOutline:
        return 'assets/images/squareMark.png';

      case ShapeType.rectangle:
      case ShapeType.rectangleOutline:
        return 'assets/images/rectangleMark.png';

      case ShapeType.circle:
      case ShapeType.circleOutline:
        return 'assets/images/circleMark.png';

      case ShapeType.triangle:
      case ShapeType.triangleOutline:
        return 'assets/images/triangleMark.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final key = ValueKey('${piece.id}-${piece.color?.index ?? -1}-${piece.qTurns % 4}');
    final angle = (piece.qTurns % 4) * 3.1415926535 / 2;
    final pieceColor = _renderPieceColor(piece.color, cs);

    final icon = Transform.rotate(
      angle: angle,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 🔵 1) FILL – tinted
          Image.asset(
            _shapeFillAsset(piece.shape),
            width: selected ? 110 : 100,
            height: selected ? 110 : 100,
            color: pieceColor, // only the fill gets tinted
          ),
          // ⚪ 2) MARKER – NOT tinted
          Image.asset(
            _shapeMarkAsset(piece.shape),
            width: selected ? 110 : 100,
            height: selected ? 110 : 100,
            // no color: uses the original pixel colors (e.g. white line)
          ),
        ],
      ),
    );


    // This is the *inner* content
    final inner = _pieceBody(key, icon, cs, selected: selected);

    // Wrap it optionally in a DragTarget
    Widget body = inner;
    if (allowColorDrop) {
      body = DragTarget<Object>(
        onWillAccept: (data) => enabled && data is _DragColor,
        onAccept: (data) {
          if (!enabled) return;
          if (data is _DragColor) onAcceptColor(data.color);
        },
        builder: (_, __, ___) => inner, // <-- return the inner, not `body`
      );
    }
    return LongPressDraggable<_DragPiece>(
      maxSimultaneousDrags: enabled ? 1 : 0,
      data: _DragPiece(piece.id),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Transform.rotate(
              angle: angle,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    _shapeFillAsset(piece.shape),
                    width: 40,
                    height: 40,
                    color: pieceColor,
                  ),
                  Image.asset(
                    _shapeMarkAsset(piece.shape),
                    width: 40,
                    height: 40,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      childWhenDragging: Opacity(opacity: .35, child: body),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: body,
      ),
    );
  }


  Widget _pieceBody(ValueKey<String> key, Widget icon, ColorScheme cs,
      {bool selected = false}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: selected ? Border.all(color: cs.primary, width: 2) : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: KeyedSubtree(key: key, child: Center(child: icon)),
      ),
    );
  }
}

class _MirrorLines extends StatelessWidget {
  const _MirrorLines({required this.axis});
  final String axis;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MirrorPainter(axis, Theme.of(context).colorScheme.primary),
    );
  }
}

class _MirrorPainter extends CustomPainter {
  _MirrorPainter(this.axis, this.color);
  final String axis;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withOpacity(.55)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    switch (axis) {
      case 'x': // horizontal
        final y = size.height / 2;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
        break;
      case 'y': // vertical
        final x = size.width / 2;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
        break;
      case 'd': // diagonal TL->BR
        canvas.drawLine(Offset.zero, Offset(size.width, size.height), p);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _MirrorPainter old) => old.axis != axis || old.color != color;
}

class _SoundBubble extends StatelessWidget {
  const _SoundBubble({required this.sound});

  final SoundId sound;

  String _soundAsset(SoundId s) {
    switch (s) {
      case SoundId.drums:
        return 'assets/images/drums.png';
      case SoundId.guitar:
        return 'assets/images/guitar.png';
      case SoundId.flute:
        return 'assets/images/flute.png';
      case SoundId.piano:
        return 'assets/images/piano.png';
    }
  }


  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,  // circle size
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0x1F2430),        // subtle dark bg
        border: Border.all(
          color: Colors.transparent,
          width: 1.4,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Image.asset(
          _soundAsset(sound),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _ColorPalette extends StatelessWidget {
  const _ColorPalette({
    super.key,
    required this.colors,
    required this.enabled,
    required this.cs,
  });

  final List<ColorId> colors;
  final bool enabled;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final count = colors.length;
    const double maxSpacing = 16;
    const double minSpacing = 6;

    final spacing = count <= 3
        ? maxSpacing
        : (maxSpacing - (count - 3) * 2).clamp(minSpacing, maxSpacing);

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: spacing,
      runSpacing: spacing,
      children: [
        for (final c in colors)
          Draggable<_DragColor>(
            maxSimultaneousDrags: enabled ? 1 : 0,
            data: _DragColor(c),
            feedback: Material(
              color: Colors.transparent,
              child: _ColorDot(colorId: c, cs: cs),
            ),
            childWhenDragging: Opacity(
              opacity: 0.4,
              child: _ColorDot(colorId: c, cs: cs),
            ),
            child: _ColorDot(colorId: c, cs: cs),
          ),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    super.key,
    required this.colorId,
    required this.cs,
  });

  final ColorId colorId;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _mapColor(colorId, cs),
      ),
    );
  }
}

class _DragPiece {
  final String id;
  const _DragPiece(this.id);
}

class _DragShape {
  final ShapeType shape;
  const _DragShape(this.shape);
}

class _ShapePalette extends StatelessWidget {
  const _ShapePalette({
    super.key,
    required this.shapes,
    required this.enabled,
    required this.cs,
  });

  final List<ShapeType> shapes;
  final bool enabled;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final count = shapes.length;
    const double maxSpacing = 16;
    const double minSpacing = 6;

    final spacing = count <= 3
        ? maxSpacing
        : (maxSpacing - (count - 3) * 2).clamp(minSpacing, maxSpacing);

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: spacing,
      runSpacing: spacing,
      children: [
        for (final s in shapes)
          Draggable<_DragShape>(
            maxSimultaneousDrags: enabled ? 1 : 0,
            data: _DragShape(s),
            feedback: Material(
              color: Colors.transparent,
              child: _ShapeDot(shape: s, cs: cs),
            ),
            childWhenDragging: Opacity(
              opacity: 0.4,
              child: _ShapeDot(shape: s, cs: cs),
            ),
            child: _ShapeDot(shape: s, cs: cs),
          ),
      ],
    );
  }
}

class _ShapeDot extends StatelessWidget {
  const _ShapeDot({
    super.key,
    required this.shape,
    required this.cs,
  });

  final ShapeType shape;
  final ColorScheme cs;

  String _shapeAsset(ShapeType shape) {
    switch (shape) {
      case ShapeType.square:
        return 'assets/images/square.png';
      case ShapeType.rectangle:
        return 'assets/images/rectangle.png';
      case ShapeType.circle:
        return 'assets/images/circle.png';
      case ShapeType.triangle:
        return 'assets/images/triangle.png';
      case ShapeType.squareOutline:
        return 'assets/images/squareOutline.png';
      case ShapeType.rectangleOutline:
        return 'assets/images/rectangleOutline.png';
      case ShapeType.circleOutline:
        return 'assets/images/circleOutline.png';
      case ShapeType.triangleOutline:
        return 'assets/images/triangleOutline.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cs.surfaceVariant.withOpacity(0.16),
        ),
        child: Center(
          child: Image.asset(
            _shapeAsset(shape),
            width: 60,
            height: 60,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}

class _GoalPiece {
  final ShapeType shape;
  final ColorId? color;
  final GridPos pos;
  const _GoalPiece(this.shape, this.color, this.pos);
}

bool _replicateMode = true; // turn on the “copy what you saw” mode
List<_GoalPiece> _goal = [];

class _Step {
  final ActionType type;
  final String? demoId;   // e.g., "A" from the demo
  final ShapeType? shape;
  final GridPos? pos;
  final ColorId? color;

  String? boundUserId;    // user's piece id mapped to this demo id

  _Step({
    required this.type,
    this.demoId,
    this.shape,
    this.pos,
    this.color,
  });
}
List<_Step> _steps = [];
int _stepIndex = 0;             // points at the next required step
final Map<String, String> _demoToUserId = {};

class _DragColor {
  final ColorId color;
  _DragColor(this.color);
}

/// Discrete difficulty definition for d = 1..8
class DifficultyProfile {
  final int rows;
  final int cols;
  final int actionCount;      // how many “meaningful” steps in the script
  final int allowedMistakes;  // how many times the user can be wrong
  final bool enableMove;
  final bool enableRotation;
  final bool enableColor;
  final bool enableSound;
  final bool enableMirror;
  final int hideAfterMs;      // 0 = never hide, >0 = hide after demo
  final int demoStepMs;       // pacing of the demo (bigger = slower)

  /// How many distinct items from each palette we allow
  final int maxShapes;
  final int maxColors;
  final int maxSounds;

  const DifficultyProfile({
    required this.rows,
    required this.cols,
    required this.actionCount,
    required this.allowedMistakes,
    required this.enableMove,
    required this.enableRotation,
    required this.enableColor,
    required this.enableSound,
    required this.enableMirror,
    required this.hideAfterMs,
    required this.demoStepMs,
    required this.maxShapes,
    required this.maxColors,
    required this.maxSounds,
  });
}

/// Map 1..8 to “real” difficulty settings.
/// You can tweak these numbers to taste.
const Map<int, DifficultyProfile> kDifficultyProfiles = {
  // 1 = Easy
  1: DifficultyProfile(
    rows: 2,
    cols: 2,
    actionCount: 7,
    allowedMistakes: 3,
    enableMove: true,
    enableRotation: false,
    enableColor: true,
    enableSound: false,
    enableMirror: false,
    hideAfterMs: 0,
    demoStepMs: 1750,
    maxShapes: 3,
    maxColors: 3,
    maxSounds: 0,
  ),

  // 2 = Medium
  2: DifficultyProfile(
    rows: 2,
    cols: 2,
    actionCount: 12,
    allowedMistakes: 3,
    enableMove: true,
    enableRotation: true,
    enableColor: true,
    enableSound: false,
    enableMirror: false,
    hideAfterMs: 0,
    demoStepMs: 1650,
    maxShapes: 4,
    maxColors: 4,
    maxSounds: 0,
  ),

  // 3 = Hard
  3: DifficultyProfile(
    rows: 3,
    cols: 3,
    actionCount: 17,
    allowedMistakes: 3,
    enableMove: true,
    enableRotation: true,
    enableColor: true,
    enableSound: false,
    enableMirror: false,
    hideAfterMs: 0,
    demoStepMs: 1500,
    maxShapes: 4,
    maxColors: 4,
    maxSounds: 0,
  ),

  // 4 = Expert
  4: DifficultyProfile(
    rows: 3,
    cols: 3,
    actionCount: 25,
    allowedMistakes: 3,
    enableMove: true,
    enableRotation: true,
    enableColor: true,
    enableSound: true,
    enableMirror: false,
    hideAfterMs: 0,
    demoStepMs: 1350,
    maxShapes: 4,
    maxColors: 4,
    maxSounds: 1,
  ),

  // 5 = Master
  5: DifficultyProfile(
    rows: 3,
    cols: 3,
    actionCount: 32,
    allowedMistakes: 4,
    enableMove: true,
    enableRotation: true,
    enableColor: true,
    enableSound: true,
    enableMirror: false,
    hideAfterMs: 0,
    demoStepMs: 1200,
    maxShapes: 5,
    maxColors: 5,
    maxSounds: 3,
  ),

  // 6 = Extreme
  6: DifficultyProfile(
    rows: 4,
    cols: 4,
    actionCount: 40,
    allowedMistakes: 4,
    enableMove: true,
    enableRotation: true,
    enableColor: true,
    enableSound: true,
    enableMirror: true,
    hideAfterMs: 0,
    demoStepMs: 1100,
    maxShapes: 6,
    maxColors: 6,
    maxSounds: 4,
  ),

  // 7 = Impossible (1)
  7: DifficultyProfile(
    rows: 4,
    cols: 4,
    actionCount: 50,
    allowedMistakes: 5,
    enableMove: true,
    enableRotation: true,
    enableColor: true,
    enableSound: true,
    enableMirror: true,
    hideAfterMs: 600,
    demoStepMs: 1000,
    maxShapes: 8,
    maxColors: 8,
    maxSounds: 4,
  ),
};

class _CardButton extends StatelessWidget {
  final Color color;
  final String assetPath;
  final int count;
  final VoidCallback? onPressed;

  const _CardButton({
    required this.color,
    required this.assetPath,
    required this.count,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null;

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: color, // same color when disabled
        disabledForegroundColor: Colors.white.withOpacity(0.7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            assetPath,
            width: 27,
            height: 27,
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownOverlay extends StatelessWidget {
  final int value;
  const _CountdownOverlay({required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IgnorePointer(
      ignoring: true,
      child: Container(
        color: Colors.black.withOpacity(0.75),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, animation) {
              final scale = Tween<double>(begin: 1.1, end: 1.0).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: scale, child: child),
              );
            },
            child: Text(
              '$value',
              key: ValueKey<int>(value),
              style: theme.textTheme.displayLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 90,
              ) ??
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 90,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DifficultyVisual {
  final String label;
  final Color color;
  final double fillFraction; // 0–1
  const _DifficultyVisual(this.label, this.color, this.fillFraction);
}

class _RunCoinsBadge extends StatelessWidget {
  final int coins;

  const _RunCoinsBadge({required this.coins});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: Image.asset(
            'assets/images/coin.png', // 👈 your coin asset
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, animation) {
            // slide up slightly + fade
            final offset = Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(animation);

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: offset,
                child: child,
              ),
            );
          },
          child: Text(
            coins.toString(),
            key: ValueKey(coins), // 👈 triggers animation on change
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.amber,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ),
      ],
    );
  }
}

bool _difficultyCanRewardInty(int difficulty) {
  // hard, expert, master => 3,4,5
  return difficulty >= 3 && difficulty <= 5;
}

bool _difficultyCanRewardSkip(int difficulty) {
  // only master => 5
  return difficulty == 5;
}

bool _difficultyCanRewardReplay(int difficulty) {
  // extreme, impossible => 6,7
  return difficulty >= 6;
}

class _RewardTileData {
  final String label;
  final int value;
  final String asset;

  const _RewardTileData({
    required this.label,
    required this.value,
    required this.asset,
  });
}

class _RewardTile extends StatelessWidget {
  final _RewardTileData data;
  final int index;

  const _RewardTile({
    required this.data,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: Container(
              decoration: BoxDecoration(
                color: cs.surfaceVariant.withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: Image.asset(
                      data.asset,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      data.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    data.value.toString(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}


class _EndRewardsSheet extends StatefulWidget {
  final int iqDelta;
  final int coins;
  final int inty;
  final int skip;
  final int replay;
  final int difficulty;   // 1–7 based on your stars
  final VoidCallback onClose;

  const _EndRewardsSheet({
    required this.iqDelta,
    required this.coins,
    required this.inty,
    required this.skip,
    required this.replay,
    required this.difficulty,
    required this.onClose,
    super.key,
  });

  @override
  State<_EndRewardsSheet> createState() => _EndRewardsSheetState();
}

class _EndRewardsSheetState extends State<_EndRewardsSheet>
    with SingleTickerProviderStateMixin {
  bool _showTop = false;
  bool _showBottom = false;

  @override
  void initState() {
    super.initState();

    // Stagger: top appears, then bottom
    Future.microtask(() {
      if (!mounted) return;
      setState(() => _showTop = true);

      Future.delayed(const Duration(milliseconds: 2000), () {
        if (!mounted) return;
        setState(() => _showBottom = true);
      });
    });
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Build rewards list: always coins + applicable cards (even if 0)
    final rewards = <_RewardTileData>[
      _RewardTileData(
        label: 'Coins',
        value: widget.coins,
        asset: 'assets/images/coin.png',
      ),
      if (_difficultyCanRewardInty(widget.difficulty))
        _RewardTileData(
          label: 'Immunity',
          value: widget.inty,
          asset: 'assets/images/inmmunityCard.png',
        ),
      if (_difficultyCanRewardSkip(widget.difficulty))
        _RewardTileData(
          label: 'Skip',
          value: widget.skip,
          asset: 'assets/images/skipCard.png',
        ),
      if (_difficultyCanRewardReplay(widget.difficulty))
        _RewardTileData(
          label: 'Replay',
          value: widget.replay,
          asset: 'assets/images/replayCard.png',
        ),
    ];

    return AnimatedSlide(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      offset: const Offset(0, 0.1),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 350),
        opacity: 1,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 18,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // TOP: Estimated IQ (centered row: label + number)
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 450),
                  opacity: _showTop ? 1 : 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Estimated IQ',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TweenAnimationBuilder<double>(
                        tween: Tween(
                          begin: 0,
                          end: widget.iqDelta.toDouble(),
                        ),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOut,
                        builder: (context, value, _) {
                          return Text(
                            value.toInt().toString(),
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: cs.primary,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // BOTTOM: Rewards centered + centered button
                // BOTTOM: Rewards centered + centered button
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 450),
                  opacity: _showBottom ? 1 : 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (rewards.isNotEmpty) ...[
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 12,
                          children: List.generate(rewards.length, (index) {
                            final r = rewards[index];
                            return SizedBox(
                              width: 150, // nice card width
                              child: _RewardTile(
                                data: r,
                                index: index,
                              ),
                            );
                          }),
                        ),
                      ],

                      const SizedBox(height: 25),

                      // Centered "Continue" button
                      Center(
                        child: SizedBox(
                          height: 46,
                          width: 200,
                          child: ElevatedButton(
                            onPressed: widget.onClose,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cs.primary,
                              foregroundColor: cs.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Continue'),
                          ),
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
  }
}