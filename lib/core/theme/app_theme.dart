import 'package:flutter/material.dart';
import 'app_themes.dart';

/// Competra "Field & Glory" temaları (Geriye dönük uyumluluk için proxy).
class AppTheme {
  const AppTheme._();

  static ThemeData get light => AppThemes.getTheme(AppThemeId.fieldAndGlory, Brightness.light);
  static ThemeData get dark => AppThemes.getTheme(AppThemeId.fieldAndGlory, Brightness.dark);
}
