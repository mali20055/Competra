import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/route_paths.dart';
import '../../services/app_settings.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_providers.dart';
import '../../l10n/app_localizations.dart';

/// Ayarlar ekranı: tema (açık/koyu) anahtarı, dil seçimi, gizlilik politikası,
/// oturum kapatma ve hesap silme.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final l10n = AppLocalizations.of(context);
    final selectedLocale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionLabel(l10n.appearance),
          _Card(
            child: Column(
              children: [
                SwitchListTile(
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
                  title: Text(l10n.darkTheme),
                  subtitle: Text(
                    isDark ? l10n.darkThemeEnabled : l10n.lightThemeEnabled,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.palette_outlined, color: scheme.primary),
                  title: Text(l10n.themesAndCosmetics),
                  subtitle: Text(l10n.themesAndCosmeticsDesc),
                  trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                  onTap: () => context.pushNamed(RoutePaths.themeName),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: DropdownButtonFormField<Locale?>(
                    initialValue: selectedLocale,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.language, color: scheme.primary),
                      labelText: l10n.language,
                      border: InputBorder.none,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(l10n.deviceLanguage),
                      ),
                      const DropdownMenuItem(
                        value: Locale('tr'),
                        child: Text('🇹🇷 Türkçe'),
                      ),
                      const DropdownMenuItem(
                        value: Locale('en'),
                        child: Text('🇬🇧 English'),
                      ),
                    ],
                    onChanged: (locale) {
                      ref.read(localeProvider.notifier).setLocale(locale);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _SectionLabel(l10n.general),
          _Card(
            child: ListTile(
              leading: Icon(Icons.privacy_tip_outlined, color: scheme.primary),
              title: Text(l10n.privacyPolicy),
              trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              onTap: () => context.pushNamed(RoutePaths.privacyPolicyName),
            ),
          ),
          const SizedBox(height: 24),

          _SectionLabel(l10n.subscription),
          _Card(
            child: ListTile(
              leading: const Icon(Icons.workspace_premium, color: Color(0xFFFFD700)),
              title: const Text('Competra Pro'),
              subtitle: Text(l10n.proSubscriptionDesc),
              trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              onTap: () => context.pushNamed(RoutePaths.premiumName),
            ),
          ),
          const SizedBox(height: 24),

          _SectionLabel(l10n.account),
          _Card(
            child: ListTile(
              leading: Icon(Icons.logout, color: scheme.error),
              title: Text(
                l10n.signOut,
                style: TextStyle(
                  color: scheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => _confirmSignOut(context, ref),
            ),
          ),
          const SizedBox(height: 24),

          _SectionLabel(l10n.dangerZone),
          _Card(
            child: ListTile(
              leading: Icon(Icons.delete_forever_outlined, color: scheme.error),
              title: Text(
                l10n.deleteAccount,
                style: TextStyle(
                  color: scheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                l10n.deleteAccountDesc,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              onTap: () => _deleteAccountFlow(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.signOut),
        content: Text(l10n.logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              l10n.signOut,
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

  /// İki aşamalı hesap silme: önce uyarı onayı, sonra (e-posta hesaplarında)
  /// şifre doğrulaması; ardından [AuthService.deleteAccount] çağrılır.
  Future<void> _deleteAccountFlow(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    // Aşama 1: emin misin? uyarısı.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Text(l10n.areYouSure),
          content: Text(l10n.deleteAccountConfirmDesc),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                l10n.next,
                style: TextStyle(color: scheme.error),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    // Sağlayıcıya göre şifre gerekli mi? (e-posta/şifre → evet)
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;
    final needsPassword =
        user.providerData.map((p) => p.providerId).contains('password');

    String? password;
    if (needsPassword) {
      if (!context.mounted) return;
      // Aşama 2: şifre iste.
      password = await showDialog<String>(
        context: context,
        builder: (_) => const _PasswordPromptDialog(),
      );
      if (password == null) return; // iptal edildi
    }

    if (!context.mounted) return;
    // Silme sırasında engelleyici ilerleme göstergesi.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await ref.read(authServiceProvider).deleteAccount(password: password);
      if (!context.mounted) return;
      Navigator.of(context).pop(); // ilerleme göstergesini kapat
      context.goNamed(RoutePaths.loginName);
    } on AuthException catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.deleteAccountFailed)),
      );
    }
  }
}

/// Hesap silme öncesi şifre doğrulama diyaloğu. Onaylanırsa girilen şifreyi,
/// iptal edilirse `null` döndürür.
class _PasswordPromptDialog extends StatefulWidget {
  const _PasswordPromptDialog();

  @override
  State<_PasswordPromptDialog> createState() => _PasswordPromptDialogState();
}

class _PasswordPromptDialogState extends State<_PasswordPromptDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.enterPassword),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.deleteAccountPasswordDesc),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.passwordLabel,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(
            l10n.deleteAccount,
            style: TextStyle(color: scheme.error),
          ),
        ),
      ],
    );
  }
}

/// Tutarlı kart sarmalayıcı (kenarlık + köşe + yüzey rengi).
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
      ),
      child: child,
    );
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
