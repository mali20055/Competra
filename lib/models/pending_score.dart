import 'package:hive_ce/hive_ce.dart';

@HiveType(typeId: 0)
class PendingScore extends HiveObject {
  @HiveField(0) late String tournamentId;
  @HiveField(1) late String matchId;
  @HiveField(2) late int homeScore;
  @HiveField(3) late int awayScore;
  @HiveField(4) late DateTime createdAt;
}

class PendingScoreAdapter extends TypeAdapter<PendingScore> {
  @override
  final int typeId = 0;

  @override
  PendingScore read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PendingScore()
      ..tournamentId = fields[0] as String
      ..matchId = fields[1] as String
      ..homeScore = fields[2] as int
      ..awayScore = fields[3] as int
      ..createdAt = fields[4] as DateTime;
  }

  @override
  void write(BinaryWriter writer, PendingScore obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.tournamentId)
      ..writeByte(1)
      ..write(obj.matchId)
      ..writeByte(2)
      ..write(obj.homeScore)
      ..writeByte(3)
      ..write(obj.awayScore)
      ..writeByte(4)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingScoreAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
