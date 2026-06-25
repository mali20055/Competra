class RosterEntry {
  final String uid;
  final String? teamName;
  final String teamColor; // hex renk kodu, varsayılan '#4CAF50'

  const RosterEntry({
    required this.uid,
    this.teamName,
    this.teamColor = '#4CAF50',
  });

  factory RosterEntry.fromMap(Map<String, dynamic> map) {
    return RosterEntry(
      uid: (map['uid'] as String?) ?? '',
      teamName: map['teamName'] as String?,
      teamColor: (map['teamColor'] as String?) ?? '#4CAF50',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'teamName': teamName,
      'teamColor': teamColor,
    };
  }
}
