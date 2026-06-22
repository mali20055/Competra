/**
 * Rozet ve unvan türetimi — lib/services/achievement_service.dart ve
 * lib/models/title_definitions.dart portu. Kullanıcının toplam istatistiklerine
 * bakarak kazanılan rozetleri ve en prestijli unvanı hesaplar.
 */

export interface UserStats {
  totalMatches: number;
  totalWins: number;
  totalLosses: number;
  totalGoalsScored: number;
  totalGoalsConceded: number;
  tournamentsPlayed: number;
  tournamentsWon: number;
  badges: string[];
  activeTitle: string;
}

/** Ham `users/{uid}` verisinden istatistik görünümü çıkarır. */
export function parseUserStats(data: FirebaseFirestore.DocumentData): UserStats {
  const int = (k: string): number => (typeof data[k] === "number" ? Math.trunc(data[k]) : 0);
  const rawBadges = Array.isArray(data.badges) ? data.badges : [];
  return {
    totalMatches: int("totalMatches"),
    totalWins: int("totalWins"),
    totalLosses: int("totalLosses"),
    totalGoalsScored: int("totalGoalsScored"),
    totalGoalsConceded: int("totalGoalsConceded"),
    tournamentsPlayed: int("tournamentsPlayed"),
    tournamentsWon: int("tournamentsWon"),
    badges: rawBadges.map((b) => `${b}`),
    activeTitle: typeof data.activeTitle === "string" ? data.activeTitle : "",
  };
}

/** Yalnızca toplam istatistiklerden türetilebilen rozet koşulları. */
const badgeConditions: Record<string, (p: UserStats) => boolean> = {
  first_tournament: (p) => p.tournamentsPlayed >= 1,
  champion: (p) => p.tournamentsWon >= 1,
  veteran: (p) => p.tournamentsPlayed >= 10,
  legend: (p) => p.tournamentsWon >= 5,
  goal_machine: (p) => p.totalGoalsScored >= 50,
};

interface TitleDefinition {
  label: string;
  priority: number;
  condition: (p: UserStats) => boolean;
}

/** Tüm unvanların kataloğu (artan prestij = artan priority). */
const titleDefinitions: TitleDefinition[] = [
  {label: "Çaylak", priority: 0, condition: (p) => p.tournamentsPlayed === 0},
  {label: "Amatör", priority: 1, condition: (p) => p.tournamentsPlayed >= 1},
  {label: "Yarı Pro", priority: 2, condition: (p) => p.tournamentsPlayed >= 5},
  {label: "Pro", priority: 3, condition: (p) => p.tournamentsWon >= 1},
  {label: "Gol Kralı", priority: 4, condition: (p) => p.totalGoalsScored >= 50},
  {label: "Demir Duvar", priority: 5, condition: (p) => p.totalGoalsConceded <= 10 && p.totalMatches >= 10},
  {label: "Kral", priority: 6, condition: (p) => p.tournamentsWon >= 3},
  {
    label: "Geri Dönüş Kralı",
    priority: 7,
    condition: (p) => p.totalWins >= 10 && p.totalMatches > 0 && p.totalWins / p.totalMatches >= 0.7,
  },
  {label: "Efsane", priority: 8, condition: (p) => p.tournamentsWon >= 5},
];

/**
 * Verilen istatistiklerden, yazılması gereken `badges`/`activeTitle` güncellemesini
 * üretir. Değişiklik yoksa boş nesne döner (yazım atlanır).
 */
export function deriveAchievementUpdate(stats: UserStats): Record<string, unknown> {
  const earned = new Set(stats.badges);
  let badgesChanged = false;
  for (const [id, condition] of Object.entries(badgeConditions)) {
    if (!earned.has(id) && condition(stats)) {
      earned.add(id);
      badgesChanged = true;
    }
  }

  let bestTitle: string | null = null;
  let bestPriority = -1;
  for (const t of titleDefinitions) {
    if (t.condition(stats) && t.priority > bestPriority) {
      bestPriority = t.priority;
      bestTitle = t.label;
    }
  }

  const update: Record<string, unknown> = {};
  if (badgesChanged) update.badges = [...earned];
  if (bestTitle !== null && bestTitle !== stats.activeTitle) update.activeTitle = bestTitle;
  return update;
}
