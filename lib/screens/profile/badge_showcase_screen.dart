import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/badge_definitions.dart';
import '../../services/firebase_providers.dart';
import '../../services/user_repository.dart';

class BadgeShowcaseScreen extends ConsumerStatefulWidget {
  const BadgeShowcaseScreen({super.key});

  @override
  ConsumerState<BadgeShowcaseScreen> createState() => _BadgeShowcaseScreenState();
}

class _BadgeShowcaseScreenState extends ConsumerState<BadgeShowcaseScreen> {
  final List<String> _selectedBadgeIds = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider).asData?.value;
    if (profile != null) {
      _selectedBadgeIds.addAll(profile.showcaseBadges);
    }
  }

  Future<void> _save() async {
    final profile = ref.read(userProfileProvider).asData?.value;
    if (profile == null) return;

    setState(() => _saving = true);

    try {
      final firestore = ref.read(firestoreProvider);
      await firestore.collection('users').doc(profile.uid).update({
        'showcaseBadges': _selectedBadgeIds,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vitrin rozetleri güncellendi ✓')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Hata oluştu: $e',
            style: TextStyle(color: Theme.of(context).colorScheme.onError),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final profile = ref.watch(userProfileProvider).asData?.value;

    if (profile == null) {
      return const Scaffold(
        body: Center(child: Text('Kullanıcı oturumu bulunamadı.')),
      );
    }

    // Filter to only user's earned badges
    final earnedBadges = BadgeDefinitions.all
        .where((badge) => profile.badges.contains(badge.id))
        .toList();

    final isMaxSelected = _selectedBadgeIds.length >= 3;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vitrin Rozetlerini Seç'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Kaydet',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profilinde göstermek istediğin 3 rozeti seç',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: earnedBadges.isEmpty
                    ? Center(
                        child: Text(
                          'Henüz kazanılmış bir rozetin bulunmuyor.\nÖnce turnuvalara katılıp rozet kazanmalısın!',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.95,
                        ),
                        itemCount: earnedBadges.length,
                        itemBuilder: (context, index) {
                          final badge = earnedBadges[index];
                          final isSelected = _selectedBadgeIds.contains(badge.id);
                          final isSelectionDisabled = !isSelected && isMaxSelected;

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: isSelectionDisabled
                                  ? null
                                  : () {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedBadgeIds.remove(badge.id);
                                        } else {
                                          _selectedBadgeIds.add(badge.id);
                                        }
                                      });
                                    },
                              child: Opacity(
                                opacity: isSelectionDisabled ? 0.4 : 1.0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? scheme.primary.withValues(alpha: 0.10)
                                        : scheme.surface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected
                                          ? scheme.primary
                                          : scheme.outline.withValues(alpha: 0.15),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            badge.icon,
                                            size: 28,
                                            color: isSelected
                                                ? scheme.primary
                                                : scheme.onSurface,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            badge.name,
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.labelSmall?.copyWith(
                                              color: scheme.onSurface,
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (isSelected)
                                        Positioned(
                                          top: 0,
                                          right: 0,
                                          child: Icon(
                                            Icons.check_circle,
                                            color: scheme.primary,
                                            size: 18,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
