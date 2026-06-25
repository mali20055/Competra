import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/skeleton_widgets.dart';
import '../../core/time_ago.dart';
import '../../models/friend_group.dart';
import '../../models/friendship.dart';
import '../../models/tournament.dart' show Participant;
import '../../router/route_paths.dart';
import '../../services/firebase_providers.dart';
import '../../services/social_repository.dart';
import '../../services/user_repository.dart';

/// Arkadaşlar (sosyal) sekmesi.
///
/// Üstte kullanıcı adına göre arama; altında gelen arkadaşlık istekleri (varsa)
/// ve arkadaş listesi gösterilir. Veriler Firestore `friendships` koleksiyonu
/// üzerinden canlı dinlenir. Tüm renkler tema üzerinden gelir.
class SocialScreen extends ConsumerStatefulWidget {
  const SocialScreen({super.key});

  @override
  ConsumerState<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends ConsumerState<SocialScreen> {
  final _searchController = TextEditingController();

  String _query = '';
  bool _searching = false;
  List<Participant> _results = const [];
  final Set<String> _sentTo = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String value) async {
    final query = value.trim();
    setState(() => _query = query);
    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);
    final user = ref.read(currentUserProvider);
    try {
      final results = await ref.read(socialRepositoryProvider).searchUsers(
            query: query,
            excludeUid: user?.uid ?? '',
          );
      if (!mounted || _query != query) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _sendRequest(Participant target) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final myName =
        ref.read(userProfileProvider).asData?.value?.username ?? 'Oyuncu';

    setState(() => _sentTo.add(target.uid));
    try {
      await ref.read(socialRepositoryProvider).sendRequest(
            me: Participant(uid: user.uid, username: myName),
            target: target,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${target.username} kişisine istek gönderildi.')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _sentTo.remove(target.uid));
        final scheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'İstek gönderilemedi.',
              style: TextStyle(color: scheme.onError),
            ),
            backgroundColor: scheme.error,
          ),
        );
      }
    }
  }

  Future<void> _createGroup(String name) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final myName =
        ref.read(userProfileProvider).asData?.value?.username ?? 'Oyuncu';
    try {
      await ref.read(socialRepositoryProvider).createFriendGroup(
            owner: Participant(uid: user.uid, username: myName),
            name: name,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$name" grubu oluşturuldu.')),
        );
      }
    } catch (_) {
      if (mounted) {
        final scheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Grup oluşturulamadı.',
              style: TextStyle(color: scheme.onError),
            ),
            backgroundColor: scheme.error,
          ),
        );
      }
    }
  }

  Future<void> _showCreateGroupSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CreateGroupSheet(onCreate: _createGroup),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Arkadaşlar'),
        actions: [
          IconButton(
            tooltip: 'Grup Oluştur',
            icon: const Icon(Icons.group_add),
            onPressed: _showCreateGroupSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          _SearchBar(
            controller: _searchController,
            onChanged: _runSearch,
          ),
          Expanded(
            child: _query.isNotEmpty
                ? _SearchResults(
                    searching: _searching,
                    results: _results,
                    sentTo: _sentTo,
                    onAdd: _sendRequest,
                  )
                : _FriendsAndRequests(
                    onTapFriend: () =>
                        context.goNamed(RoutePaths.profileName),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Kullanıcı adı ara…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
      ),
    );
  }
}

/// Arama sonuçları + "Ekle" butonları.
class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.searching,
    required this.results,
    required this.sentTo,
    required this.onAdd,
  });

  final bool searching;
  final List<Participant> results;
  final Set<String> sentTo;
  final ValueChanged<Participant> onAdd;

  @override
  Widget build(BuildContext context) {
    if (searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (results.isEmpty) {
      return const _EmptyState(
        icon: Icons.person_search_outlined,
        title: 'Sonuç yok',
        message: 'Bu kullanıcı adıyla eşleşen biri bulunamadı.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final user = results[index];
        final sent = sentTo.contains(user.uid);
        return _UserRow(
          username: user.username,
          subtitle: '@${user.username.toLowerCase()}',
          trailing: sent
              ? const _SentChip()
              : OutlinedButton.icon(
                  onPressed: () => onAdd(user),
                  icon: const Icon(Icons.person_add_alt, size: 18),
                  label: const Text('Ekle'),
                ),
        );
      },
    );
  }
}

class _SentChip extends StatelessWidget {
  const _SentChip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check, size: 16, color: scheme.primary),
        const SizedBox(width: 4),
        Text(
          'Gönderildi',
          style: theme.textTheme.labelMedium?.copyWith(color: scheme.primary),
        ),
      ],
    );
  }
}

/// İstekler bölümü (varsa) + arkadaş listesi.
class _FriendsAndRequests extends ConsumerWidget {
  const _FriendsAndRequests({required this.onTapFriend});

  final VoidCallback onTapFriend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final requestsAsync = ref.watch(incomingRequestsProvider);
    final friendsAsync = ref.watch(friendsProvider);
    final groupsAsync = ref.watch(myFriendGroupsProvider);
    final myUid = user?.uid ?? '';

    final requests = requestsAsync.asData?.value ?? const <Friendship>[];
    final friends = friendsAsync.asData?.value ?? const <Friendship>[];
    final groups = groupsAsync.asData?.value ?? const <FriendGroup>[];

    if (friendsAsync.isLoading && friends.isEmpty && requests.isEmpty) {
      return Column(
        children: List.generate(4, (_) => const SkeletonListTile()),
      );
    }

    if (requests.isEmpty && friends.isEmpty && groups.isEmpty) {
      return const _EmptyState(
        icon: Icons.group_outlined,
        title: 'Henüz arkadaşın yok',
        message:
            'Yukarıdan kullanıcı adıyla arayıp arkadaşlık isteği gönderebilirsin.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (groups.isNotEmpty) ...[
          _SectionTitle(
            icon: Icons.workspaces_outline,
            title: 'Gruplarım',
            count: groups.length,
          ),
          const SizedBox(height: 12),
          for (final group in groups)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _GroupTile(group: group),
            ),
          const SizedBox(height: 16),
        ],
        if (requests.isNotEmpty) ...[
          _SectionTitle(
            icon: Icons.mark_email_unread_outlined,
            title: 'Arkadaşlık İstekleri',
            count: requests.length,
          ),
          const SizedBox(height: 12),
          for (final req in requests)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RequestTile(request: req, myUid: myUid),
            ),
          const SizedBox(height: 16),
        ],
        if (friends.isNotEmpty) ...[
          _SectionTitle(
            icon: Icons.group,
            title: 'Arkadaşlarım',
            count: friends.length,
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < friends.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FriendTile(
                summary: friends[i].otherSummary(myUid),
                onTap: onTapFriend,
              )
                  .animate()
                  .fadeIn(delay: (i * 70).ms, duration: 350.ms)
                  .slideX(begin: 0.1, end: 0),
            ),
        ],
      ],
    );
  }
}

/// Gelen arkadaşlık isteği — onayla/reddet aksiyonlu.
class _RequestTile extends ConsumerWidget {
  const _RequestTile({required this.request, required this.myUid});

  final Friendship request;
  final String myUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final summary = request.otherSummary(myUid);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          _Avatar(name: summary.username),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Arkadaşlık isteği gönderdi',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Onayla',
            icon: Icon(Icons.check_circle, color: scheme.primary),
            onPressed: () => ref
                .read(socialRepositoryProvider)
                .acceptRequest(request.id),
          ),
          IconButton(
            tooltip: 'Reddet',
            icon: Icon(Icons.cancel, color: scheme.error),
            onPressed: () => ref
                .read(socialRepositoryProvider)
                .declineRequest(request.id),
          ),
        ],
      ),
    );
  }
}

/// Arkadaş satırı: avatar + ad + aktif unvan + son aktiflik.
class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.summary, required this.onTap});

  final FriendSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lastActive = timeAgoTr(summary.lastActive);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              _Avatar(name: summary.username),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summary.activeTitle.isEmpty
                          ? 'Oyuncu'
                          : summary.activeTitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (lastActive.isNotEmpty)
                Text(
                  lastActive,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Arkadaş grubu satırı: gruba dokununca sıralama ekranına gider.
class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group});

  final FriendGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.pushNamed(
          RoutePaths.friendGroupName,
          pathParameters: {'id': group.id},
          extra: group.name,
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: scheme.primary.withValues(alpha: 0.15),
                child: Icon(Icons.workspaces, color: scheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${group.memberCount} üye',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grup oluşturma bottom sheet'i: grup adı girilir.
class _CreateGroupSheet extends StatefulWidget {
  const _CreateGroupSheet({required this.onCreate});

  final Future<void> Function(String name) onCreate;

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    await widget.onCreate(name);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              'Grup Oluştur',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Arkadaşlarınla maçlarınızı takip edebileceğin bir grup oluştur.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Grup adı',
                hintText: 'Örn. Salı Akşamı Ligi',
                prefixIcon: Icon(Icons.workspaces_outline),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('Oluştur'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.username,
    required this.subtitle,
    required this.trailing,
  });

  final String username;
  final String subtitle;
  final Widget trailing;

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
          _Avatar(name: username),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

/// Kullanıcı adının baş harflerini gösteren dairesel avatar.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return CircleAvatar(
      radius: 22,
      backgroundColor: scheme.primary.withValues(alpha: 0.15),
      child: Text(
        _initials(name),
        style: theme.textTheme.titleSmall?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.count,
  });

  final IconData icon;
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: scheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
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
