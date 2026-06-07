// lib/core/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  // Premium color palette
  static const Color primaryColor = Color(0xFF6C63FF);
  static const Color accentColor = Color(0xFFFF6B6B);
  static const Color successColor = Color(0xFF4ECDC4);
  
  // Dark theme colors
  static const Color darkBg = Color(0xFF0D0D0F);
  static const Color darkSurface = Color(0xFF1A1A1F);
  static const Color darkCard = Color(0xFF242429);
  static const Color darkBorder = Color(0xFF2E2E35);
  static const Color darkText = Color(0xFFE8E8F0);
  static const Color darkTextSecondary = Color(0xFF8888A0);

  // Light theme colors  
  static const Color lightBg = Color(0xFFF5F5FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFAFAFF);
  static const Color lightBorder = Color(0xFFE8E8F0);
  static const Color lightText = Color(0xFF1A1A2E);
  static const Color lightTextSecondary = Color(0xFF666680);

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'HarmonyOS',
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: accentColor,
        tertiary: successColor,
        surface: darkSurface,
        background: darkBg,
        onPrimary: Colors.white,
        onSurface: darkText,
        onBackground: darkText,
        outline: darkBorder,
      ),
      scaffoldBackgroundColor: darkBg,
      cardColor: darkCard,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: darkText,
        titleTextStyle: TextStyle(
          color: darkText,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        indicatorColor: primaryColor.withOpacity(0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.w600);
          }
          return const TextStyle(color: darkTextSecondary, fontSize: 11);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryColor, size: 24);
          }
          return const IconThemeData(color: darkTextSecondary, size: 22);
        }),
      ),
      dividerColor: darkBorder,
      textTheme: _buildTextTheme(darkText, darkTextSecondary),
    );
  }

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'HarmonyOS',
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: accentColor,
        tertiary: successColor,
        surface: lightSurface,
        background: lightBg,
        onPrimary: Colors.white,
        onSurface: lightText,
        onBackground: lightText,
        outline: lightBorder,
      ),
      scaffoldBackgroundColor: lightBg,
      cardColor: lightCard,
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBg,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        foregroundColor: lightText,
        shadowColor: Color(0x20000000),
        titleTextStyle: TextStyle(
          color: lightText,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightSurface,
        indicatorColor: primaryColor.withOpacity(0.12),
        shadowColor: Colors.black12,
        elevation: 8,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.w600);
          }
          return TextStyle(color: lightTextSecondary, fontSize: 11);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryColor, size: 24);
          }
          return IconThemeData(color: lightTextSecondary, size: 22);
        }),
      ),
      dividerColor: lightBorder,
      textTheme: _buildTextTheme(lightText, lightTextSecondary),
    );
  }

  static TextTheme _buildTextTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: TextStyle(color: primary, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -1.0),
      displayMedium: TextStyle(color: primary, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.8),
      headlineLarge: TextStyle(color: primary, fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.5),
      headlineMedium: TextStyle(color: primary, fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.3),
      headlineSmall: TextStyle(color: primary, fontSize: 18, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: primary, fontSize: 16, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: primary, fontSize: 14, fontWeight: FontWeight.w500),
      titleSmall: TextStyle(color: secondary, fontSize: 13, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(color: primary, fontSize: 15, height: 1.6),
      bodyMedium: TextStyle(color: primary, fontSize: 14, height: 1.5),
      bodySmall: TextStyle(color: secondary, fontSize: 12, height: 1.4),
      labelLarge: TextStyle(color: primary, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3),
      labelMedium: TextStyle(color: secondary, fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall: TextStyle(color: secondary, fontSize: 11, letterSpacing: 0.2),
    );
  }
}
