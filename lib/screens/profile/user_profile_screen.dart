import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/tournament.dart' show Participant;
import '../../models/user_profile.dart';
import '../../router/route_paths.dart';
import '../../services/firebase_providers.dart';
import '../../services/social_repository.dart';
import '../../services/user_repository.dart';

final _userProfileByUidProvider =
    StreamProvider.autoDispose.family<UserProfile?, String>((ref, uid) {
  if (uid.isEmpty) return Stream.value(null);
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(uid)
      .snapshots()
      .map(UserProfile.fromDoc);
});

class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({super.key, required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(_userProfileByUidProvider(uid));
    final myUid = ref.watch(currentUserProvider)?.uid ?? '';
    final isOwnProfile = uid == myUid;

    return profileAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Profil')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Scaffold(
        appBar: AppBar(title: const Text('Profil')),
        body: const Center(child: Text('Profil yüklenemedi.')),
      ),
      data: (profile) {
        if (profile == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Profil')),
            body: const Center(child: Text('Kullanıcı bulunamadı.')),
          );
        }
        return _ProfileView(
          profile: profile,
          myUid: myUid,
          isOwnProfile: isOwnProfile,
        );
      },
    );
  }
}

class _ProfileView extends ConsumerStatefulWidget {
  const _ProfileView({
    required this.profile,
    required this.myUid,
    required this.isOwnProfile,
  });

  final UserProfile profile;
  final String myUid;
  final bool isOwnProfile;

  @override
  ConsumerState<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<_ProfileView> {
  bool _requestSent = false;

  Future<void> _sendFriendRequest() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final myProfile = ref.read(userProfileProvider).asData?.value;
    final myName = myProfile?.username ?? 'Oyuncu';
    setState(() => _requestSent = true);
    try {
      await ref.read(socialRepositoryProvider).sendRequest(
            me: Participant(uid: user.uid, username: myName),
            target: Participant(
              uid: widget.profile.uid,
              username: widget.profile.username,
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${widget.profile.username} kişisine istek gönderildi.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _requestSent = false);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final profile = widget.profile;

    final friendsAsync = ref.watch(friendsProvider);
    final friends = friendsAsync.asData?.value ?? const [];
    final isFriend = friends.any((f) => f.users.contains(profile.uid));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: profile.coverUrl.isNotEmpty ? 180 : 0,
            pinned: true,
            title: Text(profile.username),
            flexibleSpace: profile.coverUrl.isNotEmpty
                ? FlexibleSpaceBar(
                    background: CachedNetworkImage(
                      imageUrl: profile.coverUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: scheme.surfaceContainerHighest),
                      errorWidget: (_, __, ___) =>
                          Container(color: scheme.surfaceContainerHighest),
                    ),
                  )
                : null,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor:
                            scheme.primary.withValues(alpha: 0.15),
                        backgroundImage: profile.photoUrl.isNotEmpty
                            ? CachedNetworkImageProvider(profile.photoUrl)
                            : null,
                        child: profile.photoUrl.isEmpty
                            ? Text(
                                _initials(profile.username),
                                style:
                                    theme.textTheme.headlineMedium?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              profile.username,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (profile.activeTitle.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      scheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: scheme.primary
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  profile.activeTitle,
                                  style:
                                      theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (profile.bio.isNotEmpty) ...[
                    Text(profile.bio, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 16),
                  ],

                  if (profile.favoriteTeam.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.favorite, size: 16, color: scheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          profile.favoriteTeam,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  Row(
                    children: [
                      _StatChip(
                          label: 'Maç', value: '${profile.totalMatches}'),
                      const SizedBox(width: 8),
                      _StatChip(
                          label: 'Galibiyet', value: '${profile.totalWins}'),
                      const SizedBox(width: 8),
                      _StatChip(
                          label: 'Gol',
                          value: '${profile.totalGoalsScored}'),
                    ],
                  ),

                  if (profile.badges.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Rozetler',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: profile.badges
                          .take(6)
                          .map((b) => _BadgeChip(badge: b))
                          .toList(),
                    ),
                  ],

                  const SizedBox(height: 24),

                  if (widget.isOwnProfile)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            context.pushNamed(RoutePaths.editProfileName),
                        icon: const Icon(Icons.edit),
                        label: const Text('Profili Düzenle'),
                      ),
                    )
                  else if (isFriend)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Arkadaşsınız ✓',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_requestSent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, color: scheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'İstek Gönderildi',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _sendFriendRequest,
                        icon: const Icon(Icons.person_add),
                        label: const Text('Arkadaş Ekle'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
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
        ),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.badge});

  final String badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
      ),
      child: Text(
        badge,
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
