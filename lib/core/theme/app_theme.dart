import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Competra "Field & Glory" temaları.
///
/// Tüm renkler buradan, [ColorScheme] ve bileşen temaları üzerinden yönetilir.
/// Ekran ve widget'lar renkleri yalnızca `Theme.of(context)` üzerinden almalıdır.
class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(_lightScheme, Brightness.light);
  static ThemeData get dark => _build(_darkScheme, Brightness.dark);

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.primaryGreen,
    onPrimary: AppColors.onDark,
    secondary: AppColors.accentGreen,
    onSecondary: AppColors.backgroundDark,
    tertiary: AppColors.accentGreen,
    onTertiary: AppColors.backgroundDark,
    error: AppColors.error,
    onError: AppColors.onDark,
    surface: AppColors.surfaceDark,
    onSurface: AppColors.onDark,
    surfaceContainerHighest: AppColors.surfaceDark,
    onSurfaceVariant: AppColors.mutedDark,
    outline: AppColors.mutedDark,
  );

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primaryGreen,
    onPrimary: AppColors.surfaceLight,
    secondary: AppColors.accentGreen,
    onSecondary: AppColors.onLight,
    tertiary: AppColors.accentGreen,
    onTertiary: AppColors.onLight,
    error: AppColors.error,
    onError: AppColors.surfaceLight,
    surface: AppColors.surfaceLight,
    onSurface: AppColors.onLight,
    surfaceContainerHighest: AppColors.backgroundLight,
    onSurfaceVariant: AppColors.mutedLight,
    outline: AppColors.mutedLight,
  );

  static ThemeData _build(ColorScheme scheme, Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final Color scaffoldBg =
        isDark ? AppColors.backgroundDark : AppColors.backgroundLight;

    final TextTheme baseText = GoogleFonts.interTextTheme(
      ThemeData(brightness: brightness).textTheme,
    ).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      textTheme: baseText,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outline.withValues(alpha: 0.2),
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.surface,
        contentTextStyle: TextStyle(color: scheme.onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
