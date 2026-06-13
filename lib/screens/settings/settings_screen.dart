import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/route_paths.dart';
import '../../services/app_settings.dart';
import '../../services/firebase_providers.dart';

/// Ayarlar ekranı: tema (açık/koyu) anahtarı ve oturum kapatma.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionLabel('Görünüm'),
          Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
            ),
            child: SwitchListTile(
              value: isDark,
              onChanged: (value) {
                ref.read(themeModeProvider.notifier).set(
                      value ? ThemeMode.dark : ThemeMode.light,
                    );
              },
              secondary: Icon(
                isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                color: scheme.primary,
              ),
              title: const Text('Koyu Tema'),
              subtitle: Text(
                isDark ? 'Koyu görünüm açık' : 'Açık görünüm açık',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel('Hesap'),
          Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
            ),
            child: ListTile(
              leading: Icon(Icons.logout, color: scheme.error),
              title: Text(
                'Çıkış Yap',
                style: TextStyle(
                  color: scheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => _confirmSignOut(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Oturumu kapatmak istediğine emin misin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Çıkış Yap',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(firebaseAuthProvider).signOut();
    if (context.mounted) {
      context.goNamed(RoutePaths.loginName);
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
