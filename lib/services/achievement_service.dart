import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/title_definitions.dart';
import '../models/user_profile.dart';
import 'firebase_providers.dart';

/// Kullanıcının toplam istatistiklerine bakarak yeni rozetleri kazandırır ve en
/// prestijli (yüksek priority) unvanı `activeTitle` olarak atar.
///
/// İstatistik güncellemesi yapan akışlar (maç tamamlama vb.) sonrasında
/// çağrılmalıdır.
class AchievementService {
  AchievementService(this._firestore);

  final FirebaseFirestore _firestore;

  /// Yalnızca toplam istatistiklerden TÜRETİLEBİLEN rozet koşulları.
  ///
  /// `iron_wall`, `hat_trick_hero`, `comeback_king` maç/turnuva bazlı olaylardan
  /// kazanılır (tek bir maçtaki gol, geri dönüş, turnuvada en az gol yeme gibi);
  /// bunlar ilgili maç işleme mantığında verilmelidir, burada türetilmez.
  static final Map<String, bool Function(UserProfile)> _badgeConditions = {
    'first_tournament': (p) => p.tournamentsPlayed >= 1,
    'champion': (p) => p.tournamentsWon >= 1,
    'veteran': (p) => p.tournamentsPlayed >= 10,
    'legend': (p) => p.tournamentsWon >= 5,
    'goal_machine': (p) => p.totalGoalsScored >= 50,
  };

  /// `users/{uid}` belgesini çekip rozet ve unvan durumunu yeniden hesaplar;
  /// değişiklik varsa yalnızca `badges` ve `activeTitle` alanlarını günceller.
  Future<void> checkAndUpdateAchievements(String uid) async {
    final ref = _firestore.collection('users').doc(uid);
    final snap = await ref.get();
    if (!snap.exists) return;

    final profile = UserProfile.fromDoc(snap);

    // 1) Yeni kazanılan rozetler.
    final earned = Set<String>.from(profile.badges);
    var badgesChanged = false;
    _badgeConditions.forEach((id, condition) {
      if (!earned.contains(id) && condition(profile)) {
        earned.add(id);
        badgesChanged = true;
      }
    });

    // 2) En yüksek priority'li uygun unvan.
    String? bestTitle;
    var bestPriority = -1;
    for (final title in TitleDefinitions.all) {
      if (title.condition(profile) && title.priority > bestPriority) {
        bestPriority = title.priority;
        bestTitle = title.label;
      }
    }

    // 3) Yalnızca değişen alanları yaz.
    final update = <String, dynamic>{};
    if (badgesChanged) {
      update['badges'] = earned.toList();
    }
    if (bestTitle != null && bestTitle != profile.activeTitle) {
      update['activeTitle'] = bestTitle;
    }
    if (update.isNotEmpty) {
      await ref.set(update, SetOptions(merge: true));
    }
  }
}

final achievementServiceProvider = Provider<AchievementService>(
  (ref) => AchievementService(ref.watch(firestoreProvider)),
);
