import 'package:flutter/material.dart';

class AppColors {
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF1F2937);
  static const Color lightTextSecondary = Color(0xFF6B7280);
  static const Color lightBorder = Color(0xFFD1FAE5);
  static const Color lightInputBackground = Color(0xFFF0FDF4);
  static const Color lightPrimary = Color(0xFF10B981);
  static const Color lightSecondary = Color(0xFFEF4444);
  static const Color lightIconColor = Color(0xFF059669);
  static const Color lightDivider = Color(0xFFD1FAE5);

  static const Color darkBackground = Color(0xFF080808);
  static const Color darkSurface = Color(0xFF121212);
  static const Color darkSurfaceVariant = Color(0xFF1A1A1A);
  static const Color darkText = Color(0xFFE8E8E8);
  static const Color darkTextSecondary = Color(0xFFA8A8A8);
  static const Color darkBorder = Color(0xFF1A1A1A);
  static const Color darkInputBackground = Color(0xFF121212);
  static const Color darkPrimary = Color(0xFFE0E0E0);
  static const Color darkPrimaryVariant = Color(0xFFB0B0B0);
  static const Color darkSecondary = Color(0xFF808080);
  static const Color darkIconColor = Color(0xFFE0E0E0);
  static const Color darkDivider = Color(0xFF1A1A1A);
  static const Color darkError = Color(0xFFCF6679);
}

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBackground,
    primaryColor: AppColors.lightPrimary,
    fontFamily: 'Roboto',
    textTheme: const TextTheme(
      labelLarge: TextStyle(
        fontSize: 12,
      ),
    ),
    colorScheme: const ColorScheme.light(
      primary: AppColors.lightPrimary,
      secondary: AppColors.lightSecondary,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightInputBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightPrimary, width: 2),
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,
    primaryColor: AppColors.darkPrimary,
    fontFamily: 'Inter',
    textTheme: const TextTheme(
      labelLarge: TextStyle(
        fontSize: 12,
      ),
    ),
    colorScheme: const ColorScheme.dark(
      primary: AppColors.darkPrimary,
      secondary: AppColors.darkSecondary,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkInputBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.darkPrimary, width: 2),
      ),
    ),
  );
}