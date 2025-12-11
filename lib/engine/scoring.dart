// lib/engine/scoring.dart
class ScoreResult {
  final int timeMs;
  final int errors;
  final int stars; // 0-3
  const ScoreResult(this.timeMs, this.errors, this.stars);
}

ScoreResult computeScore({
  required int timeMs,
  required int errors,
  required int actionCount,
}) {
  int stars = 1;
  if (errors == 0 && timeMs <= actionCount * 1000) stars = 3;
  else if (errors <= 1) stars = 2;
  return ScoreResult(timeMs, errors, stars);
}
