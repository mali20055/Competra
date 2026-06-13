import 'package:flutter/material.dart';

/// Field & Glory renk paleti.
///
/// Bu sabitler yalnızca [AppTheme] içinde [ThemeData] üretmek için kullanılır.
/// Widget'lar renklere doğrudan buradan erişmez; bunun yerine
/// `Theme.of(context).colorScheme` / `Theme.of(context).extension<...>()`
/// üzerinden okur. Böylece hard-code renk kullanımı engellenir.
class AppColors {
  const AppColors._();

  // Dark
  static const Color backgroundDark = Color(0xFF0A1F14);
  static const Color surfaceDark = Color(0xFF0D2B1C);

  // Light
  static const Color backgroundLight = Color(0xFFF0FFF4);
  static const Color surfaceLight = Color(0xFFFFFFFF);

  // Marka renkleri (her iki tema için ortak)
  static const Color primaryGreen = Color(0xFF16A34A);
  static const Color accentGreen = Color(0xFF4ADE80);

  // Durum renkleri
  static const Color error = Color(0xFFEF4444);

  // Nötr yardımcı tonlar
  static const Color onDark = Color(0xFFF0FFF4);
  static const Color onLight = Color(0xFF0A1F14);
  static const Color mutedDark = Color(0xFF7C9A88);
  static const Color mutedLight = Color(0xFF5B7A67);
}
