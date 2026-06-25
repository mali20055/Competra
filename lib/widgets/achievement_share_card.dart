import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../models/badge_definitions.dart';

class AchievementShareCard extends StatelessWidget {
  const AchievementShareCard({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    // Dark green theme (#0D2818) as specified
    const darkBgColor = Color(0xFF0D2818);
    const goldColor = Color(0xFFFFD700);

    return SizedBox(
      width: 200,
      height: 350,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1E5E3A), width: 1.5),
        ),
        color: darkBgColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Brand header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sports_soccer, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    'COMPETRA',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white.withValues(alpha: 0.9),
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              
              // Profile photo & name
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.white24,
                    backgroundImage: profile.photoUrl.isNotEmpty
                        ? NetworkImage(profile.photoUrl)
                        : null,
                    child: profile.photoUrl.isEmpty
                        ? Text(
                            profile.username.isEmpty
                                ? '?'
                                : profile.username.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    profile.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  
                  // Active title chip
                  if (profile.activeTitle.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: goldColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: goldColor.withValues(alpha: 0.5), width: 0.8),
                      ),
                      child: Text(
                        profile.activeTitle,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: goldColor,
                        ),
                      ),
                    ),
                ],
              ),
              
              // ELO Value with bolt icon
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bolt, size: 16, color: Colors.amber),
                  Text(
                    '${profile.eloRating} ELO',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
              
              // Showcase badges (max 3)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (profile.showcaseBadges.isEmpty)
                    Text(
                      'Rozet Vitrini Boş',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.3),
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    for (var i = 0; i < profile.showcaseBadges.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      _buildShowcaseBadge(profile.showcaseBadges[i]),
                    ],
                ],
              ),
              
              // Stats Container
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('${profile.wins} G', 'Galibiyet'),
                    _buildStatItem('${profile.goals} Gol', 'Gol'),
                  ],
                ),
              ),
              
              // Bottom brand footer URL
              Text(
                'competra.app',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.4),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShowcaseBadge(String badgeId) {
    final badge = BadgeDefinitions.byId(badgeId);
    if (badge == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 0.8),
      ),
      child: Icon(
        badge.icon,
        size: 16,
        color: Colors.white,
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
