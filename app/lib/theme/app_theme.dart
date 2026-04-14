import 'package:flutter/material.dart';

/// RadioKit color palette — built from the brand logo.
class AppColors {
  AppColors._();

  // --- BRAND COLORS ---
  static const Color brandCharcoal = Color(0xFF3A3939); // Primary Dark
  static const Color brandOrange = Color(0xFFF57A06);   // Brand Accent
  static const Color brandWhite = Color(0xFFFCFCFC);    // Base Light

  // --- UI SEMANTIC COLORS ---
  static const Color brandBlue = Color(0xFF0680F5);     // Secondary Blue
  static const Color brandYellow = Color(0xFFF5F106);   // Warning Yellow
  static const Color brandRed = Color(0xFFF50609);      // Danger Red
  static const Color brandGray = Color(0xFF908E8E);     // Neutral Gray

  // --- STATUS INDICATORS ---
  static const Color connected = Color(0xFF4CAF50);    // Harmonious green
  static const Color disconnected = brandRed;

  // --- LED COLORS (Hardware config based) ---
  static const Color ledOff = Color(0xFF3A3A4A);
  static const Color ledRed = Color(0xFFFF3B3B);
  static const Color ledGreen = Color(0xFF4ADE80);
  static const Color ledBlue = Color(0xFF60A5FA);
  static const Color ledYellow = Color(0xFFFBBF24);

  static Color ledColor(int value) {
    switch (value) {
      case 1: return ledRed;
      case 2: return ledGreen;
      case 3: return ledBlue;
      case 4: return ledYellow;
      default: return ledOff;
    }
  }

  // --- DYNAMIC HELPERS ---
  static Color dynamicSurface(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF454444) : Colors.white;

  static Color dynamicBackground(Brightness b) =>
      b == Brightness.dark ? brandCharcoal : brandWhite;

  static Color dynamicTextPrimary(Brightness b) =>
      b == Brightness.dark ? brandWhite : brandCharcoal;

  static Color dynamicTextSecondary(Brightness b) => brandGray;

  static Color dynamicBorder(Brightness b) =>
      b == Brightness.dark ? Colors.white10 : Colors.black12;

  // --- SEMANTIC ALIASES (For widget compatibility) ---
  static const Color primary = brandOrange;
  static const Color highlight = brandOrange;
  static const Color highlightDim = Color(0x33F57A06);
  static const Color widgetCard = Color(0xFF454444);
  static const Color widgetBorder = Colors.white10;
  static const Color joystickTrack = Color(0xFF2A2929);
  static const Color joystickThumb = brandOrange;
  static const Color textDisabled = brandGray;

  // Static property versions
  static const Color surface = Color(0xFF454444);
  static const Color background = brandCharcoal;
  static const Color textPrimary = brandWhite;
  static const Color textSecondary = brandGray;
}

/// RadioKit app theme configuration.
class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    
    // Core colors based on mode
    final bg = AppColors.dynamicBackground(brightness);
    final surface = AppColors.dynamicSurface(brightness);
    final surfaceVariant = isDark ? const Color(0xFF2D2D2D) : Colors.grey[200]!;
    final text = AppColors.dynamicTextPrimary(brightness);
    final secondaryText = AppColors.dynamicTextSecondary(brightness);
    final border = AppColors.dynamicBorder(brightness);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brandOrange,
        brightness: brightness,
        primary: AppColors.brandOrange,
        onPrimary: Colors.white,
        secondary: AppColors.brandBlue,
        error: AppColors.brandRed,
        surface: surface,
        onSurface: text,
        surfaceVariant: surfaceVariant,
      ),
      scaffoldBackgroundColor: bg,
      dividerColor: border,
      disabledColor: isDark ? const Color(0xFF666666) : const Color(0xFFAAAAAA),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: isDark ? 4 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandOrange,
          foregroundColor: Colors.white,
          elevation: isDark ? 4 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.brandOrange;
          }
          return isDark ? Colors.grey[600]! : Colors.grey[400]!;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.brandOrange.withOpacity(0.5);
          }
          return border;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.brandOrange,
        inactiveTrackColor: border,
        thumbColor: AppColors.brandOrange,
        overlayColor: AppColors.brandOrange.withOpacity(0.2),
        valueIndicatorColor: AppColors.brandOrange,
        valueIndicatorTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      iconTheme: IconThemeData(
        color: secondaryText,
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          color: text,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: text,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: text,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: text,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          color: text,
          fontSize: 15,
        ),
        bodyMedium: TextStyle(
          color: secondaryText,
          fontSize: 14,
        ),
        labelSmall: TextStyle(
          color: secondaryText.withOpacity(0.7),
          fontSize: 11,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
