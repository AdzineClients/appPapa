// lib/engine/rng.dart
import 'dart:math';

class Rng {
  final Random _r;
  Rng(int seed) : _r = Random(seed);

  int nextInt(int max) => _r.nextInt(max);
  double nextDouble() => _r.nextDouble();
  bool chance(double p) => _r.nextDouble() < p;

  T choice<T>(List<T> list) => list[_r.nextInt(list.length)];
  void shuffle<T>(List<T> list) {
    for (int i = list.length - 1; i > 0; i--) {
      final j = _r.nextInt(i + 1);
      final tmp = list[i]; list[i] = list[j]; list[j] = tmp;
    }
  }

  /// Derive a *run seed* so each attempt is different, while difficulty stays.
  static int runSeed({
    required int baseSeed,
    required int attemptIndex, // 0,1,2,... store per-user in progress
    int salt = 0x9E3779B9,     // golden ratio prime
  }) {
    // Simple 32-bit mix
    int x = baseSeed ^ (attemptIndex * 1103515245) ^ salt;
    x ^= (x << 13); x ^= (x >> 17); x ^= (x << 5);
    return x & 0x7fffffff;
  }
}
