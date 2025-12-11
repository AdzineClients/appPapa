// lib/engine/types.dart
enum ShapeType { square, triangle, rectangle, circle, circleOutline, squareOutline, rectangleOutline, triangleOutline }
enum ColorId   { red, blue, green, yellow, purple, orange, ligthBlue, pink }
enum SoundId   { drums, flute, guitar, piano }

class GridPos {
  final int row, col;
  const GridPos(this.row, this.col);
  @override String toString() => '($row,$col)';
}

extension GridPosExt on GridPos {
  bool inside(int rows, int cols) =>
      row >= 0 && row < rows && col >= 0 && col < cols;
}
