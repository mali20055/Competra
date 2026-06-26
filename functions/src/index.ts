/**
 * Competra Cloud Functions
 * =========================
 *
 * Tek tetikleyici: bir maç belgesi yazıldığında çalışır. İki kritik sorunu çözer:
 *
 *   1) Mod B/C'de (winnerEntry/doubleEntry) admin olmayan oyuncu son skoru
 *      girdiğinde sonraki tur maçlarının oluşturulamaması. Artık maçlar admin
 *      SDK ile (güvenlik kurallarını bypass ederek) sunucuda üretilir.
 *
 *   2) İstatistik yazımının istemci-güvenli olması. Tüm istatistik artışları,
 *      şampiyon belirleme ve tur ilerletme artık SUNUCUDA yapılır; istemci
 *      yalnızca maç skorunu yazar (firestore.rules buna göre sıkılaştırıldı).
 *
 * İstemci mantığının (tournament_repository.dart, fixture_generator.dart,
 * achievement_service.dart, social_repository.dart) sunucu portudur.
 */

import {onDocumentWritten, onDocumentCreated} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";
import * as admin from "firebase-admin";
import {onSchedule} from "firebase-functions/v2/scheduler";

import {
  Match,
  Participant,
  Tournament,
  isFinal,
  isPlayed,
  parseMatch,
  parseTournament,
} from "./types";
import {computeStandings} from "./standings";
import {
  generateKnockoutFromGroups,
  generateKnockoutFromSeeds,
  generateNextKnockoutRound,
} from "./fixtures";
import {deriveAchievementUpdate, parseUserStats} from "./achievements";
import {updateElo} from "./elo";

admin.initializeApp();
const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;
type DocRef = FirebaseFirestore.DocumentReference;

// ---------------------------------------------------------------------------
// Tetikleyici
// ---------------------------------------------------------------------------

export const onMatchWritten = onDocumentWritten(
  {
    document: "tournaments/{tournamentId}/matches/{matchId}",
    region: "europe-west3",
    minInstances: 1,
    timeoutSeconds: 60,
  },
  async (event) => {
    const {tournamentId, matchId} = event.params as {
      tournamentId: string;
      matchId: string;
    };

    const after = event.data?.after;
    if (!after || !after.exists) return; // maç silindi → işlem yok

    const before = event.data?.before;
    const afterMatch = parseMatch(matchId, after.data()!);
    const beforeFinal =
      before && before.exists ? isFinal(parseMatch(matchId, before.data()!)) : false;

    // Maç bu yazımla ilk kez kesinleşti mi? (idempotent geçiş kontrolü)
    const becameFinal = isFinal(afterMatch) && !beforeFinal;

    if (
      becameFinal &&
      !afterMatch.isBye &&
      afterMatch.homeUid.length > 0 &&
      afterMatch.awayUid.length > 0
    ) {
      try {
        const applied = await applyMatchStats(tournamentId, matchId);
        if (applied) {
          // Sezon istatistiklerini güncelle
          try {
            const seasonSnap = await db.collection("seasons")
              .where("isActive", "==", true).limit(1).get();
            if (!seasonSnap.empty) {
              const seasonId = seasonSnap.docs[0].id;
              const homeWin = applied.homeScore > applied.awayScore;
              const awayWin = applied.awayScore > applied.homeScore;

              const homeSeasonDelta: Record<string, any> = {};
              const awaySeasonDelta: Record<string, any> = {};

              homeSeasonDelta[`seasonStats.${seasonId}.totalMatches`] = FieldValue.increment(1);
              homeSeasonDelta[`seasonStats.${seasonId}.totalGoalsScored`] = FieldValue.increment(applied.homeScore);
              homeSeasonDelta[`seasonStats.${seasonId}.totalGoalsConceded`] = FieldValue.increment(applied.awayScore);
              if (homeWin) homeSeasonDelta[`seasonStats.${seasonId}.totalWins`] = FieldValue.increment(1);
              if (awayWin) homeSeasonDelta[`seasonStats.${seasonId}.totalLosses`] = FieldValue.increment(1);

              awaySeasonDelta[`seasonStats.${seasonId}.totalMatches`] = FieldValue.increment(1);
              awaySeasonDelta[`seasonStats.${seasonId}.totalGoalsScored`] = FieldValue.increment(applied.awayScore);
              awaySeasonDelta[`seasonStats.${seasonId}.totalGoalsConceded`] = FieldValue.increment(applied.homeScore);
              if (awayWin) awaySeasonDelta[`seasonStats.${seasonId}.totalWins`] = FieldValue.increment(1);
              if (homeWin) awaySeasonDelta[`seasonStats.${seasonId}.totalLosses`] = FieldValue.increment(1);

              const batch = db.batch();
              batch.update(db.collection("users").doc(applied.homeUid), homeSeasonDelta);
              batch.update(db.collection("users").doc(applied.awayUid), awaySeasonDelta);
              await batch.commit();
            }
          } catch (err) {
            logger.error("Update seasonStats failed", {
              tournamentId, matchId, err,
            });
          }

          // Bağımsız yan işlemler: biri başarısız olursa diğerleri yine de
          // çalışsın (ör. grup istatistiği yazımı patlasa bile rozet türetimi
          // engellenmesin).
          try {
            await updateFriendGroupStats(applied);
          } catch (err) {
            logger.error("updateFriendGroupStats failed", {
              tournamentId, matchId, err,
            });
          }
          // ELO hesapla (bye maçı değilse)
          const isBye = applied.homeUid === 'bye' || applied.awayUid === 'bye';
          if (!isBye && applied.homeUid && applied.awayUid) {
            try {
              await updateElo(
                db,
                applied.homeUid,
                applied.awayUid,
                applied.homeScore,
                applied.awayScore,
              );
            } catch (err) {
              logger.error('ELO update failed', {err});
            }
          }
          for (const uid of [applied.homeUid, applied.awayUid]) {
            try {
              await runAchievements(uid);
            } catch (err) {
              logger.error("runAchievements failed", {
                tournamentId, matchId, uid, err,
              });
            }
          }
        }
      } catch (err) {
        logger.error("applyMatchStats failed", {tournamentId, matchId, err});
      }
    }

    // Skor kesinleşsin ya da kesinleşmesin, her maç yazımında turnuvanın
    // ilerleme/tamamlanma durumunu değerlendir (idempotenttir).
    try {
      await checkTournamentProgression(tournamentId);
    } catch (err) {
      logger.error("checkTournamentProgression failed", {tournamentId, err});
    }
  },
);

// ---------------------------------------------------------------------------
// FCM push bildirimi — yeni notification belgesi yazıldığında
// ---------------------------------------------------------------------------

/**
 * Bir `notifications/{id}` belgesi oluşturulduğunda, hedef kullanıcının FCM
 * token'ına push bildirimi gönderir.
 *
 *   * `userId` alanından hedef kullanıcı bulunur, `users/{userId}.fcmToken` okunur.
 *   * token yoksa/boşsa sessizce çıkılır.
 *   * Hem `notification` (sistem tepsisi) hem `data` (uygulama-içi yönlendirme)
 *     payload'ı gönderilir. `data` yalnızca dolu alanları içerir (type/tournamentId/matchId).
 *   * Token geçersizse (invalid-registration-token / registration-token-not-registered)
 *     `users/{userId}.fcmToken` Firestore'dan silinir.
 */
export const onNotificationCreated = onDocumentCreated(
  {document: "notifications/{notificationId}", region: "europe-west3"},
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data();
    if (!data) return;

    const userId = typeof data.userId === "string" ? data.userId : "";
    if (!userId) return;

    const userRef = db.collection("users").doc(userId);
    const userSnap = await userRef.get();
    if (!userSnap.exists) return;

    const token = userSnap.data()?.fcmToken;
    if (typeof token !== "string" || token.length === 0) return; // sessizce geç

    const title = typeof data.title === "string" ? data.title : "Competra";
    const body = typeof data.message === "string" ? data.message : "";

    // data payload'ı yalnızca dolu alanları taşır (FCM data değerleri string olmalı).
    const dataPayload: Record<string, string> = {};
    if (typeof data.type === "string" && data.type.length > 0) {
      dataPayload.type = data.type;
    }
    if (typeof data.tournamentId === "string" && data.tournamentId.length > 0) {
      dataPayload.tournamentId = data.tournamentId;
    }
    if (typeof data.matchId === "string" && data.matchId.length > 0) {
      dataPayload.matchId = data.matchId;
    }

    try {
      await admin.messaging().send({
        token,
        notification: {title, body},
        data: dataPayload,
      });
    } catch (err) {
      const code = (err as {code?: string})?.code ?? "";
      if (
        code === "messaging/invalid-registration-token" ||
        code === "messaging/registration-token-not-registered"
      ) {
        // Geçersiz token'ı temizle ki bir daha denenmesin.
        await userRef.update({fcmToken: FieldValue.delete()});
        logger.info("Geçersiz FCM token temizlendi", {userId, code});
      } else {
        logger.error("FCM gönderimi başarısız", {userId, code, err});
      }
    }
  },
);

// ---------------------------------------------------------------------------
// Arkadaş aktivite akışı (Activity Feed) fan-out
// ---------------------------------------------------------------------------

async function pushToFriendFeeds(
  db: admin.firestore.Firestore,
  actorUid: string,
  feedItem: Record<string, unknown>
): Promise<void> {
  // Aktörün kabul edilmiş arkadaşlarını bul
  const snap = await db.collection("friendships")
    .where("users", "array-contains", actorUid)
    .where("status", "==", "accepted")
    .get();

  if (snap.empty) return;

  const batch = db.batch();
  for (const doc of snap.docs) {
    const users = doc.data().users as string[];
    const friendUid = users.find((u) => u !== actorUid);
    if (!friendUid) continue;
    const ref = db
      .collection("activity_feed")
      .doc(friendUid)
      .collection("items")
      .doc();
    batch.set(ref, {
      ...feedItem,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
    });
  }
  await batch.commit();
}

// ---------------------------------------------------------------------------
// (a) Maç istatistikleri — katılımcı + kullanıcı + hat-trick rozeti
// ---------------------------------------------------------------------------

interface AppliedMatch {
  homeUid: string;
  awayUid: string;
  homeScore: number;
  awayScore: number;
}

/**
 * Tamamlanan bir maçın istatistik artışlarını TEK transaction'da uygular ve
 * maça `statsApplied: true` damgası vurarak çift sayımı engeller (Cloud
 * Functions en-az-bir-kez teslimat garantisi verir; bu damga idempotentliği
 * sağlar). İlk kez uygulandıysa maç skorlarını döner; zaten uygulanmışsa null.
 */
async function applyMatchStats(
  tournamentId: string,
  matchId: string,
): Promise<AppliedMatch | null> {
  const tRef = db.collection("tournaments").doc(tournamentId);
  const matchRef = tRef.collection("matches").doc(matchId);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(matchRef);
    if (!snap.exists) return null;
    const data = snap.data()!;

    // Skor değer doğrulaması — negatif veya aşırı büyük skor istatistik bozmasın
    const homeGoals = (data.homeScore as number | null | undefined) ?? 0;
    const awayGoals = (data.awayScore as number | null | undefined) ?? 0;
    if (homeGoals < 0 || awayGoals < 0 || homeGoals > 99 || awayGoals > 99) {
      logger.warn("Invalid score values", {homeGoals, awayGoals, matchId});
      return null;
    }

    if (data.statsApplied === true) return null;

    const m = parseMatch(matchId, data);
    if (m.isBye || !isFinal(m) || !m.homeUid || !m.awayUid) return null;
    if (m.homeScore === null || m.awayScore === null) return null;

    const hs = m.homeScore;
    const as = m.awayScore;
    const homeWin = hs > as;
    const awayWin = as > hs;
    const draw = hs === as;

    // a) tournaments/{id}/participants/{uid}
    const participants = tRef.collection("participants");
    tx.set(participants.doc(m.homeUid), participantDelta(hs, as, homeWin, draw, awayWin), {merge: true});
    tx.set(participants.doc(m.awayUid), participantDelta(as, hs, awayWin, draw, homeWin), {merge: true});

    // b + c) users/{uid} — genel istatistik + hat-trick rozeti
    const users = db.collection("users");
    tx.set(users.doc(m.homeUid), userDelta(hs, as, homeWin, awayWin), {merge: true});
    tx.set(users.doc(m.awayUid), userDelta(as, hs, awayWin, homeWin), {merge: true});

    tx.update(matchRef, {statsApplied: true});
    return {homeUid: m.homeUid, awayUid: m.awayUid, homeScore: hs, awayScore: as};
  });
}

/** Turnuva katılımcısının (alt koleksiyon) istatistik artışları. */
function participantDelta(
  goalsScored: number,
  goalsConceded: number,
  win: boolean,
  draw: boolean,
  loss: boolean,
): Record<string, unknown> {
  const map: Record<string, unknown> = {
    matchesPlayed: FieldValue.increment(1),
    goalsScored: FieldValue.increment(goalsScored),
    goalsConceded: FieldValue.increment(goalsConceded),
    goalDifference: FieldValue.increment(goalsScored - goalsConceded),
  };
  if (win) {
    map.wins = FieldValue.increment(1);
    map.points = FieldValue.increment(3);
  } else if (draw) {
    map.draws = FieldValue.increment(1);
    map.points = FieldValue.increment(1);
  }
  if (loss) map.losses = FieldValue.increment(1);
  return map;
}

/** Kullanıcı genel istatistik artışları; 3+ gol → hat_trick_hero rozeti. */
function userDelta(
  goalsScored: number,
  goalsConceded: number,
  win: boolean,
  loss: boolean,
): Record<string, unknown> {
  const map: Record<string, unknown> = {
    totalMatches: FieldValue.increment(1),
    totalGoalsScored: FieldValue.increment(goalsScored),
    totalGoalsConceded: FieldValue.increment(goalsConceded),
  };
  if (win) map.totalWins = FieldValue.increment(1);
  if (loss) map.totalLosses = FieldValue.increment(1);
  if (goalsScored >= 3) map.badges = FieldValue.arrayUnion("hat_trick_hero");
  return map;
}

// ---------------------------------------------------------------------------
// Arkadaş grubu istatistikleri (ortak gruplar)
// ---------------------------------------------------------------------------

/** İki oyuncunun ortak üye olduğu arkadaş gruplarının grup-içi istatistikleri. */
async function updateFriendGroupStats(m: AppliedMatch): Promise<void> {
  const [homeGroups, awayGroups] = await Promise.all([
    groupIdsFor(m.homeUid),
    groupIdsFor(m.awayUid),
  ]);
  const shared = [...homeGroups].filter((id) => awayGroups.has(id));
  if (shared.length === 0) return;

  const homeWin = m.homeScore > m.awayScore;
  const awayWin = m.awayScore > m.homeScore;
  const draw = m.homeScore === m.awayScore;

  const batch = db.batch();
  const groups = db.collection("friendGroups");
  for (const groupId of shared) {
    const members = groups.doc(groupId).collection("members");
    batch.set(members.doc(m.homeUid), memberDelta(m.homeScore, m.awayScore, homeWin, draw, awayWin), {merge: true});
    batch.set(members.doc(m.awayUid), memberDelta(m.awayScore, m.homeScore, awayWin, draw, homeWin), {merge: true});
  }
  await batch.commit();
}

/** Bir kullanıcının üye olduğu tüm friendGroups id'leri (collectionGroup). */
async function groupIdsFor(uid: string): Promise<Set<string>> {
  const snap = await db.collectionGroup("members").where("uid", "==", uid).get();
  const ids = new Set<string>();
  for (const doc of snap.docs) {
    const groupRef = doc.ref.parent.parent;
    if (groupRef) ids.add(groupRef.id);
  }
  return ids;
}

/** Tek bir maçtan bir grup üyesinin istatistiklerine eklenecek artışlar. */
function memberDelta(
  goalsScored: number,
  goalsConceded: number,
  win: boolean,
  draw: boolean,
  loss: boolean,
): Record<string, unknown> {
  const map: Record<string, unknown> = {
    totalMatches: FieldValue.increment(1),
    totalGoalsScored: FieldValue.increment(goalsScored),
    totalGoalsConceded: FieldValue.increment(goalsConceded),
  };
  if (win) {
    map.totalWins = FieldValue.increment(1);
    map.totalPoints = FieldValue.increment(3);
  } else if (draw) {
    map.totalPoints = FieldValue.increment(1);
  }
  if (loss) map.totalLosses = FieldValue.increment(1);
  return map;
}

// ---------------------------------------------------------------------------
// Rozet / unvan türetimi
// ---------------------------------------------------------------------------

/** users/{uid} istatistiklerinden rozet/unvan güncellemesini hesaplar ve yazar. */
async function runAchievements(uid: string): Promise<void> {
  const ref = db.collection("users").doc(uid);
  const snap = await ref.get();
  if (!snap.exists) return;
  const userData = snap.data()!;
  const oldBadges: string[] = Array.isArray(userData.badges) ? userData.badges.map((b: unknown) => `${b}`) : [];
  const oldStats = parseUserStats(userData);
  const update = deriveAchievementUpdate(oldStats);
  if (Object.keys(update).length > 0) {
    await ref.set(update, {merge: true});

    if (update.badges && Array.isArray(update.badges)) {
      const newlyEarnedBadges = (update.badges as string[]).filter((b) => !oldBadges.includes(b));
      if (newlyEarnedBadges.length > 0) {
        const userName = userData.username ?? "Bir oyuncu";
        try {
          for (const newBadge of newlyEarnedBadges) {
            await pushToFriendFeeds(db, uid, {
              type: "badge_earned",
              actorUid: uid,
              actorName: userName,
              message: `${userName} yeni bir rozet kazandı! 🎖️`,
              badgeId: newBadge,
            });
          }
        } catch (err) {
          logger.error("Feed fan-out failed (badge_earned)", {err});
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// (b) + (c) Turnuva ilerleme / tamamlanma
// ---------------------------------------------------------------------------

/**
 * Turnuvanın formatına göre ilerleme/tamamlanma durumunu değerlendirir.
 *
 * Okuma optimizasyonu: maç koleksiyonunun TAMAMINI her yazımda çekmek yerine,
 * önce yalnızca mevcut `roundNumber` + `phase`'e ait maçlar çekilir. Bu dar
 * sorgu turun henüz bitmediğini gösteriyorsa (tamamlanmamış maç varsa) tam
 * koleksiyon okuma hiç yapılmadan erken çıkılır — büyük turnuvalarda her maç
 * yazımında tüm maçların okunmasının önüne geçer. Tur/faz bilgisi yoksa (ör.
 * eski belgeler) doğrudan tam okumaya düşülür.
 */
async function checkTournamentProgression(tournamentId: string): Promise<void> {
  const tRef = db.collection("tournaments").doc(tournamentId);
  const tSnap = await tRef.get();
  if (!tSnap.exists) return;
  const data = tSnap.data()!;
  if (data.status === "completed") return;

  const tournament = parseTournament(tournamentId, data);
  const currentRound =
    typeof data.currentRound === "number" ? Math.trunc(data.currentRound) : null;
  const currentPhase =
    typeof data.currentPhase === "string" && data.currentPhase.length > 0 ?
      data.currentPhase :
      null;

  if (currentRound !== null && currentPhase !== null) {
    const roundSnapshot = await tRef
      .collection("matches")
      .where("roundNumber", "==", currentRound)
      .where("phase", "==", currentPhase)
      .get();
    if (roundSnapshot.empty) return;
    const allDone = roundSnapshot.docs.every((d) => {
      const m = parseMatch(d.id, d.data());
      return m.isBye || isFinal(m);
    });
    if (!allDone) return;
  }

  // Sadece (yukarıdaki dar sorguya göre) tur/faz bittiyse ya da tur bilgisi
  // yoksa tam koleksiyonu oku — tur ilerletme veya şampiyon belirlemek için
  // tüm maçların görülmesi gerekir.
  const matchesSnap = await tRef.collection("matches").get();
  if (matchesSnap.empty) return;
  const matches = matchesSnap.docs.map((d) => parseMatch(d.id, d.data()));

  switch (tournament.format) {
    case "knockout":
      await advanceKnockout(tRef, tournament, matches, currentRound);
      break;
    case "groupKnockout":
      await advanceGroupKnockout(tRef, tournament, matches, currentRound);
      break;
    case "championsLeague":
      await advanceChampionsLeague(tRef, tournament, matches, currentRound);
      break;
    case "league":
    default: {
      const allCompleted = matches.every((m) => m.isBye || isPlayed(m));
      if (!allCompleted) return;
      const standings = computeStandings(tournament.participants, matches, tournament.tiebreakerMode);
      const winnerId = standings.length > 0 ? standings[0].uid : null;
      await finalizeTournament(tRef, tournament, winnerId);
    }
  }
}

/** Grup + Eleme: eleme fazı varsa tur ilerlet; yoksa grup bitince elemeyi kur. */
async function advanceGroupKnockout(
  tRef: DocRef,
  tournament: Tournament,
  matches: Match[],
  currentRound: number | null,
): Promise<void> {
  if (matches.some((m) => m.phase === "knockout")) {
    await advanceKnockout(tRef, tournament, matches, currentRound);
    return;
  }

  const groupMatches = matches.filter((m) => m.phase === "group");
  if (groupMatches.length === 0) return;
  if (!groupMatches.every((m) => m.isBye || isFinal(m))) return;

  const byGroup = new Map<string, Match[]>();
  for (const m of groupMatches) {
    const arr = byGroup.get(m.group) ?? [];
    arr.push(m);
    byGroup.set(m.group, arr);
  }

  const labels = [...byGroup.keys()].sort();
  const groupWinners: string[][] = [];
  const uidToName = new Map<string, string>();
  for (const label of labels) {
    const gm = byGroup.get(label)!;
    const participants = participantsFromMatches(gm);
    const standings = computeStandings(participants, gm, tournament.tiebreakerMode);
    for (const s of standings) uidToName.set(s.uid, s.name);
    const top = standings.slice(0, 2).map((s) => s.uid);
    if (top.length > 0) groupWinners.push(top);
  }

  const knockout = generateKnockoutFromGroups(groupWinners, uidToName, 1);
  if (knockout.length === 0) return;
  await writeKnockoutPhase(tRef, knockout);
}

/** Şampiyonlar Ligi: eleme fazı varsa tur ilerlet; yoksa lig bitince elemeyi kur. */
async function advanceChampionsLeague(
  tRef: DocRef,
  tournament: Tournament,
  matches: Match[],
  currentRound: number | null,
): Promise<void> {
  if (matches.some((m) => m.phase === "knockout")) {
    await advanceKnockout(tRef, tournament, matches, currentRound);
    return;
  }

  const leagueMatches = matches.filter((m) => m.phase === "league");
  if (leagueMatches.length === 0) return;
  if (!leagueMatches.every((m) => m.isBye || isFinal(m))) return;

  const standings = computeStandings(tournament.participants, leagueMatches, tournament.tiebreakerMode);
  const n = tournament.participants.length;
  let qualifierCount = clamp(Math.floor(n / 2), 2, 8);
  qualifierCount = Math.min(qualifierCount, standings.length);
  if (qualifierCount < 2) return;

  const seeds = standings.slice(0, qualifierCount);
  const uidToName = new Map<string, string>(seeds.map((s) => [s.uid, s.name]));
  const knockout = generateKnockoutFromSeeds(seeds.map((s) => s.uid), uidToName, 1);
  if (knockout.length === 0) return;
  await writeKnockoutPhase(tRef, knockout);
}

/**
 * Eleme formatında mevcut turu değerlendirir: tur bittiyse ya şampiyon ilan
 * eder ya da sonraki turu üretir. Transaction + currentRound koruması ile
 * eşzamanlı çağrılarda tur yalnızca BİR kez ilerletilir.
 */
async function advanceKnockout(
  tRef: DocRef,
  tournament: Tournament,
  matches: Match[],
  explicitCurrentRound: number | null,
): Promise<void> {
  const koMatches = matches.filter((m) => m.phase === "knockout");
  if (koMatches.length === 0) return;

  const currentRound =
    explicitCurrentRound ?? koMatches.reduce((mx, m) => Math.max(mx, m.roundNumber), 1);

  const roundMatches = koMatches
    .filter((m) => m.roundNumber === currentRound)
    .sort((a, b) => a.order - b.order);
  if (roundMatches.length === 0) return;

  const allDone = roundMatches.every((m) => m.isBye || isFinal(m));
  if (!allDone) return;

  // Maçları eşleşmelere (tie) göre grupla: bye tek maç, gerçek eşleşmeler tek
  // veya çift ayaklı (Şampiyonlar Ligi) olabilir. Çift maçlıda iki ayağın
  // sıralı uid çifti aynı anahtara düşer.
  const ties = new Map<string, Match[]>();
  const tieOrder = new Map<string, number>();
  for (const m of roundMatches) {
    const key = m.isBye ?
      `bye:${m.homeUid}` :
      [m.homeUid, m.awayUid].sort().join("|");
    const arr = ties.get(key) ?? [];
    arr.push(m);
    ties.set(key, arr);
    if (!tieOrder.has(key)) tieOrder.set(key, m.order);
  }

  // Çift maçlı tur mu? (sonraki turu da aynı biçimde üretmek için)
  const twoLegged = roundMatches.some((m) => m.leg === 2);

  const sortedKeys = [...ties.keys()].sort(
    (a, b) => (tieOrder.get(a) ?? 0) - (tieOrder.get(b) ?? 0),
  );

  const winnerUids: string[] = [];
  const uidToName = new Map<string, string>();
  for (const key of sortedKeys) {
    const legs = ties.get(key)!;
    for (const m of legs) {
      uidToName.set(m.homeUid, m.homeName);
      if (!m.isBye) uidToName.set(m.awayUid, m.awayName);
    }
    winnerUids.push(resolveTieWinner(legs));
  }

  if (winnerUids.length <= 1) {
    await finalizeTournament(tRef, tournament, winnerUids.length > 0 ? winnerUids[0] : null);
    return;
  }

  const nextRound = currentRound + 1;
  const nextMatches = generateNextKnockoutRound(winnerUids, uidToName, nextRound, twoLegged);

  const matchesCol = tRef.collection("matches");
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(tRef);
    const data = snap.data();
    if (!data) return;
    if (data.status === "completed") return;
    const liveRound = typeof data.currentRound === "number" ? Math.trunc(data.currentRound) : currentRound;
    if (liveRound !== currentRound) return; // başka biri zaten ilerletti

    for (const m of nextMatches) {
      tx.set(matchesCol.doc(), {...m, createdAt: FieldValue.serverTimestamp()});
    }
    tx.update(tRef, {currentRound: nextRound});
  });
}

/**
 * Bir eşleşmenin (tek veya çift maçlı) kazananını döndürür.
 *
 *   * Bye: ev sahibi otomatik geçer.
 *   * Tek maç: skoru fazla olan; beraberlikte ev sahibi.
 *   * Çift maç (iki ayak): toplam gol fazla olan; eşitlikte deplasman golü
 *     fazla olan; iki eşitlikte 1. maçın ev sahibi (üst sıralı) geçer.
 */
function resolveTieWinner(legs: Match[]): string {
  // Bye.
  if (legs.length === 1 && legs[0].isBye) return legs[0].homeUid;

  // Tek maç (mevcut davranış korunur: beraberlik → ev sahibi).
  if (legs.length === 1) {
    const m = legs[0];
    return (m.awayScore ?? 0) > (m.homeScore ?? 0) ? m.awayUid : m.homeUid;
  }

  // Çift maç. 1. ayağı referans al (ev sahibi = üst sıralı oyuncu).
  const leg1 = legs.find((m) => m.leg === 1) ?? legs[0];
  const pA = leg1.homeUid; // 1. maçın ev sahibi
  const pB = leg1.awayUid;

  let aggA = 0; let aggB = 0; let awayA = 0; let awayB = 0;
  for (const m of legs) {
    const hs = m.homeScore ?? 0;
    const as = m.awayScore ?? 0;
    if (m.homeUid === pA) {
      aggA += hs; aggB += as; awayB += as; // pB deplasmanda gol attı
    } else if (m.homeUid === pB) {
      aggB += hs; aggA += as; awayA += as; // pA deplasmanda gol attı
    }
  }

  if (aggA !== aggB) return aggA > aggB ? pA : pB; // toplam gol
  if (awayA !== awayB) return awayA > awayB ? pA : pB; // deplasman golü
  return pA; // iki eşitlik → 1. maçın ev sahibi (basit kural)
}

/**
 * Üretilen ilk eleme turu maçlarını yazar ve turnuvayı eleme fazına geçirir.
 * currentPhase koruması ile eşzamanlı çağrılarda eleme yalnızca BİR kez kurulur.
 */
async function writeKnockoutPhase(
  tRef: DocRef,
  knockoutMatches: Record<string, unknown>[],
): Promise<void> {
  const matchesCol = tRef.collection("matches");
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(tRef);
    const data = snap.data();
    if (!data) return;
    if (data.currentPhase === "knockout") return;

    for (const m of knockoutMatches) {
      tx.set(matchesCol.doc(), {...m, createdAt: FieldValue.serverTimestamp()});
    }
    tx.update(tRef, {currentPhase: "knockout", currentRound: 1});
  });
}

/**
 * Turnuvayı sonlandırır: status 'completed', şampiyon işareti, katılımcı/şampiyon
 * genel istatistikleri ve herkese bildirim — tek transaction (status koruması ile
 * idempotent). Ardından her katılımcı için rozet/unvan türetimini çalıştırır.
 */
async function finalizeTournament(
  tRef: DocRef,
  tournament: Tournament,
  winnerId: string | null,
): Promise<void> {
  const users = db.collection("users");
  const notifications = db.collection("notifications");
  const predsSnap = await tRef.collection("predictions").get();

  const committed = await db.runTransaction<boolean>(async (tx) => {
    const snap = await tx.get(tRef);
    const data = snap.data();
    if (!data) return false;
    if (data.status === "completed") return false;

    const update: Record<string, unknown> = {
      status: "completed",
      completedAt: FieldValue.serverTimestamp(),
    };
    if (winnerId) update.winnerId = winnerId;
    tx.update(tRef, update);

    for (const p of tournament.participants) {
      tx.set(users.doc(p.uid), {tournamentsPlayed: FieldValue.increment(1)}, {merge: true});
    }
    if (winnerId) {
      tx.set(
        users.doc(winnerId),
        {tournamentsWon: FieldValue.increment(1), badges: FieldValue.arrayUnion("champion")},
        {merge: true},
      );

      // Kazanan tahminlerini kontrol et
      for (const pred of predsSnap.docs) {
        const predData = pred.data();
        if (predData.winnerUid === winnerId && predData.predictorUid) {
          tx.set(
            users.doc(predData.predictorUid),
            {badges: FieldValue.arrayUnion("prophet")},
            {merge: true},
          );
          tx.set(notifications.doc(), {
            userId: predData.predictorUid,
            type: "generic",
            title: "Doğru Tahmin! 🔮",
            message: `${tournament.name} turnuvasının kazananını doğru tahmin ettin! 🔮`,
            tournamentId: tournament.id,
            read: false,
            createdAt: FieldValue.serverTimestamp(),
          });
        }
      }
    }

    for (const p of tournament.participants) {
      const isWinner = p.uid === winnerId;
      tx.set(notifications.doc(), {
        userId: p.uid,
        type: "tournamentComplete",
        title: isWinner ? "Şampiyon Oldun! 🏆" : "Turnuva Tamamlandı",
        message: isWinner ?
          `Tebrikler! ${tournament.name} turnuvasını kazandın! 🏆` :
          `${tournament.name} turnuvası tamamlandı! Sonuçları görmek için tıkla.`,
        tournamentId: tournament.id,
        read: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
    return true;
  });

  if (!committed) return;

  if (winnerId) {
    try {
      // Şampiyonun adını users koleksiyonundan çek
      const winnerDoc = await db.collection("users").doc(winnerId).get();
      const winnerName = winnerDoc.data()?.username ?? "Bir oyuncu";
      await pushToFriendFeeds(db, winnerId, {
        type: "tournament_won",
        actorUid: winnerId,
        actorName: winnerName,
        message: `${winnerName} turnuvayı kazandı! 🏆`,
        tournamentId: tournament.id,
      });
    } catch (err) {
      logger.error("Feed fan-out failed (tournament_won)", {err});
    }

    // Doğru tahmin edenler için feed fan-out yap
    try {
      for (const pred of predsSnap.docs) {
        const predData = pred.data();
        if (predData.winnerUid === winnerId && predData.predictorUid) {
          const predictorDoc = await db.collection("users").doc(predData.predictorUid).get();
          const predictorName = predictorDoc.data()?.username ?? "Bir oyuncu";
          await pushToFriendFeeds(db, predData.predictorUid, {
            type: "badge_earned",
            actorUid: predData.predictorUid,
            actorName: predictorName,
            message: `${predictorName} yeni bir rozet kazandı! 🔮`,
            badgeId: "prophet",
          });
        }
      }
    } catch (err) {
      logger.error("Feed fan-out failed (prophet badge)", {err});
    }
  }

  for (const p of tournament.participants) {
    // Bir kullanıcının rozet türetimi başarısız olsa bile diğer
    // katılımcıların işlenmesi engellenmesin.
    try {
      await runAchievements(p.uid);
    } catch (err) {
      logger.error("runAchievements failed (tournament complete)", {
        uid: p.uid, err,
      });
    }
  }
}

/** Bir maç listesindeki tüm oyuncuları (bye hariç) Participant olarak çıkarır. */
function participantsFromMatches(matches: Match[]): Participant[] {
  const map = new Map<string, string>();
  for (const m of matches) {
    map.set(m.homeUid, m.homeName);
    if (!m.isBye) map.set(m.awayUid, m.awayName);
  }
  return [...map.entries()].map(([uid, username]) => ({uid, username}));
}

function clamp(v: number, lo: number, hi: number): number {
  return Math.max(lo, Math.min(hi, v));
}

// Her ayın 1'inde çalışır (00:00 Türkiye saati = UTC+3)
export const startNewSeason = onSchedule(
  {
    schedule: "0 0 1 * *", // Europe/Istanbul gece yarısı (timeZone aşağıda)
    region: "europe-west3",
    timeZone: "Europe/Istanbul",
  },
  async () => {
    const db = admin.firestore();
    const now = new Date();

    // Aktif sezonu kapat
    const activeSnap = await db.collection("seasons")
      .where("isActive", "==", true).get();
    const batch = db.batch();
    for (const doc of activeSnap.docs) {
      batch.update(doc.ref, { isActive: false });
    }

    // Yeni sezon oluştur
    const monthNames = [
      "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran",
      "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"
    ];
    const monthName = monthNames[now.getMonth()];
    const year = now.getFullYear();
    const newSeasonRef = db.collection("seasons").doc();
    batch.set(newSeasonRef, {
      name: `${monthName} ${year} Sezonu`,
      startDate: admin.firestore.Timestamp.now(),
      endDate: admin.firestore.Timestamp.fromDate(
        new Date(year, now.getMonth() + 1, 1)
      ),
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await batch.commit();
    logger.info(`New season started: ${monthName} ${year}`);
  }
);

async function addBadge(
  db: admin.firestore.Firestore,
  uid: string,
  badgeId: string,
): Promise<void> {
  const userRef = db.collection("users").doc(uid);
  const updated = await db.runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    if (!snap.exists) return false;
    const data = snap.data()!;
    const badges = Array.isArray(data.badges) ? data.badges : [];
    if (!badges.includes(badgeId)) {
      tx.update(userRef, {
        badges: admin.firestore.FieldValue.arrayUnion(badgeId),
      });
      return true;
    }
    return false;
  });

  if (updated) {
    try {
      const userDoc = await userRef.get();
      const userName = userDoc.data()?.username ?? "Bir oyuncu";
      await pushToFriendFeeds(db, uid, {
        type: "badge_earned",
        actorUid: uid,
        actorName: userName,
        message: `${userName} yeni bir rozet kazandı! 🎖️`,
        badgeId: badgeId,
      });
    } catch (err) {
      logger.error("addBadge feed push failed", {uid, badgeId, err});
    }
  }
}

export const onTournamentUpdated = onDocumentWritten(
  {
    document: "tournaments/{tournamentId}",
    region: "europe-west3",
  },
  async (event) => {
    const after = event.data?.after;
    if (!after || !after.exists) return;

    const before = event.data?.before;
    const afterData = after.data();
    if (!afterData) return;
    const beforeData = before?.exists ? before.data() : null;

    const newMvpUid = afterData.mvpUid as string | undefined;
    const oldMvpUid = beforeData?.mvpUid as string | undefined;

    if (newMvpUid && newMvpUid !== oldMvpUid) {
      try {
        await addBadge(db, newMvpUid, "mvp");

        const tournamentName = afterData.name ?? "Turnuva";
        const notifRef = db.collection("notifications").doc();
        await notifRef.set({
          userId: newMvpUid,
          type: "generic",
          title: "Turnuva MVP'si Seçildin! ⭐️",
          message: `${tournamentName} turnuvasında En Değerli Oyuncu (MVP) seçildin! ⭐️`,
          tournamentId: event.params.tournamentId,
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (err) {
        logger.error("Error setting MVP badge / notification", {
          tournamentId: event.params.tournamentId,
          mvpUid: newMvpUid,
          err,
        });
      }
    }
  }
);
