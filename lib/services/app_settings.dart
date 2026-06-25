import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uygulama genelinde aktif tema modunu yöneten Notifier.
///
/// Varsayılan koyu temadır. Ayarlar ekranındaki anahtar bu notifier'ı
/// güncelleyerek tüm uygulamanın temasını değiştirir.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  void set(ThemeMode mode) => state = mode;

  void toggle() => state =
      state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class LocaleNotifier extends Notifier<Locale?> {
  static const String _localeKey = 'selected_locale';

  @override
  Locale? build() {
    loadSavedLocale();
    return null;
  }

  Future<void> setLocale(Locale? locale) async {
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_localeKey);
    } else {
      await prefs.setString(_localeKey, locale.languageCode);
    }
    state = locale;
  }

  Future<void> loadSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_localeKey);
      if (code != null) {
        state = Locale(code);
      }
    } catch (_) {}
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(
  LocaleNotifier.new,
);
