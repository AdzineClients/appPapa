// lib/engine/state.dart
import 'types.dart';

class ShapeInstance {
  final String id;
  final ShapeType type;
  GridPos pos;
  int quarterTurns;
  ColorId? fill;

  ShapeInstance({
    required this.id,
    required this.type,
    required this.pos,
    this.quarterTurns = 0,
    this.fill,
  });

  ShapeInstance copy() => ShapeInstance(
    id: id, type: type, pos: pos, quarterTurns: quarterTurns, fill: fill);
}

class BoardState {
  final int rows, cols;
  final Map<String, ShapeInstance> items = {};

  BoardState(this.rows, this.cols);

  bool occupied(GridPos p) =>
      items.values.any((s) => s.pos.row == p.row && s.pos.col == p.col);
}
