// lib/engine/actions.dart
import 'types.dart';

enum ActionType { spawn, move, rotate, setColor, playSound, delay, mirrorBoard, paintCell }


class GameAction {
  final ActionType type;
  final String? instanceId;
  final ShapeType? shape;
  final GridPos? pos;
  final int? quarterTurns;
  final ColorId? color;
  final SoundId? sound;
  final int? ms;
  final String? axis; // 'x', 'y', (optionally 'd' for diagonal)

  const GameAction._({
    required this.type,
    this.instanceId,
    this.shape,
    this.pos,
    this.quarterTurns,
    this.color,
    this.sound,
    this.ms,
    this.axis,
  });

  factory GameAction.spawn(String id, ShapeType shape, GridPos at) =>
      GameAction._(type: ActionType.spawn, instanceId: id, shape: shape, pos: at);

  factory GameAction.move(String id, GridPos to) =>
      GameAction._(type: ActionType.move, instanceId: id, pos: to);

  factory GameAction.rotate(String id, int qTurns) =>
      GameAction._(type: ActionType.rotate, instanceId: id, quarterTurns: qTurns % 4);

  factory GameAction.setColor(String id, ColorId color) =>
      GameAction._(type: ActionType.setColor, instanceId: id, color: color);

  factory GameAction.playSound(SoundId s) =>
      GameAction._(type: ActionType.playSound, sound: s);

  factory GameAction.delay(int ms) =>
      GameAction._(type: ActionType.delay, ms: ms);

  factory GameAction.mirror(String axis) =>
      GameAction._(type: ActionType.mirrorBoard, axis: axis);

  factory GameAction.paintCell(GridPos pos, ColorId c) =>
      GameAction._(type: ActionType.paintCell, pos: pos, color: c); // ✅
}
