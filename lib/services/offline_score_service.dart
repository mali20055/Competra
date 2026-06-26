import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../models/pending_score.dart';

class OfflineScoreService {
  static Box<PendingScore>? _box;

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(PendingScoreAdapter());
    _box = await Hive.openBox<PendingScore>('pending_scores');
  }

  static Future<void> saveScore(PendingScore score) async {
    await _box?.add(score);
  }

  static List<PendingScore> getPendingScores() =>
      _box?.values.toList() ?? [];

  static Future<void> clearScore(int index) async {
    await _box?.deleteAt(index);
  }
}
