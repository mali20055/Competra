import 'package:flutter/material.dart';

/// [BuildContext] üzerinden hızlı SnackBar gösterimleri.
extension BuildContextX on BuildContext {
  /// Hata mesajını tema `error` renkleriyle gösterir.
  void showError(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: Theme.of(this).colorScheme.onError),
        ),
        backgroundColor: Theme.of(this).colorScheme.error,
      ),
    );
  }

  /// Başarı/bilgi mesajını varsayılan SnackBar ile gösterir.
  void showSuccess(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
