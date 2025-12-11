// lib/audio_controller.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioController {
  static final ValueNotifier<bool> isMuted = ValueNotifier(false);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    isMuted.value = prefs.getBool('isMuted') ?? false;
  }

  static Future<void> toggleMuted() async {
    final prefs = await SharedPreferences.getInstance();
    final newValue = !isMuted.value;
    isMuted.value = newValue;
    await prefs.setBool('isMuted', newValue);
  }
}
