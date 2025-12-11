// lib/data/.../loaded_level_from_json.dart (whatever your path is)
import 'package:flutter/foundation.dart';
import '../../engine/types.dart';
import '../../engine/level_config.dart';
import '../../engine/actions.dart';

class LoadedLevel {
  final LevelConfig cfg;
  final List<GameAction>? scripted; // null => generate procedurally
  LoadedLevel({required this.cfg, this.scripted});
}

ShapeType _shapeFrom(String s) {
  switch (s) {
    case 'square':   return ShapeType.square;
    case 'triangle': return ShapeType.triangle;
    case 'rectangle':return ShapeType.rectangle;
    case 'circle':   return ShapeType.circle;
    default: throw ArgumentError('Unknown shape: $s');
  }
}

ColorId _colorFrom(String s) {
  switch (s) {
    case 'red':    return ColorId.red;
    case 'blue':   return ColorId.blue;
    case 'green':  return ColorId.green;
    case 'yellow': return ColorId.yellow;
    case 'purple': return ColorId.purple;
    case 'orange': return ColorId.orange;
    default: throw ArgumentError('Unknown color: $s');
  }
}

SoundId _soundFrom(String s) {
  switch (s) {
    case 'drums':   return SoundId.drums;
    case 'guitar':  return SoundId.guitar;
    case 'flute': return SoundId.flute;
    case 'piano':   return SoundId.piano;
    default: throw ArgumentError('Unknown sound: $s');
  }
}


GameAction _actionFromJson(Map<String, dynamic> j) {
  final type = j['type'] as String;
  switch (type) {
    case 'spawn':
      return GameAction.spawn(
        j['instanceId'] as String,
        _shapeFrom(j['shape'] as String),
        GridPos(j['pos']['row'] as int, j['pos']['col'] as int),
      );

    case 'move':
      return GameAction.move(
        j['instanceId'] as String,
        GridPos(j['pos']['row'] as int, j['pos']['col'] as int),
      );

    case 'rotate':
      return GameAction.rotate(j['instanceId'] as String, j['quarterTurns'] as int);

    case 'setColor':
      return GameAction.setColor(
        j['instanceId'] as String,
        _colorFrom(j['color'] as String),
      );

    case 'paintCell': // ✅ new
      return GameAction.paintCell(
        GridPos(j['pos']['row'] as int, j['pos']['col'] as int),
        _colorFrom(j['color'] as String),
      );

    case 'playSound':
      return GameAction.playSound(_soundFrom(j['sound'] as String));

    case 'delay':
      return GameAction.delay(j['ms'] as int);

    case 'mirror':
    case 'mirrorBoard':
      // support 'x','y','d' (diagonal) – default to 'x' if missing
      return GameAction.mirror((j['axis'] as String?) ?? 'x');

    default:
      throw ArgumentError('Unknown action type: $type');
  }
}

LoadedLevel loadedLevelFromJson({
  required Map<String, dynamic> j,
  required String worldId,
}) {
  final shapePalette = (j['shapePalette'] as List?)?.cast<String>() ?? const [];
  final colorPalette = (j['colorPalette'] as List?)?.cast<String>() ?? const [];
  final soundPalette = (j['soundPalette'] as List?)?.cast<String>() ?? const [];

  final cfg = LevelConfig(
    worldId: worldId,
    levelId: j['levelId'] as String,
    rows: j['rows'] as int,
    cols: j['cols'] as int,
    shapePalette: shapePalette.map(_shapeFrom).toList(),
    colorPalette: colorPalette.map(_colorFrom).toList(),
    soundPalette: soundPalette.map(_soundFrom).toList(),
    actionCount: j['actionCount'] as int,
    playbackSpeedMs: j['playbackSpeedMs'] as int,
    allowedMistakes: j['allowedMistakes'] as int,
    enableRotation: j['enableRotation'] as bool,
    enableMove: j['enableMove'] as bool,
    enableColor: j['enableColor'] as bool,
    enableSound: j['enableSound'] as bool,
    enableMirror: j['enableMirror'] as bool,
    hideAfterMs: j['hideAfterMs'] as int,
    seed: j['seed'] as int,
  );

  final raw = (j['scriptedActions'] as List?)?.cast<Map>();
  final scriptedList = raw?.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  final scripted = scriptedList == null ? null : scriptedList.map(_actionFromJson).toList();

  return LoadedLevel(cfg: cfg, scripted: scripted);
}
