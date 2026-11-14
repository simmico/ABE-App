import 'package:material_ui/material_ui.dart';

import '../config/brand_config.dart';

/// Builds the official Aqeelah's Beauty Empire (ABE) Warm Luxury Theme.
///
/// Implements the "Dusty Rose & Alabaster Studio" colour scheme,
/// Cormorant Garamond editorial headings, Plus Jakarta Sans body/price typography,
/// warm hairline card borders, and pill/rounded-rectangle controls.
abstract final class AbeTheme {
  static ThemeData get lightTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: BrandConfig.rosePrimary,
      onPrimary: BrandConfig.surfaceCard,
      primaryContainer: BrandConfig.blushSoft,
      onPrimaryContainer: BrandConfig.espresso,
      secondary: BrandConfig.champagne,
      onSecondary: BrandConfig.surfaceCard,
      secondaryContainer: BrandConfig.blushSoft,
      onSecondaryContainer: BrandConfig.espresso,
      tertiary: BrandConfig.sageSuccess,
      onTertiary: BrandConfig.surfaceCard,
      error: BrandConfig.errorTerracotta,
      onError: BrandConfig.surfaceCard,
      surface: BrandConfig.surfaceCard,
      onSurface: BrandConfig.espresso,
      onSurfaceVariant: BrandConfig.textMuted,
      outline: BrandConfig.borderWarm,
      outlineVariant: BrandConfig.borderWarm,
    );

    final textTheme = _buildTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: BrandConfig.bgCream,
      canvasColor: BrandConfig.bgCream,
      dividerColor: BrandConfig.borderWarm,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: BrandConfig.bgCream,
        foregroundColor: BrandConfig.espresso,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: BrandConfig.headingFontFamily,
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: BrandConfig.espresso,
        ),
      ),
      cardTheme: CardThemeData(
        color: BrandConfig.surfaceCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BrandConfig.cardRadius),
          side: const BorderSide(color: BrandConfig.borderWarm, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BrandConfig.roseDark,
          foregroundColor: BrandConfig.surfaceCard,
          disabledBackgroundColor: BrandConfig.borderWarm,
          disabledForegroundColor: BrandConfig.textMuted,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BrandConfig.inputRadius),
          ),
          textStyle: const TextStyle(
            fontFamily: BrandConfig.bodyFontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BrandConfig.espresso,
          backgroundColor: BrandConfig.surfaceCard,
          side: const BorderSide(color: Color(0xFFA89592), width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          minimumSize: const Size(48, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BrandConfig.inputRadius),
          ),
          textStyle: const TextStyle(
            fontFamily: BrandConfig.bodyFontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BrandConfig.surfaceCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        labelStyle: const TextStyle(
          fontFamily: BrandConfig.bodyFontFamily,
          color: BrandConfig.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(
          fontFamily: BrandConfig.bodyFontFamily,
          color: BrandConfig.textMuted,
          fontSize: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BrandConfig.inputRadius),
          borderSide: const BorderSide(color: Color(0xFFA89592), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BrandConfig.inputRadius),
          borderSide: const BorderSide(color: BrandConfig.rosePrimary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BrandConfig.inputRadius),
          borderSide: const BorderSide(color: BrandConfig.errorTerracotta, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BrandConfig.inputRadius),
          borderSide: const BorderSide(color: BrandConfig.errorTerracotta, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: BrandConfig.surfaceCard,
        selectedColor: BrandConfig.blushSoft,
        disabledColor: BrandConfig.bgCream,
        labelStyle: const TextStyle(
          fontFamily: BrandConfig.bodyFontFamily,
          color: BrandConfig.espresso,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: BrandConfig.bodyFontFamily,
          color: BrandConfig.espresso,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        side: const BorderSide(color: Color(0xFFA89592), width: 1),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      dividerTheme: const DividerThemeData(
        color: BrandConfig.borderWarm,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static TextTheme _buildTextTheme() {
    return const TextTheme(
      displayLarge: TextStyle(
        fontFamily: BrandConfig.headingFontFamily,
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.15,
        color: BrandConfig.espresso,
      ),
      displayMedium: TextStyle(
        fontFamily: BrandConfig.headingFontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.2,
        color: BrandConfig.espresso,
      ),
      displaySmall: TextStyle(
        fontFamily: BrandConfig.headingFontFamily,
        fontSize: 26,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.25,
        height: 1.25,
        color: BrandConfig.espresso,
      ),
      headlineMedium: TextStyle(
        fontFamily: BrandConfig.headingFontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.3,
        color: BrandConfig.espresso,
      ),
      titleLarge: TextStyle(
        fontFamily: BrandConfig.bodyFontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: BrandConfig.espresso,
      ),
      titleMedium: TextStyle(
        fontFamily: BrandConfig.bodyFontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: BrandConfig.espresso,
      ),
      titleSmall: TextStyle(
        fontFamily: BrandConfig.bodyFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: BrandConfig.espresso,
      ),
      bodyLarge: TextStyle(
        fontFamily: BrandConfig.bodyFontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: BrandConfig.espresso,
      ),
      bodyMedium: TextStyle(
        fontFamily: BrandConfig.bodyFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: BrandConfig.textMuted,
      ),
      bodySmall: TextStyle(
        fontFamily: BrandConfig.bodyFontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: BrandConfig.textMuted,
      ),
      labelLarge: TextStyle(
        fontFamily: BrandConfig.bodyFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.15,
        color: BrandConfig.espresso,
      ),
      labelMedium: TextStyle(
        fontFamily: BrandConfig.bodyFontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: BrandConfig.textMuted,
      ),
    );
  }
}
