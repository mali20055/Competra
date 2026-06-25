import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/tournament.dart';
import '../../services/firebase_providers.dart';
import '../../services/tournament_repository.dart';

/// Bekleme ('waiting') durumundaki bir turnuvanın temel ayarlarını düzenler.
///
/// Format ve davet kodu değiştirilemez; adı, notu, skor giriş modu ve tiebreaker
/// modu düzenlenebilir. Kayıt başarılı olduğunda önceki ekrana döner.
class EditTournamentScreen extends ConsumerStatefulWidget {
  const EditTournamentScreen({super.key, required this.tournamentId});

  final String tournamentId;

  @override
  ConsumerState<EditTournamentScreen> createState() =>
      _EditTournamentScreenState();
}

class _EditTournamentScreenState extends ConsumerState<EditTournamentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();

  String? _selectedScoreMode;
  TiebreakerMode _selectedTiebreaker = TiebreakerMode.uefa;
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _initFrom(Tournament t) {
    if (_initialized) return;
    _initialized = true;
    _nameController.text = t.name;
    _noteController.text = t.note;
    _selectedScoreMode = t.scoreEntrySystem;
    _selectedTiebreaker = t.tiebreakerMode;
  }

  Future<void> _save(String tournamentId) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedScoreMode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen skor giriş modunu seçin.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(firestoreProvider)
          .collection('tournaments')
          .doc(tournamentId)
          .update({
        'name': _nameController.text.trim(),
        'note': _noteController.text.trim(),
        'scoreEntrySystem': _selectedScoreMode,
        'tiebreakerMode': _selectedTiebreaker.value,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Turnuva güncellendi.')),
      );
      context.pop();
    } catch (_) {
      if (!mounted) return;
      final scheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Güncellenemedi. Lütfen tekrar deneyin.',
            style: TextStyle(color: scheme.onError),
          ),
          backgroundColor: scheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tournamentAsync =
        ref.watch(tournamentStreamProvider(widget.tournamentId));

    return tournamentAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Turnuvayı Düzenle')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Scaffold(
        appBar: AppBar(title: const Text('Turnuvayı Düzenle')),
        body: const Center(child: Text('Yüklenirken bir hata oluştu.')),
      ),
      data: (tournament) {
        if (tournament == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Turnuvayı Düzenle')),
            body: const Center(child: Text('Turnuva bulunamadı.')),
          );
        }
        if (!tournament.isWaiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Turnuvayı Düzenle')),
            body: const Center(
              child: Text('Başlamış turnuvalar düzenlenemez.'),
            ),
          );
        }
        _initFrom(tournament);
        return _buildForm(tournament);
      },
    );
  }

  Widget _buildForm(Tournament t) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Turnuvayı Düzenle'),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => _save(t.id),
            child: _saving
                ? SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    ),
                  )
                : const Text('Kaydet'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // ── Turnuva Adı ──────────────────────────────────────
            _FieldLabel('Turnuva Adı'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameController,
              maxLength: 50,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'Turnuva adı',
                prefixIcon: Icon(Icons.emoji_events_outlined),
              ),
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) return 'Ad gerekli';
                if (s.length < 3) return 'En az 3 karakter olmalı';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // ── Not ──────────────────────────────────────────────
            _FieldLabel('Not (opsiyonel)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _noteController,
              maxLength: 200,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: 'Kurallar, ödüller veya özel notlar…',
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),

            // ── Skor Giriş Modu ──────────────────────────────────
            _FieldLabel('Skor Giriş Modu'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _selectedScoreMode,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.sports_score_outlined),
              ),
              hint: const Text('Seçin'),
              items: const [
                DropdownMenuItem(
                  value: 'adminOnly',
                  child: Text('Yalnızca Yönetici'),
                ),
                DropdownMenuItem(
                  value: 'winnerEntry',
                  child: Text('Kazanan Girer'),
                ),
                DropdownMenuItem(
                  value: 'doubleEntry',
                  child: Text('Çift Giriş'),
                ),
              ],
              onChanged: (v) => setState(() => _selectedScoreMode = v),
            ),
            const SizedBox(height: 20),

            // ── Tiebreaker (eleme formatında anlamsız) ────────────
            if (t.format != 'knockout') ...[
              _FieldLabel('Sıralama Kriteri'),
              const SizedBox(height: 6),
              DropdownButtonFormField<TiebreakerMode>(
                initialValue: _selectedTiebreaker,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.balance_outlined),
                ),
                items: [
                  for (final m in TiebreakerMode.values)
                    DropdownMenuItem(value: m, child: Text(m.label)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _selectedTiebreaker = v);
                },
              ),
              const SizedBox(height: 20),
            ],

            // ── Format (değiştirilemez) ───────────────────────────
            _DisabledInfoTile(
              label: 'Format',
              value: _formatLabel(t.format),
              hint: 'Fikstür oluşturulduktan sonra format değiştirilemez',
            ),
            const SizedBox(height: 16),

            // ── Davet Kodu (görüntüle) ───────────────────────────
            _DisabledInfoTile(
              label: 'Davet Kodu',
              value: t.inviteCode,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _formatLabel(String format) => switch (format) {
        'league' => 'Lig',
        'knockout' => 'Eleme',
        'groupKnockout' => 'Grup + Eleme',
        'championsLeague' => 'Şampiyonlar Ligi',
        _ => format,
      };
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DisabledInfoTile extends StatelessWidget {
  const _DisabledInfoTile({
    required this.label,
    required this.value,
    this.hint,
  });

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: scheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (hint != null) ...[
                const SizedBox(height: 4),
                Text(
                  hint!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
