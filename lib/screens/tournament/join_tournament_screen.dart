import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/route_paths.dart';
import '../../services/tournament_repository.dart';
import 'qr_scanner_screen.dart';

/// Davet koduyla turnuvaya katılma ekranı.
///
/// Kullanıcı 6 haneli davet kodunu girer; kod Firestore'da `inviteCode`
/// alanıyla aranır. Bulunursa kullanıcı katılımcı listesine eklenir ve turnuva
/// detayına yönlendirilir. Tüm renkler tema üzerinden gelir.
class JoinTournamentScreen extends ConsumerStatefulWidget {
  const JoinTournamentScreen({super.key, this.initialCode});

  /// Deep link (competra://join/KOD) ile gelindiğinde otomatik doldurulan kod.
  final String? initialCode;

  @override
  ConsumerState<JoinTournamentScreen> createState() =>
      _JoinTournamentScreenState();
}

class _JoinTournamentScreenState extends ConsumerState<JoinTournamentScreen> {
  static const int _codeLength = 6;

  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Deep link'ten gelen kodu otomatik doldur (büyük harf, en çok 6 karakter).
    final code = widget.initialCode?.trim().toUpperCase();
    if (code != null && code.isNotEmpty) {
      _controller.text =
          code.length > _codeLength ? code.substring(0, _codeLength) : code;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isComplete => _controller.text.trim().length == _codeLength;

  Future<void> _scanQR() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => QrScannerScreen(
          onCodeScanned: (code) {
            _controller.text = code;
            setState(() {});
          },
        ),
      ),
    );
  }

  Future<void> _join() async {
    if (_loading || !_isComplete) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final id = await ref
          .read(tournamentRepositoryProvider)
          .joinByInviteCode(_controller.text);
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      context.pushReplacementNamed(
        RoutePaths.tournamentDetailName,
        pathParameters: {'id': id},
      );
    } on TournamentNotFoundException {
      if (mounted) {
        setState(() => _error = 'Bu koda sahip bir turnuva bulunamadı.');
      }
    } on TournamentJoinClosedException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Bir hata oluştu. Lütfen tekrar deneyin.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Turnuvaya Katıl')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              _IconBadge(),
              const SizedBox(height: 24),
              Text(
                'Davet Kodunu Gir',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Turnuva yöneticisinin paylaştığı 6 haneli kodu girerek '
                'turnuvaya katıl.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              _CodeField(
                controller: _controller,
                codeLength: _codeLength,
                hasError: _error != null,
                enabled: !_loading,
                onChanged: (_) {
                  setState(() {
                    if (_error != null) _error = null;
                  });
                },
                onSubmitted: (_) => _join(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 18, color: scheme.error),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loading ? null : _scanQR,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('QR ile Katıl'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: (_isComplete && !_loading) ? _join : null,
                child: _loading
                    ? SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: scheme.onPrimary,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Katıl'),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 20),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Üstteki davet ikonu rozeti.
class _IconBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.vpn_key_outlined, size: 34, color: scheme.primary),
      ),
    );
  }
}

/// 6 haneli, otomatik büyük harfe çeviren davet kodu giriş alanı.
class _CodeField extends StatelessWidget {
  const _CodeField({
    required this.controller,
    required this.codeLength,
    required this.hasError,
    required this.enabled,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final int codeLength;
  final bool hasError;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final Color borderColor =
        hasError ? scheme.error : scheme.outline.withValues(alpha: 0.4);

    return TextField(
      controller: controller,
      enabled: enabled,
      autofocus: true,
      textAlign: TextAlign.center,
      textCapitalization: TextCapitalization.characters,
      textInputAction: TextInputAction.done,
      maxLength: codeLength,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
        _UpperCaseTextFormatter(),
        LengthLimitingTextInputFormatter(codeLength),
      ],
      style: theme.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 12,
        color: scheme.onSurface,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: '------',
        hintStyle: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 12,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: hasError ? scheme.error : scheme.primary,
            width: 2,
          ),
        ),
      ),
    );
  }
}

/// Girilen metni otomatik olarak büyük harfe çevirir.
class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
