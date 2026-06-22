import 'package:cloud_firestore/cloud_firestore.dart';

/// Puan eşitliğinde uygulanacak averaj / sıralama modu.
///
/// - [fifa]  : MOD A — genel averaj önce (Premier League stili)
/// - [uefa]  : MOD B — ikili (head-to-head) averaj önce (La Liga / UEFA stili)
/// - [hybrid]: MOD C — karma (genel averaj + ikili tiebreaker)
enum TiebreakerMode {
  fifa,
  uefa,
  hybrid;

  /// Firestore'da saklanan string değer.
  String get value => name;

  /// Kullanıcıya gösterilen Türkçe etiket.
  String get label => switch (this) {
        TiebreakerMode.fifa => 'FIFA Stili',
        TiebreakerMode.uefa => 'UEFA Stili',
        TiebreakerMode.hybrid => 'Karma',
      };

  /// Kısa açıklama.
  String get description => switch (this) {
        TiebreakerMode.fifa => 'Genel averaj önce',
        TiebreakerMode.uefa => 'İkili averaj önce',
        TiebreakerMode.hybrid => 'Genel averaj + ikili tiebreaker',
      };

  /// Firestore string'inden çözer. Bilinmeyen/boş değer uygulama varsayılanı
  /// olan [uefa]'ya düşer.
  static TiebreakerMode fromString(String? value) {
    switch (value) {
      case 'fifa':
        return TiebreakerMode.fifa;
      case 'hybrid':
        return TiebreakerMode.hybrid;
      case 'uefa':
      default:
        return TiebreakerMode.uefa;
    }
  }
}

/// Bir turnuva katılımcısı (oyuncu).
class Participant {
  const Participant({required this.uid, required this.username});

  final String uid;
  final String username;

  factory Participant.fromMap(Map<String, dynamic> map) => Participant(
        uid: (map['uid'] as String?) ?? '',
        username: (map['username'] as String?) ?? 'Oyuncu',
      );

  Map<String, dynamic> toMap() => {'uid': uid, 'username': username};
}

/// Firestore'daki `tournaments/{id}` belgesinin model karşılığı.
class Tournament {
  const Tournament({
    required this.id,
    required this.name,
    required this.note,
    required this.format,
    required this.scoreMode,
    required this.scoreEntrySystem,
    required this.inviteCode,
    required this.ownerId,
    required this.participants,
    required this.status,
    required this.tiebreakerMode,
    required this.createdAt,
    required this.currentPhase,
  });

  final String id;
  final String name;
  final String note;
  final String format;
  final String scoreMode;

  /// Skor giriş sistemi (kanonik): 'adminOnly' | 'winnerEntry' | 'doubleEntry'.
  ///
  /// Eski belgelerdeki `scoreMode` enum adları ('bothPlayers'/'winnerEnters'/
  /// 'adminOnly') buraya normalize edilir (bkz. [_normalizeScoreEntry]).
  final String scoreEntrySystem;
  final String inviteCode;
  final String ownerId;
  final List<Participant> participants;

  /// 'waiting' | 'active' | 'completed'. Eski belgelerde alan yoksa 'active'.
  final String status;

  /// Puan eşitliğinde uygulanacak sıralama modu.
  final TiebreakerMode tiebreakerMode;
  final DateTime? createdAt;

  /// Turnuvanın bulunduğu aşama:
  /// 'waiting' | 'league' | 'group' | 'knockout' | 'completed'.
  ///
  /// Belgede yoksa duruma/formata göre türetilir (bkz. [_derivePhase]); çok
  /// aşamalı formatlarda (grup+eleme, Şampiyonlar Ligi) aşama geçişlerini izler.
  final String currentPhase;

  bool get isCompleted => status == 'completed';
  bool get isWaiting => status == 'waiting';

  /// Eleme aşamasında mı? (grup/lig fazından sonra)
  bool get isKnockoutPhase => currentPhase == 'knockout';

  /// Belgede `currentPhase` yoksa duruma ve formata göre türetir.
  static String _derivePhase(
    Map<String, dynamic> data,
    String format,
    String status,
  ) {
    final raw = data['currentPhase'] as String?;
    if (raw != null && raw.isNotEmpty) return raw;
    if (status == 'completed') return 'completed';
    if (status == 'waiting') return 'waiting';
    switch (format) {
      case 'knockout':
        return 'knockout';
      case 'groupKnockout':
      case 'groupElimination':
        return 'group';
      case 'championsLeague':
      case 'league':
      default:
        return 'league';
    }
  }

  /// Yalnızca yöneticinin skor girdiği mod.
  bool get isAdminOnlyScoring => scoreEntrySystem == 'adminOnly';

  /// Kazananın (bir tarafın) skoru girip rakibin onayladığı mod.
  bool get isWinnerEntryScoring => scoreEntrySystem == 'winnerEntry';

  /// Her iki oyuncunun ayrı ayrı skor girip eşleşmesi gereken mod.
  bool get isDoubleEntryScoring => scoreEntrySystem == 'doubleEntry';

  /// `scoreEntrySystem` (yoksa eski `scoreMode`) değerini kanonik forma çevirir.
  static String _normalizeScoreEntry(Map<String, dynamic> data) {
    final raw = (data['scoreEntrySystem'] as String?) ??
        (data['scoreMode'] as String?) ??
        '';
    switch (raw) {
      case 'adminOnly':
        return 'adminOnly';
      case 'winnerEntry':
      case 'winnerEnters':
        return 'winnerEntry';
      case 'doubleEntry':
      case 'bothPlayers':
        return 'doubleEntry';
      default:
        return 'doubleEntry';
    }
  }

  factory Tournament.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawParticipants = (data['participants'] as List?) ?? const [];
    return Tournament(
      id: doc.id,
      name: (data['name'] as String?) ?? 'Turnuva',
      note: (data['note'] as String?) ?? '',
      format: (data['format'] as String?) ?? '',
      scoreMode: (data['scoreMode'] as String?) ?? '',
      scoreEntrySystem: _normalizeScoreEntry(data),
      inviteCode: (data['inviteCode'] as String?) ?? '',
      ownerId: (data['ownerId'] as String?) ?? '',
      participants: [
        for (final p in rawParticipants)
          Participant.fromMap(Map<String, dynamic>.from(p as Map)),
      ],
      status: (data['status'] as String?) ?? 'active',
      tiebreakerMode:
          TiebreakerMode.fromString(data['tiebreakerMode'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      currentPhase: _derivePhase(
        data,
        (data['format'] as String?) ?? '',
        (data['status'] as String?) ?? 'active',
      ),
    );
  }
}

/// `tournaments/{id}/matches/{matchId}` belgesinin model karşılığı.
class TournamentMatch {
  const TournamentMatch({
    required this.id,
    required this.round,
    required this.order,
    required this.homeUid,
    required this.homeName,
    required this.awayUid,
    required this.awayName,
    required this.homeScore,
    required this.awayScore,
    required this.isBye,
    required this.status,
    required this.enteredBy,
    required this.enteredHomeScore,
    required this.enteredAwayScore,
    required this.secondEnteredBy,
    required this.secondEnteredHomeScore,
    required this.secondEnteredAwayScore,
    this.roundNumber = 1,
    this.phase = '',
    this.group = '',
    this.leg = 1,
  });

  final String id;

  /// Kullanıcıya gösterilen tur etiketi ('Final', '1. Hafta' vb.).
  final String round;

  /// Eleme formatında sayısal tur numarası (1 = açılış turu). Tur ilerletmede
  /// ([generateNextKnockoutRound]) ve [Tournament] `currentRound` ile birlikte
  /// kullanılır. Lig/grup maçlarında anlamsızdır (varsayılan 1).
  final int roundNumber;

  /// Maç fazı: 'knockout' | 'group' | 'league' (eski belgelerde boş olabilir).
  final String phase;

  /// Grup aşamasındaki maçın grup etiketi ('A', 'B'…). Diğer fazlarda boştur.
  final String group;

  /// Çift maçlı (iki ayaklı) eleme aşamasında ayak numarası: 1 (ev) veya 2
  /// (rövanş/deplasman). Tek maçlı maçlarda ve diğer fazlarda 1'dir.
  final int leg;

  final int order;
  final String homeUid;
  final String homeName;
  final String awayUid;
  final String awayName;
  final int? homeScore;
  final int? awayScore;

  /// Bye maçı: oyuncu otomatik tur atlar. Averaja/gol krallığına dahil edilmez.
  final bool isBye;

  /// Maç durumu: 'pending' | 'awaitingConfirmation' | 'completed' | 'disputed'.
  ///
  /// Eski belgelerde alan yoksa skordan türetilir (oynandıysa 'completed').
  final String status;

  /// İlk skoru giren oyuncunun UID'si (winnerEntry/doubleEntry akışı).
  final String enteredBy;

  /// İlk girilen (henüz kesinleşmemiş) ev sahibi/deplasman skoru.
  final int? enteredHomeScore;
  final int? enteredAwayScore;

  /// doubleEntry modunda ikinci oyuncunun girişi (uyuşmazlık halinde saklanır).
  final String secondEnteredBy;
  final int? secondEnteredHomeScore;
  final int? secondEnteredAwayScore;

  /// Her iki skor da girilmişse maç oynanmış sayılır.
  bool get isPlayed => homeScore != null && awayScore != null;

  /// Karşı tarafın onayını/girişini bekliyor.
  bool get isAwaitingConfirmation => status == 'awaitingConfirmation';

  /// Skorlar üzerinde anlaşmazlık var; yöneticinin çözmesi gerekir.
  bool get isDisputed => status == 'disputed';

  /// Maç kesinleşti (durum 'completed' ya da eski belgede skor girilmiş).
  bool get isFinal => status == 'completed' || (status.isEmpty && isPlayed);

  factory TournamentMatch.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    int? intOrNull(String key) => (data[key] as num?)?.toInt();
    return TournamentMatch(
      id: doc.id,
      round: (data['round'] as String?) ?? '',
      order: (data['order'] as num?)?.toInt() ?? 0,
      homeUid: (data['homeUid'] as String?) ?? '',
      homeName: (data['homeName'] as String?) ?? 'Oyuncu',
      awayUid: (data['awayUid'] as String?) ?? '',
      awayName: (data['awayName'] as String?) ?? 'Oyuncu',
      homeScore: intOrNull('homeScore'),
      awayScore: intOrNull('awayScore'),
      isBye: (data['isBye'] as bool?) ?? false,
      status: (data['status'] as String?) ?? '',
      enteredBy: (data['enteredBy'] as String?) ?? '',
      enteredHomeScore: intOrNull('enteredHomeScore'),
      enteredAwayScore: intOrNull('enteredAwayScore'),
      secondEnteredBy: (data['secondEnteredBy'] as String?) ?? '',
      secondEnteredHomeScore: intOrNull('secondEnteredHomeScore'),
      secondEnteredAwayScore: intOrNull('secondEnteredAwayScore'),
      roundNumber: (data['roundNumber'] as num?)?.toInt() ?? 1,
      // phase yoksa veya boşsa eski `stage` alanına düşülür.
      phase: () {
        final p = data['phase'] as String?;
        if (p != null && p.isNotEmpty) return p;
        return (data['stage'] as String?) ?? '';
      }(),
      group: (data['group'] as String?) ?? '',
      leg: (data['leg'] as num?)?.toInt() ?? 1,
    );
  }
}

/// Puan tablosundaki tek bir satır (oynanan maçlardan hesaplanır).
class StandingRow {
  StandingRow({required this.uid, required this.name});

  final String uid;
  final String name;

  int played = 0;
  int won = 0;
  int drawn = 0;
  int lost = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;

  /// Averaj (atılan - yenilen).
  int get goalDiff => goalsFor - goalsAgainst;

  /// Puan: galibiyet 3, beraberlik 1.
  int get points => won * 3 + drawn;
}

/// Gol krallığı listesindeki tek bir oyuncu.
class ScorerRow {
  const ScorerRow({
    required this.uid,
    required this.name,
    required this.goals,
  });

  final String uid;
  final String name;
  final int goals;
}

/// Puan tablosu tiebreaker kriterleri (yüksek değer = üstte).
enum _TbKey {
  overallGoalDiff,
  overallGoalsFor,
  headToHeadPoints,
  headToHeadGoalDiff,
  headToHeadGoalsFor,
}

/// Her [TiebreakerMode] için, puan eşitliğinde uygulanacak kriter sırası.
///
/// Doküman Bölüm 3.3'teki tablonun kod karşılığıdır. Son eşitlik bozucu olan
/// "kura", canlı tabloda titremeyi önlemek için deterministik kayıt sırasıyla
/// gerçeklenir (bkz. Edge Case 5).
List<_TbKey> _criteriaFor(TiebreakerMode mode) {
  switch (mode) {
    // MOD A: puan → genel averaj → genel AG → ikili averaj → kura
    case TiebreakerMode.fifa:
      return const [
        _TbKey.overallGoalDiff,
        _TbKey.overallGoalsFor,
        _TbKey.headToHeadGoalDiff,
      ];
    // MOD B: puan → ikili puan → ikili averaj → ikili AG → genel averaj → genel AG → kura
    case TiebreakerMode.uefa:
      return const [
        _TbKey.headToHeadPoints,
        _TbKey.headToHeadGoalDiff,
        _TbKey.headToHeadGoalsFor,
        _TbKey.overallGoalDiff,
        _TbKey.overallGoalsFor,
      ];
    // MOD C: puan → genel averaj → genel AG → ikili averaj → ikili AG → kura
    case TiebreakerMode.hybrid:
      return const [
        _TbKey.overallGoalDiff,
        _TbKey.overallGoalsFor,
        _TbKey.headToHeadGoalDiff,
        _TbKey.headToHeadGoalsFor,
      ];
  }
}

/// Katılımcılar ve oynanmış maçlardan, seçilen [mode]'a göre puan tablosunu
/// hesaplar.
///
/// Sıralama önce puana göredir; puan eşitliğinde kriterler [mode]'a göre
/// uygulanır. İkili (head-to-head) kriterler, o an hâlâ eşit olan alt grup
/// üzerinden hesaplanır; böylece doküman Bölüm 3.2'deki mini-tablo mantığı
/// (3+ oyuncu eşitliği dahil) sağlanır.
///
/// Ele alınan kenar durumlar (Bölüm 6): yalnızca tamamlanmış maçlar sayılır;
/// bye maçları averaja katılmaz; sıfır maçta sıralama kayıt sırasına göredir;
/// negatif averaj geçerlidir.
List<StandingRow> computeStandings(
  List<Participant> participants,
  List<TournamentMatch> matches,
  TiebreakerMode mode,
) {
  // Kayıt sırası — deterministik son eşitlik bozucu.
  final regIndex = <String, int>{};
  for (var i = 0; i < participants.length; i++) {
    regIndex[participants[i].uid] = i;
  }

  final rows = <String, StandingRow>{
    for (final p in participants)
      p.uid: StandingRow(uid: p.uid, name: p.username),
  };

  StandingRow rowFor(String uid, String name) {
    regIndex.putIfAbsent(uid, () => regIndex.length);
    return rows.putIfAbsent(uid, () => StandingRow(uid: uid, name: name));
  }

  // Yalnızca tamamlanmış, bye olmayan maçlar tabloya işlenir.
  final counted = matches.where((m) => m.isPlayed && !m.isBye).toList();

  for (final m in counted) {
    final home = rowFor(m.homeUid, m.homeName);
    final away = rowFor(m.awayUid, m.awayName);
    final hs = m.homeScore!;
    final as = m.awayScore!;

    home.played++;
    away.played++;
    home.goalsFor += hs;
    home.goalsAgainst += as;
    away.goalsFor += as;
    away.goalsAgainst += hs;

    if (hs > as) {
      home.won++;
      away.lost++;
    } else if (hs < as) {
      away.won++;
      home.lost++;
    } else {
      home.drawn++;
      away.drawn++;
    }
  }

  final all = rows.values.toList()
    ..sort((a, b) => b.points.compareTo(a.points));

  final criteria = _criteriaFor(mode);
  final result = <StandingRow>[];

  // Eşit puanlı grupları belirle ve her birini kritere göre çöz.
  var i = 0;
  while (i < all.length) {
    var j = i;
    while (j < all.length && all[j].points == all[i].points) {
      j++;
    }
    final group = all.sublist(i, j);
    if (group.length == 1) {
      result.add(group.first);
    } else {
      result.addAll(_rankTiedGroup(group, counted, criteria, 0, regIndex));
    }
    i = j;
  }

  return result;
}

/// Eşit puanlı bir grubu, [criteria] sırasını izleyerek özyinelemeli çözer.
List<StandingRow> _rankTiedGroup(
  List<StandingRow> group,
  List<TournamentMatch> matches,
  List<_TbKey> criteria,
  int criterionIndex,
  Map<String, int> regIndex,
) {
  if (group.length <= 1) return group;

  // Kriterler tükendi → deterministik kayıt sırası (kura yerine).
  if (criterionIndex >= criteria.length) {
    final sorted = [...group]
      ..sort((a, b) =>
          (regIndex[a.uid] ?? 0).compareTo(regIndex[b.uid] ?? 0));
    return sorted;
  }

  final key = criteria[criterionIndex];
  // İkili kriterler bu alt grup üzerinden hesaplanır (mini-tablo).
  final h2h = _headToHead(group, matches);

  int keyOf(StandingRow row) {
    switch (key) {
      case _TbKey.overallGoalDiff:
        return row.goalDiff;
      case _TbKey.overallGoalsFor:
        return row.goalsFor;
      case _TbKey.headToHeadPoints:
        return h2h[row.uid]?.points ?? 0;
      case _TbKey.headToHeadGoalDiff:
        return h2h[row.uid]?.goalDiff ?? 0;
      case _TbKey.headToHeadGoalsFor:
        return h2h[row.uid]?.goalsFor ?? 0;
    }
  }

  final sorted = [...group]..sort((a, b) => keyOf(b).compareTo(keyOf(a)));

  // Eşit anahtarlı alt grupları bir sonraki kritere taşı.
  final result = <StandingRow>[];
  var i = 0;
  while (i < sorted.length) {
    var j = i;
    while (j < sorted.length && keyOf(sorted[j]) == keyOf(sorted[i])) {
      j++;
    }
    final sub = sorted.sublist(i, j);
    if (sub.length == 1) {
      result.add(sub.first);
    } else {
      result.addAll(
        _rankTiedGroup(sub, matches, criteria, criterionIndex + 1, regIndex),
      );
    }
    i = j;
  }
  return result;
}

/// Verilen oyuncu grubunun yalnızca kendi aralarındaki maçlardan ikili
/// (head-to-head) istatistiklerini hesaplar.
Map<String, ({int points, int goalDiff, int goalsFor})> _headToHead(
  List<StandingRow> group,
  List<TournamentMatch> matches,
) {
  final ids = {for (final r in group) r.uid};
  final points = {for (final id in ids) id: 0};
  final goalDiff = {for (final id in ids) id: 0};
  final goalsFor = {for (final id in ids) id: 0};

  for (final m in matches) {
    if (!ids.contains(m.homeUid) || !ids.contains(m.awayUid)) continue;
    final hs = m.homeScore!;
    final as = m.awayScore!;

    goalsFor[m.homeUid] = goalsFor[m.homeUid]! + hs;
    goalsFor[m.awayUid] = goalsFor[m.awayUid]! + as;
    goalDiff[m.homeUid] = goalDiff[m.homeUid]! + (hs - as);
    goalDiff[m.awayUid] = goalDiff[m.awayUid]! + (as - hs);

    if (hs > as) {
      points[m.homeUid] = points[m.homeUid]! + 3;
    } else if (hs < as) {
      points[m.awayUid] = points[m.awayUid]! + 3;
    } else {
      points[m.homeUid] = points[m.homeUid]! + 1;
      points[m.awayUid] = points[m.awayUid]! + 1;
    }
  }

  return {
    for (final id in ids)
      id: (
        points: points[id]!,
        goalDiff: goalDiff[id]!,
        goalsFor: goalsFor[id]!,
      ),
  };
}

/// Oynanmış maçlardan gol krallığını hesaplar (her oyuncunun attığı toplam gol).
///
/// Gol atmamış oyuncular listeye dahil edilmez. Sıralama: gole göre azalan,
/// eşitlikte ada göre.
List<ScorerRow> computeScorers(
  List<Participant> participants,
  List<TournamentMatch> matches,
) {
  final goals = <String, int>{};
  final names = <String, String>{for (final p in participants) p.uid: p.username};

  void add(String uid, String name, int count) {
    if (count <= 0) return;
    names.putIfAbsent(uid, () => name);
    goals.update(uid, (v) => v + count, ifAbsent: () => count);
  }

  for (final m in matches) {
    if (!m.isPlayed || m.isBye) continue;
    add(m.homeUid, m.homeName, m.homeScore!);
    add(m.awayUid, m.awayName, m.awayScore!);
  }

  final list = goals.entries
      .map((e) => ScorerRow(
            uid: e.key,
            name: names[e.key] ?? 'Oyuncu',
            goals: e.value,
          ))
      .toList()
    ..sort((a, b) {
      final byGoals = b.goals.compareTo(a.goals);
      if (byGoals != 0) return byGoals;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  return list;
}
