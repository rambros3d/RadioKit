import 'package:flutter/material.dart';

/// RadioKit color palette — dark theme inspired by electronics / control panels.
class AppColors {
  AppColors._();

  // Background layers
  static const Color background = Color(0xFF1A1A2E);
  static const Color surface = Color(0xFF16213E);
  static const Color surfaceVariant = Color(0xFF1F2B47);

  // Primary accent
  static const Color primary = Color(0xFF0F3460);
  static const Color primaryLight = Color(0xFF1A4A80);

  // Highlight / active state
  static const Color highlight = Color(0xFFE94560);
  static const Color highlightDim = Color(0xFFB83350);

  // Status indicators
  static const Color connected = Color(0xFF4CAF50);
  static const Color disconnected = Color(0xFFE94560);

  // Text
  static const Color textPrimary = Color(0xFFEEF0F5);
  static const Color textSecondary = Color(0xFF8892A4);
  static const Color textDisabled = Color(0xFF4A526A);

  // Widget-specific
  static const Color widgetCard = Color(0xFF1F2B47);
  static const Color widgetBorder = Color(0xFF2A3A5C);
  static const Color joystickTrack = Color(0xFF0D1A30);
  static const Color joystickThumb = Color(0xFFE94560);

  // LED colors
  static const Color ledOff = Color(0xFF3A3A4A);
  static const Color ledRed = Color(0xFFFF3B3B);
  static const Color ledGreen = Color(0xFF4ADE80);
  static const Color ledBlue = Color(0xFF60A5FA);
  static const Color ledYellow = Color(0xFFFBBF24);

  static Color ledColor(int value) {
    switch (value) {
      case 1:
        return ledRed;
      case 2:
        return ledGreen;
      case 3:
        return ledBlue;
      case 4:
        return ledYellow;
      default:
        return ledOff;
    }
  }
}

/// RadioKit app theme configuration.
class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          background: AppColors.background,
          surface: AppColors.surface,
          primary: AppColors.highlight,
          onPrimary: AppColors.textPrimary,
          secondary: AppColors.primary,
          onSecondary: AppColors.textPrimary,
          error: AppColors.disconnected,
          onBackground: AppColors.textPrimary,
          onSurface: AppColors.textPrimary,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        cardTheme: CardTheme(
          color: AppColors.widgetCard,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.widgetBorder, width: 1),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.highlight,
            foregroundColor: AppColors.textPrimary,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor:
              MaterialStateProperty.resolveWith<Color>((states) {
            if (states.contains(MaterialState.selected)) {
              return AppColors.highlight;
            }
            return AppColors.textDisabled;
          }),
          trackColor:
              MaterialStateProperty.resolveWith<Color>((states) {
            if (states.contains(MaterialState.selected)) {
              return AppColors.highlightDim;
            }
            return AppColors.widgetBorder;
          }),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: AppColors.highlight,
          inactiveTrackColor: AppColors.widgetBorder,
          thumbColor: AppColors.highlight,
          overlayColor: AppColors.highlight.withOpacity(0.2),
          valueIndicatorColor: AppColors.highlight,
          valueIndicatorTextStyle: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(
          color: AppColors.textSecondary,
        ),
        dividerColor: AppColors.widgetBorder,
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
          headlineMedium: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
          titleLarge: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          bodyLarge: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
          ),
          bodyMedium: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
          labelSmall: TextStyle(
            color: AppColors.textDisabled,
            fontSize: 11,
            letterSpacing: 0.8,
          ),
        ),
      );
}
