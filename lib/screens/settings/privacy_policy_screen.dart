import 'package:flutter/material.dart';

/// Gizlilik Politikası ekranı.
///
/// Uygulamanın hangi verileri topladığını, nasıl kullandığını ve kullanıcı
/// haklarını sade bir dille açıklar. Tüm renkler tema üzerinden gelir.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  /// İletişim e-posta adresi.
  static const String contactEmail = 'destek@competra.app';

  /// Politikanın son güncellenme tarihi.
  static const String lastUpdated = '21 Haziran 2026';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Gizlilik Politikası')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            'Gizliliğin bizim için önemli. Bu politika, Competra\'yı '
            'kullanırken hangi verilerin toplandığını ve nasıl kullanıldığını '
            'açıklar.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          _Section(
            title: 'Hangi veriler toplanıyor?',
            children: const [
              _Bullet('E-posta adresi ve kullanıcı adı'),
              _Bullet('Profil fotoğrafı ve kapak fotoğrafı (isteğe bağlı)'),
              _Bullet('Turnuva, maç ve skor verileri'),
              _Bullet(
                'Cihaz ve kullanım bilgileri (Firebase Analytics / Crashlytics '
                'aracılığıyla, çökme ve performans için)',
              ),
            ],
          ),

          _Section(
            title: 'Veriler nasıl kullanılıyor?',
            children: const [
              _Bullet('Hesabını oluşturmak ve oturumunu yönetmek için'),
              _Bullet(
                'Turnuvalarını, maçlarını ve istatistiklerini saklamak ve '
                'göstermek için',
              ),
              _Bullet('Arkadaşlarınla bağlantı kurman ve sıralamalar için'),
              _Bullet(
                'Uygulamanın hatalarını gidermek ve deneyimi iyileştirmek için',
              ),
            ],
          ),

          _Section(
            title: 'Veriler kimlerle paylaşılıyor?',
            children: const [
              _Bullet(
                'Verilerin, altyapı sağlayıcımız Google Firebase '
                '(kimlik doğrulama, veritabanı, depolama, analitik) üzerinde '
                'barındırılır.',
              ),
              _Bullet(
                'Verilerini üçüncü taraflara satmıyoruz veya reklam amacıyla '
                'paylaşmıyoruz.',
              ),
            ],
          ),

          _Section(
            title: 'Veri silme hakkın',
            children: const [
              _Bullet(
                'İstediğin zaman Ayarlar > Hesabı Sil ile hesabını ve tüm '
                'verilerini (turnuvalar, istatistikler, rozetler, fotoğraflar) '
                'kalıcı olarak silebilirsin.',
              ),
              _Bullet(
                'Hesap silindiğinde bu işlem geri alınamaz.',
              ),
            ],
          ),

          _Section(
            title: 'İletişim',
            children: const [
              _Bullet(
                'Gizlilikle ilgili sorularını $contactEmail adresine '
                'iletebilirsin.',
              ),
            ],
          ),

          const SizedBox(height: 8),
          Text(
            'Son güncelleme: $lastUpdated',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7, right: 10),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
