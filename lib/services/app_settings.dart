import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
