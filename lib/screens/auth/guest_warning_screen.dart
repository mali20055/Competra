import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/pitch_pattern_background.dart';
import '../../router/route_paths.dart';
import '../../services/auth_service.dart';

/// Misafir olarak devam etmeden önce, hesap açmanın avantajlarını gösteren
/// uyarı ekranı.
///
/// "Hesap Oluştur" giriş/kayıt ekranına, "Misafir Devam Et" doğrudan ana
/// panele yönlendirir. Tüm renkler tema üzerinden gelir.
class GuestWarningScreen extends StatelessWidget {
  const GuestWarningScreen({super.key});

  /// Hesap açıldığında elde edilen avantajlar.
  static const List<({IconData icon, String label})> _benefits = [
    (icon: Icons.account_circle_outlined, label: 'Profil sayfası'),
    (icon: Icons.bar_chart, label: 'İstatistikler'),
    (icon: Icons.workspace_premium_outlined, label: 'Unvanlar ve rozetler'),
    (icon: Icons.group_outlined, label: 'Arkadaş listesi'),
    (icon: Icons.leaderboard_outlined, label: 'Grup sıralaması'),
    (icon: Icons.history, label: 'Turnuva geçmişi'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: PitchPatternBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 32),
                        _WarningBadge()
                            .animate()
                            .fadeIn(duration: 500.ms)
                            .scaleXY(begin: 0.8, end: 1, curve: Curves.easeOut),
                        const SizedBox(height: 20),
                        Text(
                          'Emin misin?',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 100.ms, duration: 500.ms)
                            .slideY(begin: 0.2, end: 0),
                        const SizedBox(height: 8),
                        Text(
                          'Hesap açarsan bunlara sahip olursun:',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 150.ms, duration: 500.ms),
                        const SizedBox(height: 24),
                        for (var i = 0; i < _benefits.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _BenefitTile(
                              icon: _benefits[i].icon,
                              label: _benefits[i].label,
                            )
                                .animate()
                                .fadeIn(
                                  delay: (200 + i * 80).ms,
                                  duration: 450.ms,
                                )
                                .slideY(begin: 0.3, end: 0),
                          ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                _Actions()
                    .animate()
                    .fadeIn(delay: 700.ms, duration: 500.ms)
                    .slideY(begin: 0.2, end: 0),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Üstteki parlayan uyarı ikonu rozeti.
class _WarningBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.surface,
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.25),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(Icons.warning_amber_rounded, size: 36, color: scheme.primary),
    );
  }
}

/// Tek bir avantaj satırı: sol tarafta onay ikonu + etiket.
class _BenefitTile extends StatelessWidget {
  const _BenefitTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 20, color: scheme.primary),
          const SizedBox(width: 16),
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// Alttaki birincil/ikincil aksiyon butonları.
///
/// "Misafir Devam Et" gerçek bir anonim FirebaseAuth oturumu açar.
class _Actions extends ConsumerStatefulWidget {
  @override
  ConsumerState<_Actions> createState() => _ActionsState();
}

class _ActionsState extends ConsumerState<_Actions> {
  bool _loading = false;

  Future<void> _continueAsGuest() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).signInAsGuest();
      if (!mounted) return;
      context.goNamed(RoutePaths.homeName);
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    } catch (_) {
      if (mounted) {
        _showError('Misafir girişi yapılamadı. Lütfen tekrar deneyin.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: TextStyle(color: scheme.onError)),
          backgroundColor: scheme.error,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        ElevatedButton(
          onPressed: _loading
              ? null
              : () => context.goNamed(RoutePaths.loginName),
          child: const Text('Hesap Oluştur'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _loading ? null : _continueAsGuest,
          child: _loading
              ? SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: scheme.primary,
                  ),
                )
              : const Text('Misafir Devam Et'),
        ),
      ],
    );
  }
}
