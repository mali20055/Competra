import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/format_labels.dart';
import '../../models/tournament.dart';
import '../../models/roster_entry.dart';
import '../../router/route_paths.dart';
import '../../services/firebase_providers.dart';
import '../../services/tournament_repository.dart';
import '../../components/player_avatar.dart';

/// Turnuvanın QR kodunu ve davet kodunu bir modal bottom sheet'te gösterir.
void _showQrModal(BuildContext context, Tournament tournament) {
  showModalBottomSheet<void>(
    context: context,
    builder: (_) => Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tournament.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          QrImageView(
            data: 'competra://join/${tournament.inviteCode}',
            size: 200,
            backgroundColor: Colors.white,
          ),
          const SizedBox(height: 12),
          Text(
            'Davet Kodu: ${tournament.inviteCode}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              SharePlus.instance.share(
                ShareParams(
                  text: '${tournament.name} turnuvasına katıl!\n'
                      'Kod: ${tournament.inviteCode}\n'
                      'competra://join/${tournament.inviteCode}',
                ),
              );
            },
            icon: const Icon(Icons.share),
            label: const Text('Paylaş'),
          ),
        ],
      ),
    ),
  );
}

/// Turnuvayı sistem paylaşım sayfasıyla (WhatsApp vb.) davet metni olarak paylaşır.
Future<void> _shareTournament(Tournament tournament) {
  final text =
      "Competra'da ${tournament.name} turnuvasına katıl! 🏆\n"
      'Davet kodu: ${tournament.inviteCode}\n'
      'Uygulamayı indir ve kodu gir!';
  return SharePlus.instance.share(ShareParams(text: text));
}

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

    // Turnuva 'completed' durumuna geçtiği anda güçlü titreşimle kutla.
    ref.listen<AsyncValue<Tournament?>>(
      tournamentStreamProvider(tournamentId),
      (prev, next) {
        final wasCompleted = prev?.asData?.value?.isCompleted ?? false;
        final isCompleted = next.asData?.value?.isCompleted ?? false;
        if (!wasCompleted && isCompleted) {
          HapticFeedback.heavyImpact();
        }
      },
    );

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
    final user = ref.watch(currentUserProvider);
    final isOwner = user != null && user.uid == tournament.ownerId;
    final isAdmin = user != null && (user.uid == tournament.ownerId || tournament.adminIds.contains(user.uid));
    final isParticipant = user != null && tournament.participants.any((p) => p.uid == user.uid);
    final scheme = Theme.of(context).colorScheme;

    final completedAt = tournament.completedAt;
    final isWithin24Hours = completedAt != null &&
        DateTime.now().difference(completedAt).inHours < 24;
    final hasMvp = tournament.mvpUid != null && tournament.mvpUid!.isNotEmpty;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tournament.name),
          actions: [
            if (isOwner)
              IconButton(
                icon: const Icon(Icons.admin_panel_settings_outlined),
                tooltip: 'Yöneticileri Yönet',
                onPressed: () => _showAdminManagementSheet(context, ref, tournament),
              ),
            if (tournament.isCompleted)
              IconButton(
                icon: const Icon(Icons.celebration_outlined),
                tooltip: 'Kutlama',
                onPressed: () => context.pushNamed(
                  RoutePaths.tournamentWrappedName,
                  pathParameters: {'id': tournament.id},
                ),
              ),
            if (tournament.isCompleted && isWithin24Hours && isParticipant)
              () {
                final myVote = ref.watch(myMvpVoteProvider(tournament.id)).value;
                final hasVoted = myVote != null;
                return TextButton.icon(
                  onPressed: () => _showMvpVotingSheet(context, ref, tournament),
                  icon: Icon(
                    hasVoted ? Icons.check_circle : Icons.star_border,
                    size: 18,
                    color: hasVoted ? Colors.green : scheme.primary,
                  ),
                  label: Text(
                    hasVoted ? 'Oy Verdim ✓' : 'MVP Oyla',
                    style: TextStyle(
                      color: hasVoted ? Colors.green : scheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }(),
            if (tournament.isCompleted && isAdmin && !hasMvp)
              TextButton.icon(
                onPressed: () => _determineMvp(context, ref, tournament),
                icon: const Icon(Icons.stars, color: Colors.amber, size: 18),
                label: const Text(
                  'MVP Belirle',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.qr_code),
              tooltip: 'QR Kod',
              onPressed: () => _showQrModal(context, tournament),
            ),
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Paylaş',
              onPressed: () => _shareTournament(tournament),
            ),
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
            if (tournament.note.trim().isNotEmpty)
              _NoteCard(note: tournament.note.trim()),
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
                        tournament: tournament,
                        matches: matches,
                      ),
                      _StandingsTab(
                        standings: standings,
                        tiebreakerMode: tournament.tiebreakerMode,
                      ),
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

void _showMvpVotingSheet(BuildContext context, WidgetRef ref, Tournament tournament) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'En Değerli Oyuncu\'yu Seç (MVP)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bu turnuvada en iyi performans gösteren oyuncuya oy verin.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: tournament.participants.length,
                    itemBuilder: (context, index) {
                      final p = tournament.participants[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: scheme.primaryContainer,
                          child: Text(
                            p.username.substring(0, p.username.length >= 2 ? 2 : 1).toUpperCase(),
                            style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(p.username),
                        onTap: () async {
                          Navigator.of(context).pop();
                          await ref.read(tournamentRepositoryProvider).voteMvp(tournament.id, p.uid);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Oyunuz alındı!')),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Future<void> _determineMvp(BuildContext context, WidgetRef ref, Tournament tournament) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final votes = await ref.read(tournamentRepositoryProvider).getMvpVotes(tournament.id);
    if (!context.mounted) return;
    Navigator.of(context).pop(); // dismiss loading

    if (votes.isEmpty) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Oy Yok'),
          content: const Text('Bu turnuvada henüz hiç oylama yapılmamış. MVP\'yi manuel belirlemek ister misiniz?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showManualMvpSelectionSheet(context, ref, tournament);
              },
              child: const Text('Oyuncu Seç'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
          ],
        ),
      );
      return;
    }

    String? winnerUid;
    int maxVotes = -1;
    votes.forEach((uid, count) {
      if (count > maxVotes) {
        maxVotes = count;
        winnerUid = uid;
      }
    });

    if (winnerUid != null) {
      final winnerParticipant = tournament.participants.firstWhere(
        (p) => p.uid == winnerUid,
        orElse: () => const Participant(uid: '', username: 'Bilinmeyen Oyuncu'),
      );

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('MVP Belirle'),
          content: Text('En çok oy alan oyuncu: ${winnerParticipant.username} ($maxVotes oy).\nBu oyuncuyu turnuvanın MVP\'si olarak onaylıyor musunuz?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Onayla'),
            ),
          ],
        ),
      );

      if (confirm == true && context.mounted) {
        await ref.read(firestoreProvider).collection('tournaments').doc(tournament.id).update({
          'mvpUid': winnerUid,
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('MVP belirlendi: ${winnerParticipant.username}! ⭐️')),
          );
        }
      }
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context).pop(); // dismiss loading if not already done
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('MVP belirlenirken hata oluştu: $e')),
      );
    }
  }
}

void _showManualMvpSelectionSheet(BuildContext context, WidgetRef ref, Tournament tournament) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MVP Manuel Seç',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Oylama yapılmadığı için turnuvanın MVP\'sini manuel olarak seçin.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: tournament.participants.length,
                    itemBuilder: (context, index) {
                      final p = tournament.participants[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: scheme.primaryContainer,
                          child: Text(
                            p.username.substring(0, p.username.length >= 2 ? 2 : 1).toUpperCase(),
                            style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(p.username),
                        onTap: () async {
                          Navigator.of(context).pop();
                          await ref.read(firestoreProvider).collection('tournaments').doc(tournament.id).update({
                            'mvpUid': p.uid,
                          });
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('MVP belirlendi: ${p.username}! ⭐️')),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

void _showPredictionSheet(BuildContext context, WidgetRef ref, Tournament tournament) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kazananı Tahmin Et',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Turnuvayı kimin kazanacağını düşünüyorsun? Tahminini seç. Turnuva başladıktan sonra değiştirilemez.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: tournament.participants.length,
                    itemBuilder: (context, index) {
                      final p = tournament.participants[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: scheme.primaryContainer,
                          child: Text(
                            p.username.substring(0, p.username.length >= 2 ? 2 : 1).toUpperCase(),
                            style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(p.username),
                        onTap: () async {
                          Navigator.of(context).pop();
                          await ref.read(tournamentRepositoryProvider).predictWinner(tournament.id, p.uid);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Tahmininiz kaydedildi: ${p.username}')),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// Yöneticileri yönetme BottomSheet'i.
void _showAdminManagementSheet(
  BuildContext context,
  WidgetRef ref,
  Tournament tournament,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return _AdminManagementSheet(tournamentId: tournament.id);
    },
  );
}

class _AdminManagementSheet extends ConsumerWidget {
  const _AdminManagementSheet({required this.tournamentId});

  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tournamentAsync = ref.watch(tournamentStreamProvider(tournamentId));

    return tournamentAsync.when(
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox(
        height: 200,
        child: Center(child: Text('Hata oluştu')),
      ),
      data: (t) {
        if (t == null) return const SizedBox.shrink();

        return Padding(
          padding: EdgeInsets.only(
            top: 24,
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Yöneticileri Yönet',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Turnuvaya yardımcı yöneticiler atayabilir veya kaldırabilirsin.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              if (t.adminIds.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Henüz yardımcı yönetici eklenmedi.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: t.adminIds.length,
                  itemBuilder: (context, index) {
                    final adminId = t.adminIds[index];
                    final adminParticipant = t.participants.firstWhere(
                      (p) => p.uid == adminId,
                      orElse: () => Participant(uid: adminId, username: 'Yardımcı Yönetici'),
                    );
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: scheme.secondaryContainer,
                        child: Icon(Icons.admin_panel_settings, color: scheme.onSecondaryContainer),
                      ),
                      title: Text(adminParticipant.username),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline, color: scheme.error),
                        onPressed: () async {
                          await ref.read(tournamentRepositoryProvider).removeCoAdmin(t.id, adminId);
                        },
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showAddCoAdminSearchSheet(context, ref, t),
                  icon: const Icon(Icons.add),
                  label: const Text('Yardımcı Yönetici Ekle'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

void _showAddCoAdminSearchSheet(
  BuildContext context,
  WidgetRef ref,
  Tournament t,
) {
  final candidates = t.participants.where(
    (p) => p.uid != t.ownerId && !t.adminIds.contains(p.uid),
  ).toList();

  showModalBottomSheet<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;

      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Yönetici Ekle',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            if (candidates.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Eklenebilecek aday oyuncu bulunamadı.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  itemBuilder: (context, index) {
                    final p = candidates[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: scheme.primaryContainer,
                        child: Text(
                          p.username.substring(0, p.username.length >= 2 ? 2 : 1).toUpperCase(),
                          style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(p.username),
                      onTap: () async {
                        Navigator.of(context).pop();
                        await ref.read(tournamentRepositoryProvider).addCoAdmin(t.id, p.uid);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      );
    },
  );
}

Color _parseHexColor(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  if (cleaned.length == 6) {
    return Color(int.parse('FF$cleaned', radix: 16));
  }
  return const Color(0xFF4CAF50);
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
  Map<String, RosterEntry> _localRoster = {};

  @override
  void initState() {
    super.initState();
    _initLocalRoster();
  }

  @override
  void didUpdateWidget(_LobbyView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tournament.roster != widget.tournament.roster) {
      _initLocalRoster();
    }
  }

  void _initLocalRoster() {
    _localRoster = {
      for (final entry in widget.tournament.roster) entry.uid: entry,
    };
  }

  bool _hasRosterChanges() {
    final currentRoster = widget.tournament.roster;
    if (_localRoster.length != currentRoster.length) return true;
    for (final entry in currentRoster) {
      final local = _localRoster[entry.uid];
      if (local == null) return true;
      if (local.teamName != entry.teamName || local.teamColor != entry.teamColor) {
        return true;
      }
    }
    for (final key in _localRoster.keys) {
      final dbEntry = currentRoster.firstWhere(
        (e) => e.uid == key,
        orElse: () => const RosterEntry(uid: ''),
      );
      if (dbEntry.uid.isEmpty) return true;
    }
    return false;
  }

  Future<void> _saveRoster() async {
    try {
      await ref.read(tournamentRepositoryProvider).updateRoster(
            widget.tournament.id,
            _localRoster.values.toList(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Takım kadrosu kaydedildi.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  void _showAssignTeamDialog(Participant participant) {
    final entry = _localRoster[participant.uid] ?? RosterEntry(uid: participant.uid);
    final nameController = TextEditingController(text: entry.teamName ?? '');
    String selectedColor = entry.teamColor;

    const colorMap = {
      '#F44336': Colors.red,
      '#2196F3': Colors.blue,
      '#4CAF50': Colors.green,
      '#FFEB3B': Colors.yellow,
      '#9C27B0': Colors.purple,
      '#FF9800': Colors.orange,
      '#E91E63': Colors.pink,
      '#FFFFFF': Colors.white,
    };

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            return AlertDialog(
              title: Text('${participant.username} - Takım Ata'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Takım Adı (İsteğe Bağlı)',
                      hintText: 'Örn: Real Madrid',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Takım Rengi',
                    style: theme.textTheme.labelMedium,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: colorMap.entries.map((e) {
                      final isSelected = selectedColor.toUpperCase() == e.key.toUpperCase();
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedColor = e.key;
                          });
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: e.value,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline.withValues(alpha: 0.4),
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          child: isSelected
                              ? Icon(
                                  Icons.check,
                                  size: 16,
                                  color: e.value == Colors.white ? Colors.black : Colors.white,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _localRoster[participant.uid] = RosterEntry(
                        uid: participant.uid,
                        teamName: nameController.text.trim(),
                        teamColor: selectedColor,
                      );
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmRemoveParticipant(
    Tournament tournament,
    Participant participant,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Katılımcıyı Çıkar'),
        content: Text(
          '${participant.username} turnuvadan çıkarılsın mı?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: const Text('Çıkar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await ref.read(tournamentRepositoryProvider).removeParticipant(
            tournamentId: tournament.id,
            participantUid: participant.uid,
          );
    } catch (e) {
      if (!mounted) return;
      final scheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Katılımcı çıkarılamadı.',
            style: TextStyle(color: scheme.onError),
          ),
          backgroundColor: scheme.error,
        ),
      );
    }
  }

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
    final isAdmin = user != null && (user.uid == t.ownerId || t.adminIds.contains(user.uid));
    final isOwner = user != null && user.uid == t.ownerId;
    final enoughPlayers = t.participants.length >= 2;
    final myPredictionAsync = ref.watch(myTournamentPredictionProvider(t.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(t.name),
        actions: [
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Turnuvayı Düzenle',
              onPressed: () => context.pushNamed(
                RoutePaths.editTournamentName,
                pathParameters: {'id': t.id},
              ),
            ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Paylaş',
            onPressed: () => _shareTournament(t),
          ),
        ],
      ),
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
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _shareTournament(t),
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: const Text('Arkadaşlarını Davet Et'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  myPredictionAsync.when(
                    data: (predictionUid) {
                      if (predictionUid == null) {
                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _showPredictionSheet(context, ref, t),
                            icon: const Icon(Icons.psychology_alt),
                            label: const Text('Kazananı Tahmin Et'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: scheme.primaryContainer,
                              foregroundColor: scheme.onPrimaryContainer,
                            ),
                          ),
                        );
                      } else {
                        final predicted = t.participants.firstWhere(
                          (p) => p.uid == predictionUid,
                          orElse: () => const Participant(uid: '', username: 'Bilinmeyen Oyuncu'),
                        );
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: InputChip(
                              label: Text('Tahminim: ${predicted.username}'),
                              avatar: const Icon(Icons.auto_awesome, size: 16),
                              onPressed: () => _showPredictionSheet(context, ref, t),
                            ),
                          ),
                        );
                      }
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Katılımcılar (${t.participants.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final p in t.participants)
                    () {
                      final rosterEntry = _localRoster[p.uid];
                      final hasTeam = rosterEntry != null &&
                          rosterEntry.teamName != null &&
                          rosterEntry.teamName!.isNotEmpty;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ParticipantTile(
                          name: p.username,
                          isOwner: p.uid == t.ownerId,
                          teamName: hasTeam ? rosterEntry.teamName : null,
                          teamColor: rosterEntry?.teamColor,
                          onTap: () {
                            if (isAdmin) {
                              _showAssignTeamDialog(p);
                            } else {
                              if (p.uid == (user?.uid ?? '')) {
                                context.goNamed(RoutePaths.profileName);
                              } else {
                                context.pushNamed(
                                  RoutePaths.userProfileName,
                                  pathParameters: {'uid': p.uid},
                                );
                              }
                            }
                          },
                          onRemove: (isAdmin && p.uid != t.ownerId)
                              ? () => _confirmRemoveParticipant(t, p)
                              : null,
                        ),
                      );
                    }(),
                  if (isOwner) ...[
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Yardımcı Yöneticiler (${t.adminIds.length})',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _showAdminManagementSheet(context, ref, t),
                          icon: const Icon(Icons.settings, size: 16),
                          label: const Text('Yönet'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (t.adminIds.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          'Henüz yardımcı yönetici eklenmedi.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    else
                      for (final adminId in t.adminIds)
                        () {
                          final adminParticipant = t.participants.firstWhere(
                            (p) => p.uid == adminId,
                            orElse: () => Participant(uid: adminId, username: 'Bilinmeyen Admin'),
                          );
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
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
                                    backgroundColor: scheme.secondaryContainer,
                                    child: Icon(Icons.admin_panel_settings, color: scheme.onSecondaryContainer, size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      adminParticipant.username,
                                      style: theme.textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.remove_circle_outline, color: scheme.error, size: 20),
                                    onPressed: () async {
                                      await ref.read(tournamentRepositoryProvider).removeCoAdmin(t.id, adminId);
                                    },
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }(),
                  ],
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
                        if (_hasRosterChanges())
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _saveRoster,
                                icon: const Icon(Icons.save),
                                label: const Text('Takım Değişikliklerini Kaydet'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(44),
                                ),
                              ),
                            ),
                          ),
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
  const _ParticipantTile({
    required this.name,
    required this.isOwner,
    this.teamName,
    this.teamColor,
    this.onTap,
    this.onRemove,
  });

  final String name;
  final bool isOwner;
  final String? teamName;
  final String? teamColor;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (teamName != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _parseHexColor(teamColor ?? '#4CAF50'),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          teamName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
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
            )
          else if (onRemove != null)
            IconButton(
              icon: Icon(
                Icons.remove_circle_outline,
                color: scheme.error,
                size: 20,
              ),
              tooltip: 'Çıkar',
              onPressed: onRemove,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    ),
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
            label: tournamentFormatLabel(tournament.format),
          ),
          const SizedBox(width: 8),
          _Chip(
            icon: Icons.group_outlined,
            label: '${tournament.participants.length} Oyuncu',
          ),
          if (tournament.mvpUid != null && tournament.mvpUid!.isNotEmpty) ...[
            const SizedBox(width: 8),
            () {
              final mvpParticipant = tournament.participants.firstWhere(
                (p) => p.uid == tournament.mvpUid,
                orElse: () => const Participant(uid: '', username: 'MVP'),
              );
              return _Chip(
                icon: Icons.star,
                label: 'MVP: ${mvpParticipant.username}',
                color: Colors.amber,
              );
            }(),
          ],
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
  const _Chip({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final activeColor = color ?? scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: activeColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: activeColor),
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

class _FixtureTab extends ConsumerWidget {
  const _FixtureTab({required this.tournament, required this.matches});

  final Tournament tournament;
  final List<TournamentMatch> matches;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (matches.isEmpty) {
      return const _EmptyState(
        icon: Icons.sports_soccer_outlined,
        message: 'Henüz fikstür oluşturulmadı.',
      );
    }

    final uid = ref.watch(currentUserProvider)?.uid ?? '';

    // Mod B (Kazanan Girer): rakibin girdiği ve benim onayımı bekleyen maçlar
    // için üstte onayla/itiraz banner'ı gösterilir.
    final pendingConfirmations = tournament.isWinnerEntryScoring
        ? matches
            .where((m) =>
                m.isAwaitingConfirmation &&
                m.enteredBy.isNotEmpty &&
                m.enteredBy != uid &&
                (m.homeUid == uid || m.awayUid == uid))
            .toList()
        : const <TournamentMatch>[];

    // Çift maçlı (iki ayaklı) eleme eşleşmelerini tek karta grupla; geri kalan
    // maçlar tekil kart olarak gösterilir.
    final items = _buildFixtureItems();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final m in pendingConfirmations) ...[
          _ConfirmationBanner(tournament: tournament, match: m),
          const SizedBox(height: 12),
        ],
        for (var i = 0; i < items.length; i++) ...[
          items[i],
          if (i != items.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  /// Maçları görüntü öğelerine dönüştürür. Aynı turdaki, aynı oyuncu çiftine ait
  /// iki eleme maçı (1. ve 2. ayak) tek bir [_TwoLeggedTieCard]'ta birleştirilir.
  List<Widget> _buildFixtureItems() {
    final items = <Widget>[];
    final consumed = <String>{};
    for (final m in matches) {
      if (consumed.contains(m.id)) continue;

      TournamentMatch? partner;
      if (m.phase == 'knockout' && !m.isBye) {
        for (final other in matches) {
          if (other.id == m.id || consumed.contains(other.id)) continue;
          if (other.phase == 'knockout' &&
              !other.isBye &&
              other.roundNumber == m.roundNumber &&
              _samePair(m, other)) {
            partner = other;
            break;
          }
        }
      }

      if (partner != null) {
        final leg1 = m.leg <= partner.leg ? m : partner;
        final leg2 = identical(leg1, m) ? partner : m;
        consumed.add(leg1.id);
        consumed.add(leg2.id);
        items.add(
          _TwoLeggedTieCard(tournament: tournament, leg1: leg1, leg2: leg2),
        );
      } else {
        consumed.add(m.id);
        items.add(_MatchCard(tournament: tournament, match: m));
      }
    }
    return items;
  }

  /// İki maç aynı oyuncu çiftini (sıra önemsiz) içeriyor mu?
  static bool _samePair(TournamentMatch a, TournamentMatch b) {
    return (a.homeUid == b.homeUid && a.awayUid == b.awayUid) ||
        (a.homeUid == b.awayUid && a.awayUid == b.homeUid);
  }
}

/// Mod B onay banner'ı: rakip skoru girdiğinde diğer oyuncuya gösterilir.
class _ConfirmationBanner extends ConsumerStatefulWidget {
  const _ConfirmationBanner({required this.tournament, required this.match});

  final Tournament tournament;
  final TournamentMatch match;

  @override
  ConsumerState<_ConfirmationBanner> createState() =>
      _ConfirmationBannerState();
}

class _ConfirmationBannerState extends ConsumerState<_ConfirmationBanner> {
  bool _busy = false;

  String get _entererName => widget.match.enteredBy == widget.match.homeUid
      ? widget.match.homeName
      : widget.match.awayName;

  Future<void> _confirm() async {
    if (_busy) return;
    final m = widget.match;
    final home = m.enteredHomeScore;
    final away = m.enteredAwayScore;
    if (home == null || away == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(tournamentRepositoryProvider).updateMatchScore(
            tournamentId: widget.tournament.id,
            matchId: m.id,
            homeScore: home,
            awayScore: away,
          );
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        _showError('Onaylanamadı. Lütfen tekrar deneyin.');
      }
    }
  }

  Future<void> _dispute() async {
    if (_busy) return;
    final m = widget.match;
    final uid = ref.read(currentUserProvider)?.uid ?? '';
    final disputerName = uid == m.homeUid ? m.homeName : m.awayName;
    setState(() => _busy = true);
    try {
      await ref.read(tournamentRepositoryProvider).markDisputed(
            tournamentId: widget.tournament.id,
            matchId: m.id,
            adminUid: widget.tournament.ownerId,
            title: 'Skor İtirazı',
            message: '$_entererName, ${m.homeName} - ${m.awayName} maçında '
                '${m.enteredHomeScore}-${m.enteredAwayScore} skorunu girdi; '
                '$disputerName itiraz etti.',
          );
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        _showError('İtiraz gönderilemedi. Lütfen tekrar deneyin.');
      }
    }
  }

  void _showError(String message) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: scheme.onError)),
        backgroundColor: scheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final m = widget.match;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active_outlined,
                  size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$_entererName skoru girdi: '
                  '${m.enteredHomeScore}-${m.enteredAwayScore}. '
                  'Onayla veya itiraz et.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _dispute,
                  icon: const Icon(Icons.flag_outlined, size: 18),
                  label: const Text('İtiraz Et'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _confirm,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Onayla'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tek bir maç kartı. Skor giriş aksiyonu, turnuvanın skor giriş moduna ve
/// kullanıcının rolüne (yönetici / ev sahibi / deplasman / izleyici) göre
/// belirlenir. Anlaşmazlıklı maçlar kırmızı vurguyla gösterilir ve yönetici
/// karta dokununca çözüm diyaloğu açılır.
class _MatchCard extends ConsumerWidget {
  const _MatchCard({
    required this.tournament,
    required this.match,
    this.legLabel,
  });

  final Tournament tournament;
  final TournamentMatch match;

  /// Çift maçlı eşleşmede ayak etiketi ('1. Maç' / '2. Maç'). Verilirse kart
  /// başlığında tur adı yerine bu gösterilir.
  final String? legLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final uid = ref.watch(currentUserProvider)?.uid ?? '';
    final isAdmin = uid == tournament.ownerId || tournament.adminIds.contains(uid);
    final isHome = uid == match.homeUid;
    final isAway = uid == match.awayUid;
    final isParticipant = isHome || isAway;
    final disputed = match.isDisputed;

    final homeRoster = tournament.roster.firstWhere(
      (e) => e.uid == match.homeUid,
      orElse: () => const RosterEntry(uid: ''),
    );
    final awayRoster = tournament.roster.firstWhere(
      (e) => e.uid == match.awayUid,
      orElse: () => const RosterEntry(uid: ''),
    );

    final homeDisplayName = (homeRoster.uid.isNotEmpty && homeRoster.teamName != null && homeRoster.teamName!.isNotEmpty)
        ? homeRoster.teamName!
        : match.homeName;

    final awayDisplayName = (awayRoster.uid.isNotEmpty && awayRoster.teamName != null && awayRoster.teamName!.isNotEmpty)
        ? awayRoster.teamName!
        : match.awayName;

    final action = _buildAction(
      context,
      uid: uid,
      isAdmin: isAdmin,
      isParticipant: isParticipant,
    );

    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: disputed ? scheme.error.withValues(alpha: 0.06) : scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: disputed
              ? scheme.error.withValues(alpha: 0.6)
              : scheme.outline.withValues(alpha: 0.2),
          width: disputed ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          if ((legLabel ?? match.round).isNotEmpty) ...[
            Text(
              legLabel ?? match.round,
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        homeDisplayName,
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (homeRoster.uid.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _parseHexColor(homeRoster.teamColor),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    PlayerAvatar(name: match.homeName, radius: 14),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ScoreBadge(match: match),
              ),
              Expanded(
                child: Row(
                  children: [
                    PlayerAvatar(name: match.awayName, radius: 14),
                    const SizedBox(width: 8),
                    if (awayRoster.uid.isNotEmpty) ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _parseHexColor(awayRoster.teamColor),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        awayDisplayName,
                        textAlign: TextAlign.start,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (match.isAwaitingConfirmation || disputed) ...[
            const SizedBox(height: 10),
            _StatusChip(match: match),
          ],
          if (action != null) ...[
            const SizedBox(height: 14),
            action,
          ],
        ],
      ),
    );

    // Yönetici, anlaşmazlıklı maça dokununca çözüm diyaloğunu açar.
    if (disputed && isAdmin) {
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDisputeResolution(context),
        child: card,
      );
    }
    return card;
  }

  /// Karttaki skor aksiyonunu (buton/durum metni) role ve moda göre üretir.
  Widget? _buildAction(
    BuildContext context, {
    required String uid,
    required bool isAdmin,
    required bool isParticipant,
  }) {
    // Bye maçları otomatik sonuçlanır.
    if (match.isBye) return null;

    // Tamamlanmış maçı yalnızca yönetici düzenleyebilir.
    if (match.isFinal) {
      if (isAdmin) {
        return _entryButton(
          context,
          label: 'Skoru Düzenle',
          icon: Icons.edit_outlined,
          directComplete: true,
        );
      }
      return null;
    }

    // Anlaşmazlık: yönetici çözer, taraflar bilgilendirilir.
    if (match.isDisputed) {
      if (isAdmin) {
        return _actionButton(
          context,
          label: 'Anlaşmazlığı Çöz',
          icon: Icons.gavel_outlined,
          onPressed: () => _openDisputeResolution(context),
        );
      }
      return _statusText(context, 'İtiraz edildi. Yönetici inceliyor.');
    }

    // Mod A — Sadece Admin.
    if (tournament.isAdminOnlyScoring) {
      if (isAdmin) {
        return _entryButton(
          context,
          label: 'Skoru Gir',
          icon: Icons.add_circle_outline,
          directComplete: true,
        );
      }
      return null;
    }

    // Mod B / C — onay bekleyen ilk giriş yapılmış.
    if (match.isAwaitingConfirmation) {
      if (uid == match.enteredBy) {
        return _statusText(
          context,
          tournament.isDoubleEntryScoring
              ? 'Skorun girildi. Rakibin girişi bekleniyor.'
              : 'Skorun girildi. Rakibin onayı bekleniyor.',
        );
      }
      if (isParticipant && tournament.isDoubleEntryScoring) {
        // Çift giriş: rakip kendi skorunu girer, karşılaştırılır.
        return _entryButton(
          context,
          label: 'Skoru Gir',
          icon: Icons.add_circle_outline,
          directComplete: false,
        );
      }
      // Mod B'de onay/itiraz üstteki banner üzerinden yapılır.
      if (isParticipant) {
        return _statusText(context, 'Onayın bekleniyor (yukarıdaki banner).');
      }
      return null;
    }

    // Henüz giriş yok (pending): taraflar skoru girebilir.
    if (isParticipant) {
      return _entryButton(
        context,
        label: 'Skoru Gir',
        icon: Icons.add_circle_outline,
        directComplete: false,
      );
    }
    return null;
  }

  Widget _entryButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool directComplete,
  }) {
    return _actionButton(
      context,
      label: label,
      icon: icon,
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => _ScoreEntryDialog(
          tournament: tournament,
          match: match,
          directComplete: directComplete,
        ),
      ),
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
        ),
      ),
    );
  }

  Widget _statusText(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  void _openDisputeResolution(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _DisputeResolutionDialog(
        tournament: tournament,
        match: match,
      ),
    );
  }
}

/// Maçın bekleme/anlaşmazlık durumunu gösteren küçük rozet.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.match});

  final TournamentMatch match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final disputed = match.isDisputed;
    final color = disputed ? scheme.error : scheme.tertiary;
    final label = disputed ? 'Anlaşmazlık' : 'Onay bekliyor';
    final icon = disputed ? Icons.warning_amber_rounded : Icons.hourglass_top;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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

/// Skor giriş diyaloğu. Davranış, turnuvanın skor giriş moduna göre değişir:
///
/// - [directComplete] true (Mod A yönetici girişi veya yönetici düzenlemesi):
///   skor doğrudan kesinleşir ([TournamentRepository.updateMatchScore]).
/// - Mod B (winnerEntry): giriş onay bekler.
/// - Mod C (doubleEntry): ilk giriş onay bekler; ikinci giriş ilkiyle
///   karşılaştırılır — uyuşursa kesinleşir, uyuşmazsa anlaşmazlık açılır.
class _ScoreEntryDialog extends ConsumerStatefulWidget {
  const _ScoreEntryDialog({
    required this.tournament,
    required this.match,
    required this.directComplete,
  });

  final Tournament tournament;
  final TournamentMatch match;
  final bool directComplete;

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
    // Tamamlanmış maçı düzenlerken mevcut skor ön doldurulur; aksi halde boş.
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
      _showError('Lütfen geçerli skorlar girin.');
      return;
    }

    setState(() => _saving = true);
    try {
      await _submit(home, away);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError('Skor kaydedilemedi. Lütfen tekrar deneyin.');
    }
  }

  /// Moda göre uygun repository akışını seçer.
  Future<void> _submit(int home, int away) {
    final repo = ref.read(tournamentRepositoryProvider);
    final t = widget.tournament;
    final m = widget.match;
    final uid = ref.read(currentUserProvider)?.uid ?? '';

    // Mod A veya yönetici düzenlemesi: doğrudan kesinleştir.
    if (widget.directComplete || t.isAdminOnlyScoring) {
      return repo.updateMatchScore(
        tournamentId: t.id,
        matchId: m.id,
        homeScore: home,
        awayScore: away,
      );
    }

    // Mod B: tek giriş, onay bekler.
    if (t.isWinnerEntryScoring) {
      return repo.submitScoreForConfirmation(
        tournamentId: t.id,
        matchId: m.id,
        enteredBy: uid,
        homeScore: home,
        awayScore: away,
      );
    }

    // Mod C: çift giriş.
    final isSecondEntry = m.isAwaitingConfirmation &&
        m.enteredBy.isNotEmpty &&
        m.enteredBy != uid;
    if (!isSecondEntry) {
      // İlk giriş.
      return repo.submitScoreForConfirmation(
        tournamentId: t.id,
        matchId: m.id,
        enteredBy: uid,
        homeScore: home,
        awayScore: away,
      );
    }

    // İkinci giriş: ilk girişle karşılaştır.
    if (m.enteredHomeScore == home && m.enteredAwayScore == away) {
      // Uyuşuyor → kesinleştir.
      return repo.updateMatchScore(
        tournamentId: t.id,
        matchId: m.id,
        homeScore: home,
        awayScore: away,
      );
    }

    // Uyuşmuyor → anlaşmazlık (yöneticiye bildirim).
    final firstByHome = m.enteredBy == m.homeUid;
    final firstPair = '${m.enteredHomeScore}-${m.enteredAwayScore}';
    final secondPair = '$home-$away';
    final homeEntry = firstByHome ? firstPair : secondPair;
    final awayEntry = firstByHome ? secondPair : firstPair;
    return repo.markDisputed(
      tournamentId: t.id,
      matchId: m.id,
      adminUid: t.ownerId,
      title: 'Skor Uyuşmazlığı',
      message: 'Uyuşmazlık: ${m.homeName} - ${m.awayName} maçında skorlar '
          'uyuşmuyor. Ev sahibi girişi: $homeEntry, '
          'Deplasman girişi: $awayEntry',
      extra: {
        'secondEnteredBy': uid,
        'secondEnteredHomeScore': home,
        'secondEnteredAwayScore': away,
      },
    );
  }

  void _showError(String message) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: scheme.onError)),
        backgroundColor: scheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tournament;
    final isFirstEntryMode = !widget.directComplete &&
        !t.isAdminOnlyScoring &&
        !(t.isDoubleEntryScoring && widget.match.isAwaitingConfirmation);
    final title = widget.match.isFinal
        ? 'Skoru Düzenle'
        : isFirstEntryMode
            ? 'Skoru Bildir'
            : 'Skoru Gir';

    return AlertDialog(
      title: Text(title),
      content: Row(
        children: [
          Expanded(
            child: _ScoreInput(label: widget.match.homeName, controller: _home),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('-', style: TextStyle(fontSize: 22)),
          ),
          Expanded(
            child: _ScoreInput(label: widget.match.awayName, controller: _away),
          ),
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

/// Yöneticinin anlaşmazlıklı (disputed) bir maçı çözmesi için diyalog.
///
/// Girilen skor adaylarını (ilk giriş ve varsa ikinci giriş) listeler; yönetici
/// birini onaylar ([TournamentRepository.updateMatchScore]) ya da farklı bir
/// skoru elle girer. Onaylanan skor kesinleşir ve istatistikler işlenir.
class _DisputeResolutionDialog extends ConsumerStatefulWidget {
  const _DisputeResolutionDialog({
    required this.tournament,
    required this.match,
  });

  final Tournament tournament;
  final TournamentMatch match;

  @override
  ConsumerState<_DisputeResolutionDialog> createState() =>
      _DisputeResolutionDialogState();
}

class _DisputeResolutionDialogState
    extends ConsumerState<_DisputeResolutionDialog> {
  late final TextEditingController _home;
  late final TextEditingController _away;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _home = TextEditingController();
    _away = TextEditingController();
  }

  @override
  void dispose() {
    _home.dispose();
    _away.dispose();
    super.dispose();
  }

  List<_ScoreCandidate> get _candidates {
    final m = widget.match;
    final list = <_ScoreCandidate>[];
    if (m.enteredHomeScore != null && m.enteredAwayScore != null) {
      final name = m.enteredBy == m.homeUid ? m.homeName : m.awayName;
      list.add(_ScoreCandidate(
        label: '$name girişi',
        home: m.enteredHomeScore!,
        away: m.enteredAwayScore!,
      ));
    }
    if (m.secondEnteredHomeScore != null && m.secondEnteredAwayScore != null) {
      final name = m.secondEnteredBy == m.homeUid ? m.homeName : m.awayName;
      list.add(_ScoreCandidate(
        label: '$name girişi',
        home: m.secondEnteredHomeScore!,
        away: m.secondEnteredAwayScore!,
      ));
    }
    return list;
  }

  Future<void> _approve(int home, int away) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(tournamentRepositoryProvider).updateMatchScore(
            tournamentId: widget.tournament.id,
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

  void _approveManual() {
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
    _approve(home, away);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final m = widget.match;

    return AlertDialog(
      title: const Text('Anlaşmazlığı Çöz'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${m.homeName} - ${m.awayName}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Girilen skorlardan birini onayla ya da farklı bir skor gir.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            for (final c in _candidates) ...[
              _CandidateTile(
                candidate: c,
                onApprove: _saving ? null : () => _approve(c.home, c.away),
              ),
              const SizedBox(height: 10),
            ],
            const Divider(height: 24),
            Text(
              'Farklı skor gir',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _ScoreInput(label: m.homeName, controller: _home)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('-', style: TextStyle(fontSize: 22)),
                ),
                Expanded(child: _ScoreInput(label: m.awayName, controller: _away)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _approveManual,
                child: const Text('Bu Skoru Kaydet'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Kapat'),
        ),
      ],
    );
  }
}

/// Anlaşmazlık çözümünde gösterilen tek bir skor adayı.
class _ScoreCandidate {
  const _ScoreCandidate({
    required this.label,
    required this.home,
    required this.away,
  });

  final String label;
  final int home;
  final int away;
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({required this.candidate, required this.onApprove});

  final _ScoreCandidate candidate;
  final VoidCallback? onApprove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  candidate.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${candidate.home} - ${candidate.away}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: onApprove,
            child: const Text('Bu Skoru Onayla'),
          ),
        ],
      ),
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
  const _StandingsTab({
    required this.standings,
    required this.tiebreakerMode,
  });

  final List<StandingRow> standings;
  final TiebreakerMode tiebreakerMode;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TiebreakerBadge(mode: tiebreakerMode),
          const SizedBox(height: 12),
          const _StandingsHeaderRow(),
          const SizedBox(height: 4),
          for (var i = 0; i < standings.length; i++)
            _StandingsDataRow(rank: i + 1, row: standings[i]),
        ],
      ),
    );
  }
}

/// Puan tablosunun üstünde averaj (tiebreaker) modunu gösteren küçük rozet;
/// dokununca açıklamayı bir bottom sheet'te gösterir.
class _TiebreakerBadge extends StatelessWidget {
  const _TiebreakerBadge({required this.mode});

  final TiebreakerMode mode;

  /// Göreve göre genişletilmiş açıklama metni.
  static String _explanation(TiebreakerMode mode) => switch (mode) {
        TiebreakerMode.fifa => 'Genel averaj önce',
        TiebreakerMode.uefa => 'İkili averaj önce (La Liga, Serie A)',
        TiebreakerMode.hybrid => 'Genel averaj + ikili tiebreaker',
      };

  void _showInfo(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.balance_outlined, color: scheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    mode.label,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _explanation(mode),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Puan eşitliğinde sıralama bu kurala göre belirlenir.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _showInfo(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.secondary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.balance_outlined, size: 14, color: scheme.primary),
            const SizedBox(width: 6),
            Text(
              mode.label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.info_outline, size: 13, color: scheme.onSurfaceVariant),
          ],
        ),
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
// Çift maçlı (iki ayaklı) eleme eşleşmesi
// ---------------------------------------------------------------------------

/// İki ayaklı bir eleme eşleşmesini (1. ve 2. maç) tek kartta gösterir; her iki
/// maç da oynandığında toplam skoru ve turu geçen oyuncuyu (yeşil kenarlık ile)
/// vurgular.
class _TwoLeggedTieCard extends StatelessWidget {
  const _TwoLeggedTieCard({
    required this.tournament,
    required this.leg1,
    required this.leg2,
  });

  final Tournament tournament;
  final TournamentMatch leg1;
  final TournamentMatch leg2;

  /// İki ayağın toplamında [uid]'nin attığı toplam gol.
  int _aggFor(String uid) {
    var total = 0;
    for (final leg in [leg1, leg2]) {
      if (!leg.isPlayed) continue;
      if (leg.homeUid == uid) total += leg.homeScore!;
      if (leg.awayUid == uid) total += leg.awayScore!;
    }
    return total;
  }

  /// [uid]'nin deplasmanda (away) attığı toplam gol — eşitlik bozucu.
  int _awayFor(String uid) {
    var total = 0;
    for (final leg in [leg1, leg2]) {
      if (!leg.isPlayed) continue;
      if (leg.awayUid == uid) total += leg.awayScore!;
    }
    return total;
  }

  /// Tur atlayan oyuncunun uid'i (her iki maç oynanmadıysa null).
  /// Kural: toplam gol → deplasman golü → 1. maçın ev sahibi.
  String? _winnerUid() {
    if (!leg1.isPlayed || !leg2.isPlayed) return null;
    final a = leg1.homeUid;
    final b = leg1.awayUid;
    final aggA = _aggFor(a);
    final aggB = _aggFor(b);
    if (aggA != aggB) return aggA > aggB ? a : b;
    final awayA = _awayFor(a);
    final awayB = _awayFor(b);
    if (awayA != awayB) return awayA > awayB ? a : b;
    return a; // iki eşitlik → 1. maçın ev sahibi
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final winner = _winnerUid();
    final decided = winner != null;
    final winnerName =
        winner == leg1.homeUid ? leg1.homeName : leg1.awayName;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: decided
              ? Colors.green.withValues(alpha: 0.7)
              : scheme.outline.withValues(alpha: 0.2),
          width: decided ? 1.6 : 1,
        ),
      ),
      child: Column(
        children: [
          if (leg1.round.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                leg1.round,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          _MatchCard(tournament: tournament, match: leg1, legLabel: '1. Maç'),
          const SizedBox(height: 10),
          _MatchCard(tournament: tournament, match: leg2, legLabel: '2. Maç'),
          if (decided) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Toplam: ${leg1.homeName} '
                    '${_aggFor(leg1.homeUid)}-${_aggFor(leg1.awayUid)} '
                    '${leg1.awayName}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.check_circle,
                          size: 16, color: Colors.green),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$winnerName tur atladı',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}


/// Turnuva notunu gösteren küçük bilgi kartı.
class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.secondary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📝', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              note,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface,
                height: 1.3,
              ),
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
