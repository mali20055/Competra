import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_themes.dart';

class ThemeNotifier extends Notifier<AppThemeId> {
  static const String _themeKey = 'selected_theme_id';

  @override
  AppThemeId build() {
    loadSavedTheme();
    return AppThemeId.fieldAndGlory;
  }

  Future<void> setTheme(AppThemeId id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, id.name);
    state = id;
  }

  Future<void> loadSavedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeName = prefs.getString(_themeKey);
      if (themeName != null) {
        state = AppThemeId.values.byName(themeName);
      }
    } catch (_) {
      // Hata durumunda varsayılan temada kalır
    }
  }
}

final themeNotifierProvider = NotifierProvider<ThemeNotifier, AppThemeId>(
  ThemeNotifier.new,
);
