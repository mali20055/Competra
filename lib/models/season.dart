import 'package:cloud_firestore/cloud_firestore.dart';

class Season {
  final String id;
  final String name;       // "Haziran 2026 Sezonu"
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;

  const Season({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.isActive,
  });

  factory Season.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Season(
      id: doc.id,
      name: (data['name'] as String?) ?? 'Yeni Sezon',
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: (data['isActive'] as bool?) ?? false,
    );
  }
}
