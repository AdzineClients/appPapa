// lib/engine/mirrors.dart
import 'types.dart';

/// Mirror across the horizontal axis (flip rows).
/// Example on 3x3: (0,1) -> (2,1)
GridPos mirrorX(GridPos p, int rows, int cols) =>
    GridPos(rows - 1 - p.row, p.col);

/// Mirror across the vertical axis (flip columns).
/// Example on 3x3: (1,0) -> (1,2)
GridPos mirrorY(GridPos p, int rows, int cols) =>
    GridPos(p.row, cols - 1 - p.col);

/// Mirror across the MAIN diagonal TL↘︎BR (swap row/col).
/// On a square board: (r,c) -> (c,r).
/// On a rectangular board we clamp to stay within bounds.
GridPos mirrorDiag(GridPos p, int rows, int cols) {
  final r = p.col.clamp(0, rows - 1);
  final c = p.row.clamp(0, cols - 1);
  return GridPos(r, c);
}
