import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/tournament.dart';
import '../../services/firebase_providers.dart';
import '../../services/tournament_repository.dart';

/// Turnuva detay ekranı.
///
/// Firestore'dan turnuva belgesini ve maçlarını canlı olarak ([StreamProvider])
/// dinler. Üç sekme sunar: Fikstür, Puan Tablosu ve İstatistikler. Puan tablosu
/// ile gol krallığı, oynanmış maçlardan istemci tarafında hesaplanır. Tüm
/// renkler tema üzerinden gelir.
class TournamentDetailScreen extends ConsumerWidget {
  const TournamentDetailScreen({super.key, required this.tournamentId});

  /// İlgili turnuvanın kimliği (route path parametresi).
  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournamentAsync = ref.watch(tournamentStreamProvider(tournamentId));

    return tournamentAsync.when(
      loading: () => const _MessageScaffold.loading(),
      error: (_, __) => const _MessageScaffold(
        title: 'Turnuva Detayı',
        icon: Icons.cloud_off_outlined,
        message: 'Turnuva yüklenirken bir hata oluştu.',
      ),
      data: (tournament) {
        if (tournament == null) {
          return const _MessageScaffold(
            title: 'Turnuva Detayı',
            icon: Icons.search_off_outlined,
            message: 'Turnuva bulunamadı.',
          );
        }
        return _DetailView(tournament: tournament);
      },
    );
  }
}

/// Turnuva yüklendikten sonraki üç sekmeli ana görünüm.
class _DetailView extends ConsumerWidget {
  const _DetailView({required this.tournament});

  final Tournament tournament;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Turnuva henüz başlamadıysa bekleme lobisi gösterilir.
    if (tournament.isWaiting) {
      return _LobbyView(tournament: tournament);
    }

    final matchesAsync = ref.watch(matchesStreamProvider(tournament.id));

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tournament.name),
          actions: [
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: 'Davet Kodu',
              onPressed: () => _showInviteCode(context, tournament.inviteCode),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Fikstür'),
              Tab(text: 'Puan Tablosu'),
              Tab(text: 'İstatistikler'),
            ],
          ),
        ),
        body: Column(
          children: [
            _InfoHeader(tournament: tournament),
            Expanded(
              child: matchesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => const _EmptyState(
                  icon: Icons.cloud_off_outlined,
                  message: 'Maçlar yüklenemedi.',
                ),
                data: (matches) {
                  final standings = computeStandings(
                    tournament.participants,
                    matches,
                    tournament.tiebreakerMode,
                  );
                  final scorers =
                      computeScorers(tournament.participants, matches);
                  return TabBarView(
                    children: [
                      _FixtureTab(
                        tournamentId: tournament.id,
                        matches: matches,
                      ),
                      _StandingsTab(standings: standings),
                      _StatsTab(scorers: scorers),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInviteCode(BuildContext context, String code) {
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Davet Kodu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Bu kodu paylaşarak başkalarını turnuvaya davet edebilirsin.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            SelectableText(
              code,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 8,
                    color: scheme.primary,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kod kopyalandı.')),
              );
            },
            child: const Text('Kopyala'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }
}

/// Turnuva başlamadan önceki bekleme lobisi.
///
/// Katılımcıları, davet kodunu ve (yalnızca yöneticiye) "Başlat" butonunu
/// gösterir. Başlatma, formata göre fikstürü üretir ve turnuvayı 'active'
/// duruma çeker; durum güncellenince [_DetailView] otomatik olarak sekmeli
/// görünüme döner.
class _LobbyView extends ConsumerStatefulWidget {
  const _LobbyView({required this.tournament});

  final Tournament tournament;

  @override
  ConsumerState<_LobbyView> createState() => _LobbyViewState();
}

class _LobbyViewState extends ConsumerState<_LobbyView> {
  bool _starting = false;

  Future<void> _start() async {
    final t = widget.tournament;
    if (_starting || t.participants.length < 2) return;
    setState(() => _starting = true);
    try {
      await ref.read(tournamentRepositoryProvider).startTournament(
            tournamentId: t.id,
            format: t.format,
            participants: t.participants,
          );
      // Durum 'active' olunca _DetailView yeniden kurulup sekmeleri gösterir.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Turnuva başladı!')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _starting = false);
      final scheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Turnuva başlatılamadı. Lütfen tekrar deneyin.',
            style: TextStyle(color: scheme.onError),
          ),
          backgroundColor: scheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tournament;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = ref.watch(currentUserProvider);
    final isAdmin = user != null && user.uid == t.ownerId;
    final enoughPlayers = t.participants.length >= 2;

    return Scaffold(
      appBar: AppBar(title: Text(t.name)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Bekleme durumu bandı.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.hourglass_top, color: scheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bekleme Lobisi',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Oyuncular katılıyor. Yönetici başlatınca '
                                'fikstür oluşturulacak.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _InviteCodeCard(code: t.inviteCode),
                  const SizedBox(height: 24),
                  Text(
                    'Katılımcılar (${t.participants.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final p in t.participants)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ParticipantTile(
                        name: p.username,
                        isOwner: p.uid == t.ownerId,
                      ),
                    ),
                ],
              ),
            ),
            // Alt aksiyon alanı.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(
                  top: BorderSide(color: scheme.outline.withValues(alpha: 0.2)),
                ),
              ),
              child: isAdmin
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!enoughPlayers)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Başlatmak için en az 2 oyuncu gerekli.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                (enoughPlayers && !_starting) ? _start : null,
                            icon: _starting
                                ? const SizedBox.shrink()
                                : const Icon(Icons.play_arrow),
                            label: _starting
                                ? SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: scheme.onPrimary,
                                    ),
                                  )
                                : const Text('Turnuvayı Başlat'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Yönetici turnuvayı başlattığında maçlar burada '
                            'görünecek.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lobide davet kodunu gösteren, kopyalanabilir kart.
class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.vpn_key_outlined, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Davet Kodu',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  code,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Kopyala',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kod kopyalandı.')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({required this.name, required this.isOwner});

  final String name;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: scheme.primary.withValues(alpha: 0.15),
            child: Text(
              name.isEmpty
                  ? '?'
                  : name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (isOwner)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Yönetici',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Sekmelerin üstündeki format + katılımcı bilgisi bandı.
class _InfoHeader extends StatelessWidget {
  const _InfoHeader({required this.tournament});

  final Tournament tournament;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          bottom: BorderSide(color: scheme.outline.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          _Chip(
            icon: Icons.category_outlined,
            label: _formatLabel(tournament.format),
          ),
          const SizedBox(width: 8),
          _Chip(
            icon: Icons.group_outlined,
            label: '${tournament.participants.length} Oyuncu',
          ),
          const Spacer(),
          Icon(Icons.vpn_key_outlined, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            tournament.inviteCode,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sekme 1 — Fikstür
// ---------------------------------------------------------------------------

class _FixtureTab extends StatelessWidget {
  const _FixtureTab({required this.tournamentId, required this.matches});

  final String tournamentId;
  final List<TournamentMatch> matches;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return const _EmptyState(
        icon: Icons.sports_soccer_outlined,
        message: 'Henüz fikstür oluşturulmadı.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: matches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _MatchCard(
        tournamentId: tournamentId,
        match: matches[index],
      ),
    );
  }
}

/// Tek bir maç kartı: oyuncular, skor (oynandıysa) ve "Skoru Gir" butonu.
class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.tournamentId, required this.match});

  final String tournamentId;
  final TournamentMatch match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          if (match.round.isNotEmpty) ...[
            Text(
              match.round,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  match.homeName,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ScoreBadge(match: match),
              ),
              Expanded(
                child: Text(
                  match.awayName,
                  textAlign: TextAlign.start,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openScoreEntry(context),
              icon: Icon(
                match.isPlayed ? Icons.edit_outlined : Icons.add_circle_outline,
                size: 18,
              ),
              label: Text(match.isPlayed ? 'Skoru Düzenle' : 'Skoru Gir'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openScoreEntry(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _ScoreEntryDialog(
        tournamentId: tournamentId,
        match: match,
      ),
    );
  }
}

/// Skoru gösteren orta rozet ("—" oynanmamış maçlar için).
class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.match});

  final TournamentMatch match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final String text = match.isPlayed
        ? '${match.homeScore} - ${match.awayScore}'
        : '—';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: match.isPlayed
            ? scheme.primary.withValues(alpha: 0.12)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: match.isPlayed ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Skor giriş diyaloğu — her iki oyuncunun golünü alır ve Firestore'a yazar.
class _ScoreEntryDialog extends ConsumerStatefulWidget {
  const _ScoreEntryDialog({required this.tournamentId, required this.match});

  final String tournamentId;
  final TournamentMatch match;

  @override
  ConsumerState<_ScoreEntryDialog> createState() => _ScoreEntryDialogState();
}

class _ScoreEntryDialogState extends ConsumerState<_ScoreEntryDialog> {
  late final TextEditingController _home;
  late final TextEditingController _away;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _home = TextEditingController(
      text: widget.match.homeScore?.toString() ?? '',
    );
    _away = TextEditingController(
      text: widget.match.awayScore?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _home.dispose();
    _away.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final home = int.tryParse(_home.text.trim());
    final away = int.tryParse(_away.text.trim());
    if (home == null || away == null || home < 0 || away < 0) {
      final scheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lütfen geçerli skorlar girin.',
            style: TextStyle(color: scheme.onError),
          ),
          backgroundColor: scheme.error,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(tournamentRepositoryProvider).updateMatchScore(
            tournamentId: widget.tournamentId,
            matchId: widget.match.id,
            homeScore: home,
            awayScore: away,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      final scheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Skor kaydedilemedi. Lütfen tekrar deneyin.',
            style: TextStyle(color: scheme.onError),
          ),
          backgroundColor: scheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Skoru Gir'),
      content: Row(
        children: [
          Expanded(child: _ScoreInput(label: widget.match.homeName, controller: _home)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('-', style: TextStyle(fontSize: 22)),
          ),
          Expanded(child: _ScoreInput(label: widget.match.awayName, controller: _away)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(88, 44),
          ),
          child: _saving
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                )
              : const Text('Kaydet'),
        ),
      ],
    );
  }
}

class _ScoreInput extends StatelessWidget {
  const _ScoreInput({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 2,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          decoration: const InputDecoration(
            counterText: '',
            hintText: '0',
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sekme 2 — Puan Tablosu
// ---------------------------------------------------------------------------

class _StandingsTab extends StatelessWidget {
  const _StandingsTab({required this.standings});

  final List<StandingRow> standings;

  @override
  Widget build(BuildContext context) {
    if (standings.isEmpty) {
      return const _EmptyState(
        icon: Icons.table_chart_outlined,
        message: 'Henüz katılımcı yok.',
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const _StandingsHeaderRow(),
          const SizedBox(height: 4),
          for (var i = 0; i < standings.length; i++)
            _StandingsDataRow(rank: i + 1, row: standings[i]),
        ],
      ),
    );
  }
}

class _StandingsHeaderRow extends StatelessWidget {
  const _StandingsHeaderRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 24, child: Text('#', style: style)),
          const SizedBox(width: 8),
          Expanded(child: Text('Oyuncu', style: style)),
          _StatHeaderCell('O', style),
          _StatHeaderCell('G', style),
          _StatHeaderCell('B', style),
          _StatHeaderCell('M', style),
          _StatHeaderCell('A', style),
          _StatHeaderCell('P', style),
        ],
      ),
    );
  }
}

class _StatHeaderCell extends StatelessWidget {
  const _StatHeaderCell(this.label, this.style);

  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      child: Text(label, textAlign: TextAlign.center, style: style),
    );
  }
}

/// Tek bir puan tablosu satırı; ilk 3 sıra tema rengiyle vurgulanır.
class _StandingsDataRow extends StatelessWidget {
  const _StandingsDataRow({required this.rank, required this.row});

  final int rank;
  final StandingRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // İlk 3 sıra için azalan yoğunlukta tema (primary) vurgusu.
    final double highlight = switch (rank) {
      1 => 0.16,
      2 => 0.10,
      3 => 0.06,
      _ => 0.0,
    };
    final bool isTop3 = rank <= 3;

    final cellStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurface,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isTop3
            ? scheme.primary.withValues(alpha: highlight)
            : scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isTop3
              ? scheme.primary.withValues(alpha: 0.4)
              : scheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: _RankBadge(rank: rank, isTop3: isTop3),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              row.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isTop3 ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          _StatCell('${row.played}', cellStyle),
          _StatCell('${row.won}', cellStyle),
          _StatCell('${row.drawn}', cellStyle),
          _StatCell('${row.lost}', cellStyle),
          _StatCell('${row.goalDiff}', cellStyle),
          _StatCell(
            '${row.points}',
            theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell(this.value, this.style);

  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      child: Text(value, textAlign: TextAlign.center, style: style),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank, required this.isTop3});

  final int rank;
  final bool isTop3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (!isTop3) {
      return Text(
        '$rank',
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primary,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$rank',
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sekme 3 — İstatistikler (Gol Krallığı)
// ---------------------------------------------------------------------------

class _StatsTab extends StatelessWidget {
  const _StatsTab({required this.scorers});

  final List<ScorerRow> scorers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (scorers.isEmpty) {
      return const _EmptyState(
        icon: Icons.emoji_events_outlined,
        message: 'Henüz gol kaydı yok.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Icon(Icons.emoji_events, color: scheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Gol Krallığı',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < scorers.length; i++) ...[
          _ScorerRowTile(rank: i + 1, scorer: scorers[i]),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ScorerRowTile extends StatelessWidget {
  const _ScorerRowTile({required this.rank, required this.scorer});

  final int rank;
  final ScorerRow scorer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bool isLeader = rank == 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isLeader
            ? scheme.primary.withValues(alpha: 0.12)
            : scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLeader
              ? scheme.primary.withValues(alpha: 0.4)
              : scheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          _RankBadge(rank: rank, isTop3: rank <= 3),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              scorer.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: isLeader ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            '${scorer.goals}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'gol',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ortak yardımcılar
// ---------------------------------------------------------------------------

/// Turnuva formatı kod adını ([TournamentFormat.name]) Türkçe etikete çevirir.
String _formatLabel(String format) {
  switch (format) {
    case 'league':
      return 'Lig';
    case 'knockout':
      return 'Eleme';
    case 'groupKnockout':
      return 'Grup + Eleme';
    case 'championsLeague':
      return 'Şampiyonlar Ligi';
    default:
      return 'Turnuva';
  }
}

/// Boş sekme durumlarında gösterilen ortak yer tutucu.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Yükleme / hata / bulunamadı gibi tam ekran durumları için Scaffold.
class _MessageScaffold extends StatelessWidget {
  const _MessageScaffold({
    required this.title,
    required this.icon,
    required this.message,
  }) : _isLoading = false;

  const _MessageScaffold.loading()
      : title = 'Turnuva Detayı',
        icon = Icons.hourglass_empty,
        message = '',
        _isLoading = true;

  final String title;
  final IconData icon;
  final String message;
  final bool _isLoading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _EmptyState(icon: icon, message: message),
    );
  }
}
