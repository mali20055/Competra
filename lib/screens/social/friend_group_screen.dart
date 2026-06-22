import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/friend_group.dart';
import '../../models/friendship.dart';
import '../../models/tournament.dart' show Participant;
import '../../services/firebase_providers.dart';
import '../../services/social_repository.dart';

/// Arkadaş grubu detayı: grup içi sıralama tablosu + üye ekleme.
///
/// Üyeler `friendGroups/{id}/members` alt koleksiyonundan canlı dinlenir;
/// en yüksek `totalPoints` üstte, eşitlikte `totalGoalsScored` belirleyicidir.
/// İlk üç sıra altın/gümüş/bronz sol kenar vurgusuyla gösterilir.
class FriendGroupScreen extends ConsumerWidget {
  const FriendGroupScreen({
    super.key,
    required this.groupId,
    this.groupName,
  });

  final String groupId;
  final String? groupName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(friendGroupProvider(groupId));
    final membersAsync = ref.watch(friendGroupMembersProvider(groupId));
    final myUid = ref.watch(currentUserProvider)?.uid ?? '';

    final group = groupAsync.asData?.value;
    final isOwner = group != null && group.createdBy == myUid;
    final title = group?.name ?? groupName ?? 'Grup';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (isOwner)
            IconButton(
              tooltip: 'Üye Ekle',
              icon: const Icon(Icons.person_add_alt_1),
              onPressed: () => _showAddMemberSheet(context, ref),
            ),
        ],
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const _EmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Yüklenemedi',
          message: 'Grup verisi alınamadı. Lütfen tekrar dene.',
        ),
        data: (members) => _GroupStandings(
          members: members,
          canInvite: isOwner,
          onInvite: () => _showAddMemberSheet(context, ref),
        ),
      ),
    );
  }

  Future<void> _showAddMemberSheet(BuildContext context, WidgetRef ref) async {
    final currentMembers =
        ref.read(friendGroupMembersProvider(groupId)).asData?.value ??
            const <FriendGroupMember>[];
    final memberUids = {for (final m in currentMembers) m.uid};

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _AddMemberSheet(
        groupId: groupId,
        existingMemberUids: memberUids,
      ),
    );
  }
}

/// Sıralama tablosu + grup istatistik özeti.
class _GroupStandings extends StatelessWidget {
  const _GroupStandings({
    required this.members,
    required this.canInvite,
    required this.onInvite,
  });

  final List<FriendGroupMember> members;
  final bool canInvite;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final totalMatchesRaw =
        members.fold<int>(0, (sum, m) => sum + m.totalMatches);
    // Her maç iki üyenin istatistiğine işlendiğinden, oynanan maç sayısı yarıdır.
    final totalMatches = totalMatchesRaw ~/ 2;
    final totalGoals =
        members.fold<int>(0, (sum, m) => sum + m.totalGoalsScored);

    // Sıralama: önce puan, eşitse atılan gol (her ikisi de azalan).
    final sorted = [...members]..sort((a, b) {
        final byPoints = b.totalPoints.compareTo(a.totalPoints);
        if (byPoints != 0) return byPoints;
        return b.totalGoalsScored.compareTo(a.totalGoalsScored);
      });

    if (totalMatchesRaw == 0) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatsSummary(totalMatches: totalMatches, totalGoals: totalGoals),
          const SizedBox(height: 24),
          const _EmptyState(
            icon: Icons.sports_soccer_outlined,
            title: 'Henüz maç oynanmadı',
            message:
                'Grup üyeleri bir turnuvada karşılaştığında sonuçlar burada görünecek.',
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatsSummary(totalMatches: totalMatches, totalGoals: totalGoals),
        const SizedBox(height: 16),
        const _StandingsHeader(),
        const SizedBox(height: 6),
        for (var i = 0; i < sorted.length; i++)
          _StandingRow(rank: i + 1, member: sorted[i])
              .animate()
              .fadeIn(delay: (i * 60).ms, duration: 320.ms)
              .slideX(begin: 0.08, end: 0),
      ],
    );
  }
}

/// Grup istatistik özeti kartı (toplam maç + toplam gol).
class _StatsSummary extends StatelessWidget {
  const _StatsSummary({required this.totalMatches, required this.totalGoals});

  final int totalMatches;
  final int totalGoals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryItem(
              icon: Icons.sports_soccer,
              label: 'Toplam maç',
              value: '$totalMatches',
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: scheme.outline.withValues(alpha: 0.3),
          ),
          Expanded(
            child: _SummaryItem(
              icon: Icons.scoreboard_outlined,
              label: 'Toplam gol',
              value: '$totalGoals',
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        Icon(icon, color: scheme.primary, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.primary,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Tablo başlık satırı: Sıra | Oyuncu | Maç | G | M | Gol | P
class _StandingsHeader extends StatelessWidget {
  const _StandingsHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Row(
        children: [
          SizedBox(width: 26, child: Text('#', style: style)),
          const SizedBox(width: 8),
          Expanded(child: Text('Oyuncu', style: style)),
          _HeaderCell('Maç', style),
          _HeaderCell('G', style),
          _HeaderCell('M', style),
          _HeaderCell('Gol', style),
          _HeaderCell('P', style),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label, this.style);

  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      child: Text(label, textAlign: TextAlign.center, style: style),
    );
  }
}

/// Tek bir oyuncu sırası; ilk üç için madalya renginde sol kenar vurgusu.
class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.rank, required this.member});

  final int rank;
  final FriendGroupMember member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = _rankColor(rank);

    final valueStyle = theme.textTheme.bodyMedium;
    final pointStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w800,
      color: scheme.primary,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          top: BorderSide(color: scheme.outline.withValues(alpha: 0.2)),
          right: BorderSide(color: scheme.outline.withValues(alpha: 0.2)),
          bottom: BorderSide(color: scheme.outline.withValues(alpha: 0.2)),
          // İlk üç sıra için madalya renginde kalın sol kenar vurgusu.
          left: BorderSide(
            color: accent ?? scheme.outline.withValues(alpha: 0.2),
            width: accent != null ? 4 : 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text(
                '$rank',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: accent ?? scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                member.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _ValueCell('${member.totalMatches}', valueStyle),
            _ValueCell('${member.totalWins}', valueStyle),
            _ValueCell('${member.totalLosses}', valueStyle),
            _ValueCell('${member.totalGoalsScored}', valueStyle),
            _ValueCell('${member.totalPoints}', pointStyle),
          ],
        ),
      ),
    );
  }

  Color? _rankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // altın
      case 2:
        return const Color(0xFFC0C0C0); // gümüş
      case 3:
        return const Color(0xFFCD7F32); // bronz
      default:
        return null;
    }
  }
}

class _ValueCell extends StatelessWidget {
  const _ValueCell(this.value, this.style);

  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      child: Text(value, textAlign: TextAlign.center, style: style),
    );
  }
}

/// Üye ekleme bottom sheet'i: arkadaş listesinden (gruba henüz dahil olmayan)
/// seçim yapılır ve seçilen arkadaş gruba eklenir.
class _AddMemberSheet extends ConsumerWidget {
  const _AddMemberSheet({
    required this.groupId,
    required this.existingMemberUids,
  });

  final String groupId;
  final Set<String> existingMemberUids;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final myUid = ref.watch(currentUserProvider)?.uid ?? '';
    final friendsAsync = ref.watch(friendsProvider);

    final friends = friendsAsync.asData?.value ?? const <Friendship>[];
    final candidates = [
      for (final f in friends)
        if (!existingMemberUids.contains(f.otherUid(myUid)))
          f.otherSummary(myUid),
    ];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Üye Ekle',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Arkadaş listenden gruba eklemek istediğin kişiyi seç.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (friendsAsync.isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (candidates.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Eklenebilecek arkadaş yok.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final c = candidates[index];
                    return _CandidateTile(
                      username: c.username,
                      onAdd: () => _add(context, ref, c.uid, c.username),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    String uid,
    String username,
  ) async {
    try {
      await ref.read(socialRepositoryProvider).addMemberToGroup(
            groupId: groupId,
            member: Participant(uid: uid, username: username),
          );
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$username gruba eklendi.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        final scheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Üye eklenemedi.',
              style: TextStyle(color: scheme.onError),
            ),
            backgroundColor: scheme.error,
          ),
        );
      }
    }
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({required this.username, required this.onAdd});

  final String username;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: scheme.primary.withValues(alpha: 0.15),
            child: Text(
              username.isEmpty ? '?' : username[0].toUpperCase(),
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Ekle'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
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
            Icon(icon, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
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
