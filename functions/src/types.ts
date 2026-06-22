/**
 * Firestore belge tiplerinin sunucu (Cloud Functions) tarafı karşılıkları.
 *
 * Flutter modelleriyle (lib/models/tournament.dart, user_profile.dart) AYNI
 * alan adlarını ve normalleştirme kurallarını kullanır; böylece istemci ve
 * sunucu aynı veriyi aynı biçimde yorumlar.
 */

/** Bye (boş rakip) için sahte oyuncu kimliği — fixture_generator.dart ile aynı. */
export const kByeUid = "__bye__";

/** Puan eşitliğinde uygulanacak averaj / sıralama modu. */
export type TiebreakerMode = "fifa" | "uefa" | "hybrid";

/** Firestore string'inden tiebreaker modunu çözer (varsayılan: uefa). */
export function tiebreakerFromString(value: unknown): TiebreakerMode {
  switch (value) {
    case "fifa":
      return "fifa";
    case "hybrid":
      return "hybrid";
    case "uefa":
    default:
      return "uefa";
  }
}

/** Turnuva katılımcısı. */
export interface Participant {
  uid: string;
  username: string;
}

/** `tournaments/{id}` belgesinin sunucu tarafı görünümü. */
export interface Tournament {
  id: string;
  name: string;
  format: string;
  ownerId: string;
  participants: Participant[];
  status: string;
  tiebreakerMode: TiebreakerMode;
}

/** `tournaments/{id}/matches/{matchId}` belgesinin normalleştirilmiş görünümü. */
export interface Match {
  id: string;
  round: string;
  roundNumber: number;
  phase: string;
  group: string;
  order: number;
  homeUid: string;
  homeName: string;
  awayUid: string;
  awayName: string;
  homeScore: number | null;
  awayScore: number | null;
  isBye: boolean;
  status: string;
  /** Çift maçlı elemede ayak numarası (1 veya 2); tek maçlılarda 1. */
  leg: number;
}

function intOrNull(v: unknown): number | null {
  if (typeof v === "number") return Math.trunc(v);
  return null;
}

function str(v: unknown, fallback = ""): string {
  return typeof v === "string" ? v : fallback;
}

/** Ham match verisini normalize eder (TournamentMatch.fromDoc karşılığı). */
export function parseMatch(id: string, data: FirebaseFirestore.DocumentData): Match {
  const rawPhase = str(data.phase);
  const phase = rawPhase.length > 0 ? rawPhase : str(data.stage);
  return {
    id,
    round: str(data.round),
    roundNumber: typeof data.roundNumber === "number" ? Math.trunc(data.roundNumber) : 1,
    phase,
    group: str(data.group),
    order: typeof data.order === "number" ? Math.trunc(data.order) : 0,
    homeUid: str(data.homeUid),
    homeName: str(data.homeName, "Oyuncu"),
    awayUid: str(data.awayUid),
    awayName: str(data.awayName, "Oyuncu"),
    homeScore: intOrNull(data.homeScore),
    awayScore: intOrNull(data.awayScore),
    isBye: data.isBye === true,
    status: str(data.status),
    leg: typeof data.leg === "number" ? Math.trunc(data.leg) : 1,
  };
}

/** Her iki skor da girilmişse maç oynanmış sayılır. */
export function isPlayed(m: Match): boolean {
  return m.homeScore !== null && m.awayScore !== null;
}

/** Maç kesinleşti mi? ('completed' ya da eski belgede skor girilmiş). */
export function isFinal(m: Match): boolean {
  return m.status === "completed" || (m.status.length === 0 && isPlayed(m));
}

/** Ham `tournaments/{id}` verisinden Tournament görünümü çıkarır. */
export function parseTournament(id: string, data: FirebaseFirestore.DocumentData): Tournament {
  const rawParticipants = Array.isArray(data.participants) ? data.participants : [];
  return {
    id,
    name: str(data.name, "Turnuva"),
    format: str(data.format),
    ownerId: str(data.ownerId),
    participants: rawParticipants.map((p: any) => ({
      uid: str(p?.uid),
      username: str(p?.username, "Oyuncu"),
    })),
    status: str(data.status, "active"),
    tiebreakerMode: tiebreakerFromString(data.tiebreakerMode),
  };
}
