import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class LocalLevelsSource {
  const LocalLevelsSource({this.timeout = const Duration(seconds: 6)});
  final Duration timeout;

  Future<Map<String, dynamic>> loadManifest() async {
    try {
      final s = await rootBundle
          .loadString('assets/levels/manifest.json')
          .timeout(timeout);
      return jsonDecode(s) as Map<String, dynamic>;
    } on TimeoutException {
      return _defaultManifest();
    } catch (_) {
      return _defaultManifest();
    }
  }

  Future<Map<String, dynamic>> loadWorldFile(String path) async {
    // 1) Try the requested path
    try {
      final s = await rootBundle.loadString(path).timeout(timeout);
      return jsonDecode(s) as Map<String, dynamic>;
    } on TimeoutException {
      // 2) Try the default world file
      return _loadDefaultWorldOrDemo();
    } catch (_) {
      // 2) Try the default world file, then demo
      return _loadDefaultWorldOrDemo();
    }
  }

  Future<Map<String, dynamic>> _loadDefaultWorldOrDemo() async {
    try {
      final s = await rootBundle
          .loadString('assets/levels/world1.json')
          .timeout(timeout);
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      // 3) Last-resort demo world structure
      return {
        'worldId': 'w1',
        'levels': [
          {
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
            'scripted': [3, 7, 12, 18],
          }
        ],
      };
    }
  }

  Map<String, dynamic> _defaultManifest() => {
        'worlds': [
          {
            'id': 'w1',
            'levels': {
              'type': 'scripted',
              'file': 'assets/levels/world1.json',
            },
          },
        ],
      };
}
