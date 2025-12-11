import 'package:flutter/material.dart';

class AppTheme {
  // DARK THEME COLORS (your specs)
  static const Color darkBackground = Color(0xFF070B12);
  static const Color darkSecondary = Color(0xFF11151A);
  static const Color darkAccent = Color(0xFF008EFF);
  static const Color darkText = Colors.white;
  static const Color darkTextVariant = Color(0xFF111123);

  // LIGHT THEME COLORS (simple counterpart)
  static const Color lightBackground = Colors.white;
  static const Color lightSurface = Color(0xFFF4F5F7);
  static const Color lightPrimaryText = Color(0xFF070B12);
  static const Color lightSecondaryText = Color(0xFF65718A);
  static const Color lightAccent = darkAccent; // same accent as dark

  static ThemeData get dark {
    final colorScheme = const ColorScheme.dark(
      brightness: Brightness.dark,
      primary: darkAccent,
      secondary: darkAccent,
      background: darkBackground,
      surface: darkSecondary,
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      onBackground: darkText,
      onSurface: darkText,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: darkText,
        elevation: 0,
        centerTitle: true,
      ),
      cardColor: darkSecondary,
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: darkAccent,
        foregroundColor: Colors.black,
      ),
      iconTheme: const IconThemeData(color: darkAccent),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: darkText),
        bodyMedium: TextStyle(color: darkText),
        bodySmall: TextStyle(color: darkTextVariant),
        labelSmall: TextStyle(color: darkTextVariant),
      ),
    );
  }

  static ThemeData get light {
    final colorScheme = const ColorScheme.light(
      brightness: Brightness.light,
      primary: lightAccent,
      secondary: lightAccent,
      background: lightBackground,
      surface: lightSurface,
      onPrimary: Colors.white,
      onSecondary: lightPrimaryText,
      onBackground: lightPrimaryText,
      onSurface: lightPrimaryText,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        foregroundColor: lightPrimaryText,
        elevation: 0,
        centerTitle: true,
      ),
      cardColor: lightSurface,
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: lightAccent,
        foregroundColor: Colors.white,
      ),
      iconTheme: const IconThemeData(color: lightAccent),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: lightPrimaryText),
        bodyMedium: TextStyle(color: lightPrimaryText),
        bodySmall: TextStyle(color: lightSecondaryText),
        labelSmall: TextStyle(color: lightSecondaryText),
      ),
    );
  }
}