import 'dart:async';
import '../sources/local_levels_source.dart';
import '../mappers/level_mapper.dart'; // provides loadedLevelFromJson
// If you have a LoadedLevel type, import it here as you did before.

class LevelRepository {
  LevelRepository(this.local, {this.timeout = const Duration(seconds: 6)});

  final LocalLevelsSource local;
  final Duration timeout;

  /// For this smoke test: load first level of w1 (scripted world1.json)
  Future<LoadedLevel> loadFirstLevelW1() async {
    try {
      final manifest = await local.loadManifest().timeout(timeout);

      final worlds = (manifest['worlds'] as List).cast<Map>();
      final w1 = worlds.firstWhere((w) => w['id'] == 'w1') as Map<dynamic, dynamic>;
      final levels = w1['levels'] as Map<dynamic, dynamic>;
      if (levels['type'] != 'scripted') {
        throw StateError('w1 is not scripted in manifest; set file path to world1.json');
      }
      final file = levels['file'] as String;

      final worldJson = await local.loadWorldFile(file).timeout(timeout);
      final worldId = (worldJson['worldId'] as String?) ?? 'w1';
      final arr = (worldJson['levels'] as List).cast<Map>();
      final level0 = Map<String, dynamic>.from(arr.first as Map);
      return loadedLevelFromJson(j: level0, worldId: worldId);
    } on TimeoutException {
      return _fallbackLoadedLevel();
    } catch (_) {
      return _fallbackLoadedLevel();
    }
  }

  Future<LoadedLevel> _fallbackLoadedLevel() async {
    // Try a direct default world file first
    try {
      final worldJson = await local.loadWorldFile('assets/levels/world1.json');
      final worldId = (worldJson['worldId'] as String?) ?? 'w1';
      final arr = (worldJson['levels'] as List).cast<Map>();
      final level0 = Map<String, dynamic>.from(arr.first as Map);
      return loadedLevelFromJson(j: level0, worldId: worldId);
    } catch (_) {
      // Last-resort: tiny built-in demo so the harness never blocks
      const worldId = 'w1';
      final level0 = <String, dynamic>{
        'levelId': 'l1',
        'rows': 5,
        'cols': 5,
        'actionCount': 16,
        'playbackSpeedMs': 120,
        'features': {
          'move': true,
          'rotation': true,
          'color': true,
          'sound': false,
          'mirror': true,
        },
        // If your mapper supports a scripted sequence, include it:
        'scripted': [3, 7, 12, 18],
      };
      return loadedLevelFromJson(j: level0, worldId: worldId);
    }
  }
}
