/// Form alanları için ortak doğrulama fonksiyonları.
///
/// Tümü geçerli durumda `null`, hatalı durumda Türkçe hata mesajı döner.
class Validators {
  const Validators._();

  static final RegExp _usernamePattern = RegExp(r'^[A-Za-z0-9_]+$');
  static final RegExp _emailPattern =
      RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  /// Kullanıcı adı: boş olamaz, en az 3 karakter, yalnızca harf/rakam/alt çizgi.
  static String? username(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Kullanıcı adı gerekli';
    if (text.length < 3) return 'En az 3 karakter olmalı';
    if (!_usernamePattern.hasMatch(text)) {
      return 'Sadece harf, rakam ve alt çizgi kullanılabilir';
    }
    return null;
  }

  /// E-posta: boş olamaz ve geçerli bir e-posta biçiminde olmalı.
  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'E-posta gerekli';
    if (!_emailPattern.hasMatch(text)) return 'Geçerli bir e-posta gir';
    return null;
  }

  /// Şifre: boş olamaz, en az 6 karakter.
  static String? password(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Şifre gerekli';
    if (text.length < 6) return 'En az 6 karakter olmalı';
    return null;
  }

  /// Şifre tekrarı: boş olamaz ve [original] ile eşleşmeli.
  static String? confirmPassword(String? value, String original) {
    final text = value ?? '';
    if (text.isEmpty) return 'Şifre tekrarı gerekli';
    if (text != original) return 'Şifreler eşleşmiyor';
    return null;
  }
}
