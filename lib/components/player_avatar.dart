import 'package:flutter/material.dart';

import '../models/avatar_frame.dart';

class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.name,
    this.radius = 20,
    this.activeFrame = 'default',
  });

  final String name;
  final double radius;
  final String activeFrame;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final initials = name.isEmpty
        ? '?'
        : name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();

    final frame = AvatarFrame.getFrame(activeFrame);

    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primary.withValues(alpha: 0.15),
      child: Text(
        initials,
        style: theme.textTheme.titleMedium?.copyWith(
          color: scheme.primary,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    if (frame.id == 'default') {
      return avatar;
    }

    final List<Color> borderColors = frame.secondaryColor != null
        ? [frame.primaryColor, frame.secondaryColor!]
        : [frame.primaryColor, frame.primaryColor];

    // Çerçevenin etrafındaki dolgulu alan ve avatar
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: (radius + 3) * 2,
          height: (radius + 3) * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: borderColors.length > 1
                ? SweepGradient(
                    colors: borderColors,
                  )
                : null,
            color: borderColors.length == 1 ? borderColors.first : null,
          ),
        ),
        // Gradient'in üzerine maske gibi arkaplan renginde bir daire koyuyoruz ki ortası boşalsın (çerçeve gibi dursun)
        Container(
          width: radius * 2 + 2,
          height: radius * 2 + 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.scaffoldBackgroundColor,
          ),
        ),
        avatar,
        if (frame.id == 'champion')
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Color(0xFFFFD700), // Gold
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                  )
                ]
              ),
              child: const Icon(
                Icons.emoji_events,
                size: 10,
                color: Colors.black,
              ),
            ),
          ),
      ],
    );
  }
}
