import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppThemeId { fieldAndGlory, nightArena, goldTrophy, oceanLeague }

class AppThemeConfig {
  final AppThemeId id;
  final String name;
  final bool isPremium;
  final ColorScheme lightScheme;
  final ColorScheme darkScheme;

  const AppThemeConfig({
    required this.id,
    required this.name,
    required this.isPremium,
    required this.lightScheme,
    required this.darkScheme,
  });
}

class AppThemes {
  const AppThemes._();

  // Dark Green Colors
  static const Color backgroundDark = Color(0xFF0A1F14);
  static const Color surfaceDark = Color(0xFF0D2B1C);

  // Light Green Colors
  static const Color backgroundLight = Color(0xFFF0FFF4);
  static const Color surfaceLight = Color(0xFFFFFFFF);

  // Green Brand Colors
  static const Color primaryGreen = Color(0xFF16A34A);
  static const Color accentGreen = Color(0xFF4ADE80);

  // Neutral Greenish
  static const Color mutedDark = Color(0xFF7C9A88);
  static const Color mutedLight = Color(0xFF5B7A67);

  static final Map<AppThemeId, AppThemeConfig> themes = {
    AppThemeId.fieldAndGlory: AppThemeConfig(
      id: AppThemeId.fieldAndGlory,
      name: 'Saha & Zafer (Yeşil)',
      isPremium: false,
      lightScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primaryGreen,
        onPrimary: Colors.white,
        secondary: accentGreen,
        onSecondary: Color(0xFF0A1F14),
        tertiary: accentGreen,
        onTertiary: Color(0xFF0A1F14),
        error: Color(0xFFEF4444),
        onError: Colors.white,
        surface: Colors.white,
        onSurface: Color(0xFF0A1F14),
        surfaceContainerHighest: Color(0xFFF0FFF4),
        onSurfaceVariant: Color(0xFF5B7A67),
        outline: Color(0xFF5B7A67),
      ),
      darkScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: primaryGreen,
        onPrimary: Color(0xFFF0FFF4),
        secondary: accentGreen,
        onSecondary: Color(0xFF0A1F14),
        tertiary: accentGreen,
        onTertiary: Color(0xFF0A1F14),
        error: Color(0xFFEF4444),
        onError: Color(0xFFF0FFF4),
        surface: Color(0xFF0D2B1C),
        onSurface: Color(0xFFF0FFF4),
        surfaceContainerHighest: Color(0xFF0D2B1C),
        onSurfaceVariant: Color(0xFF7C9A88),
        outline: Color(0xFF7C9A88),
      ),
    ),
    AppThemeId.nightArena: AppThemeConfig(
      id: AppThemeId.nightArena,
      name: 'Gece Arenası (Mor)',
      isPremium: true,
      lightScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFF7B2FBE),
        onPrimary: Colors.white,
        secondary: Color(0xFF3D0066),
        onSecondary: Colors.white,
        tertiary: Color(0xFF9C27B0),
        onTertiary: Colors.white,
        error: Color(0xFFEF4444),
        onError: Colors.white,
        surface: Colors.white,
        onSurface: Color(0xFF0A0010),
        surfaceContainerHighest: Color(0xFFF3E5F5),
        onSurfaceVariant: Color(0xFF6A1B9A),
        outline: Color(0xFF6A1B9A),
      ),
      darkScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFF7B2FBE),
        onPrimary: Colors.white,
        secondary: Color(0xFF3D0066),
        onSecondary: Colors.white,
        tertiary: Color(0xFF9C27B0),
        onTertiary: Colors.white,
        error: Color(0xFFEF4444),
        onError: Colors.white,
        surface: Color(0xFF0A0010),
        onSurface: Colors.white,
        surfaceContainerHighest: Color(0xFF0A0010),
        onSurfaceVariant: Color(0xFFE1BEE7),
        outline: Color(0xFF9C27B0),
      ),
    ),
    AppThemeId.goldTrophy: AppThemeConfig(
      id: AppThemeId.goldTrophy,
      name: 'Altın Kupa (Altın/Koyu)',
      isPremium: true,
      lightScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFFFFB300),
        onPrimary: Colors.black,
        secondary: Color(0xFFFF6F00),
        onSecondary: Colors.white,
        tertiary: Color(0xFFFF8F00),
        onTertiary: Colors.black,
        error: Color(0xFFEF4444),
        onError: Colors.white,
        surface: Colors.white,
        onSurface: Color(0xFF1A1200),
        surfaceContainerHighest: Color(0xFFFFF8E1),
        onSurfaceVariant: Color(0xFF8D6E63),
        outline: Color(0xFF8D6E63),
      ),
      darkScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFFFFB300),
        onPrimary: Colors.black,
        secondary: Color(0xFFFF6F00),
        onSecondary: Colors.white,
        tertiary: Color(0xFFFF8F00),
        onTertiary: Colors.black,
        error: Color(0xFFEF4444),
        onError: Colors.white,
        surface: Color(0xFF1A1200),
        onSurface: Colors.white,
        surfaceContainerHighest: Color(0xFF1A1200),
        onSurfaceVariant: Color(0xFFFFECB3),
        outline: Color(0xFFFFB300),
      ),
    ),
    AppThemeId.oceanLeague: AppThemeConfig(
      id: AppThemeId.oceanLeague,
      name: 'Okyanus Ligi (Mavi/Deniz)',
      isPremium: true,
      lightScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFF0277BD),
        onPrimary: Colors.white,
        secondary: Color(0xFF00897B),
        onSecondary: Colors.white,
        tertiary: Color(0xFF00ACC1),
        onTertiary: Colors.white,
        error: Color(0xFFEF4444),
        onError: Colors.white,
        surface: Colors.white,
        onSurface: Color(0xFF001529),
        surfaceContainerHighest: Color(0xFFE0F7FA),
        onSurfaceVariant: Color(0xFF00695C),
        outline: Color(0xFF00695C),
      ),
      darkScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFF0277BD),
        onPrimary: Colors.white,
        secondary: Color(0xFF00897B),
        onSecondary: Colors.white,
        tertiary: Color(0xFF00ACC1),
        onTertiary: Colors.white,
        error: Color(0xFFEF4444),
        onError: Colors.white,
        surface: Color(0xFF001529),
        onSurface: Colors.white,
        surfaceContainerHighest: Color(0xFF001529),
        onSurfaceVariant: Color(0xFFB2DFDB),
        outline: Color(0xFF00897B),
      ),
    ),
  };

  static ThemeData getTheme(AppThemeId id, Brightness brightness) {
    final config = themes[id] ?? themes[AppThemeId.fieldAndGlory]!;
    final scheme = brightness == Brightness.dark ? config.darkScheme : config.lightScheme;
    
    final Color scaffoldBg = brightness == Brightness.dark 
        ? (id == AppThemeId.fieldAndGlory ? backgroundDark : scheme.surface)
        : (id == AppThemeId.fieldAndGlory ? backgroundLight : scheme.surfaceContainerHighest);

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
