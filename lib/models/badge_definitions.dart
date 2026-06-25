import 'package:flutter/material.dart';

/// Tek bir rozetin tanımı.
///
/// Rozet koşulları (nasıl kazanıldığı) burada tutulmaz; bir kısmı yalnızca
/// toplam istatistiklerden, bir kısmı ise maç/turnuva bazlı olaylardan kazanılır
/// (rozet türetimi artık Cloud Functions tarafında yapılır). [isEarned] yalnızca
/// görüntüleme için bir bayraktır.
class BadgeDefinition {
  const BadgeDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.isEarned = false,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final bool isEarned;

  BadgeDefinition copyWith({bool? isEarned}) => BadgeDefinition(
        id: id,
        name: name,
        description: description,
        icon: icon,
        isEarned: isEarned ?? this.isEarned,
      );
}

/// Uygulamadaki tüm rozetlerin kataloğu.
class BadgeDefinitions {
  const BadgeDefinitions._();

  static const List<BadgeDefinition> all = [
    BadgeDefinition(
      id: 'first_tournament',
      name: 'İlk Adım',
      description: 'İlk turnuvana katıldın.',
      icon: Icons.flag_outlined,
    ),
    BadgeDefinition(
      id: 'champion',
      name: 'Şampiyon',
      description: 'Bir turnuvayı kazandın.',
      icon: Icons.emoji_events,
    ),
    BadgeDefinition(
      id: 'veteran',
      name: 'Veteran',
      description: '10 turnuva oynadın.',
      icon: Icons.military_tech,
    ),
    BadgeDefinition(
      id: 'legend',
      name: 'Efsane',
      description: '5 turnuva kazandın.',
      icon: Icons.workspace_premium,
    ),
    BadgeDefinition(
      id: 'goal_machine',
      name: 'Gol Makinesi',
      description: 'Toplam 50 gol attın.',
      icon: Icons.sports_soccer,
    ),
    BadgeDefinition(
      id: 'iron_wall',
      name: 'Demir Duvar',
      description: 'Bir turnuvada en az gol yiyen oyuncu oldun.',
      icon: Icons.security,
    ),
    BadgeDefinition(
      id: 'hat_trick_hero',
      name: 'Hat-trick Kahramanı',
      description: 'Bir maçta 3 veya daha fazla gol attın.',
      icon: Icons.local_fire_department,
    ),
    BadgeDefinition(
      id: 'comeback_king',
      name: 'Geri Dönüş Kralı',
      description: '0-2 geriden gelerek bir maçı kazandın.',
      icon: Icons.trending_up,
    ),
    BadgeDefinition(
      id: 'prophet',
      name: 'Kahin',
      description: 'Turnuva kazananını doğru tahmin etti',
      icon: Icons.auto_awesome,
    ),
    BadgeDefinition(
      id: 'mvp',
      name: 'En Değerli Oyuncu',
      description: 'Turnuvanın MVP\'si seçildi',
      icon: Icons.star,
    ),
  ];

  /// Verilen id'ye sahip rozet tanımını döner (yoksa null).
  static BadgeDefinition? byId(String id) {
    for (final b in all) {
      if (b.id == id) return b;
    }
    return null;
  }
}
