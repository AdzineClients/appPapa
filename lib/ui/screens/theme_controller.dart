import 'package:flutter/material.dart';

class ThemeController {
  ThemeController._();

  static final ValueNotifier<ThemeMode> mode =
  ValueNotifier<ThemeMode>(ThemeMode.system);

  static void setDark(bool isDark) {
    mode.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  static void setSystem() {
    mode.value = ThemeMode.system;
  }

  static void toggle() {
    mode.value =
    mode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }
}
