import 'types.dart';

class LevelConfig {
  final String worldId, levelId;
  final int rows, cols;

  final List<ShapeType> shapePalette;
  final List<ColorId>   colorPalette;
  final List<SoundId>   soundPalette;

  final int actionCount;
  final int playbackSpeedMs;
  final int allowedMistakes;

  final bool enableRotation;
  final bool enableMove;
  final bool enableColor;
  final bool enableSound;
  final bool enableMirror;

  /// If > 0, board hides after demo (memory mode).
  final int hideAfterMs;

  /// Base seed defines the difficulty identity of the level.
  /// A per-attempt run seed is derived elsewhere so the sequence changes.
  final int seed;

  const LevelConfig({
    required this.worldId,
    required this.levelId,
    required this.rows,
    required this.cols,
    required this.shapePalette,
    required this.colorPalette,
    required this.soundPalette,
    required this.actionCount,
    required this.playbackSpeedMs,
    required this.allowedMistakes,
    required this.enableRotation,
    required this.enableMove,
    required this.enableColor,
    required this.enableSound,
    required this.enableMirror,
    required this.hideAfterMs,
    required this.seed,
  });

  // 🔹 Aliases used by the game screen / upgrade logic
  List<ColorId> get allowedColors => colorPalette;
  List<ShapeType> get allowedShapes => shapePalette;
  List<SoundId> get allowedSounds => soundPalette;
}