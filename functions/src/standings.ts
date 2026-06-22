/**
 * Puan tablosu hesabı — lib/models/tournament.dart içindeki computeStandings ve
 * tiebreaker mantığının birebir TypeScript portu. İstemci ile aynı şampiyonu
 * üretmesi için kriter sırası ve mini-tablo (head-to-head) davranışı korunmuştur.
 */

import {Match, Participant, TiebreakerMode, isPlayed} from "./types";

export interface StandingRow {
  uid: string;
  name: string;
  played: number;
  won: number;
  drawn: number;
  lost: number;
  goalsFor: number;
  goalsAgainst: number;
}

function goalDiff(r: StandingRow): number {
  return r.goalsFor - r.goalsAgainst;
}

function points(r: StandingRow): number {
  return r.won * 3 + r.drawn;
}

type TbKey =
  | "overallGoalDiff"
  | "overallGoalsFor"
  | "headToHeadPoints"
  | "headToHeadGoalDiff"
  | "headToHeadGoalsFor";

/** Her moda göre, puan eşitliğinde uygulanacak kriter sırası. */
function criteriaFor(mode: TiebreakerMode): TbKey[] {
  switch (mode) {
    case "fifa":
      return ["overallGoalDiff", "overallGoalsFor", "headToHeadGoalDiff"];
    case "uefa":
      return [
        "headToHeadPoints",
        "headToHeadGoalDiff",
        "headToHeadGoalsFor",
        "overallGoalDiff",
        "overallGoalsFor",
      ];
    case "hybrid":
      return [
        "overallGoalDiff",
        "overallGoalsFor",
        "headToHeadGoalDiff",
        "headToHeadGoalsFor",
      ];
  }
}

interface H2H {
  points: number;
  goalDiff: number;
  goalsFor: number;
}

/** Bir oyuncu grubunun yalnızca kendi aralarındaki maçlardan ikili istatistiği. */
function headToHead(group: StandingRow[], matches: Match[]): Map<string, H2H> {
  const ids = new Set(group.map((r) => r.uid));
  const pts = new Map<string, number>();
  const gd = new Map<string, number>();
  const gf = new Map<string, number>();
  for (const id of ids) {
    pts.set(id, 0);
    gd.set(id, 0);
    gf.set(id, 0);
  }

  for (const m of matches) {
    if (!ids.has(m.homeUid) || !ids.has(m.awayUid)) continue;
    const hs = m.homeScore as number;
    const as = m.awayScore as number;
    gf.set(m.homeUid, (gf.get(m.homeUid) ?? 0) + hs);
    gf.set(m.awayUid, (gf.get(m.awayUid) ?? 0) + as);
    gd.set(m.homeUid, (gd.get(m.homeUid) ?? 0) + (hs - as));
    gd.set(m.awayUid, (gd.get(m.awayUid) ?? 0) + (as - hs));
    if (hs > as) {
      pts.set(m.homeUid, (pts.get(m.homeUid) ?? 0) + 3);
    } else if (hs < as) {
      pts.set(m.awayUid, (pts.get(m.awayUid) ?? 0) + 3);
    } else {
      pts.set(m.homeUid, (pts.get(m.homeUid) ?? 0) + 1);
      pts.set(m.awayUid, (pts.get(m.awayUid) ?? 0) + 1);
    }
  }

  const out = new Map<string, H2H>();
  for (const id of ids) {
    out.set(id, {
      points: pts.get(id) ?? 0,
      goalDiff: gd.get(id) ?? 0,
      goalsFor: gf.get(id) ?? 0,
    });
  }
  return out;
}

/** Eşit puanlı bir grubu kriter sırasını izleyerek özyinelemeli çözer. */
function rankTiedGroup(
  group: StandingRow[],
  matches: Match[],
  criteria: TbKey[],
  criterionIndex: number,
  regIndex: Map<string, number>,
): StandingRow[] {
  if (group.length <= 1) return group;

  if (criterionIndex >= criteria.length) {
    return [...group].sort(
      (a, b) => (regIndex.get(a.uid) ?? 0) - (regIndex.get(b.uid) ?? 0),
    );
  }

  const key = criteria[criterionIndex];
  const h2h = headToHead(group, matches);

  const keyOf = (row: StandingRow): number => {
    switch (key) {
      case "overallGoalDiff":
        return goalDiff(row);
      case "overallGoalsFor":
        return row.goalsFor;
      case "headToHeadPoints":
        return h2h.get(row.uid)?.points ?? 0;
      case "headToHeadGoalDiff":
        return h2h.get(row.uid)?.goalDiff ?? 0;
      case "headToHeadGoalsFor":
        return h2h.get(row.uid)?.goalsFor ?? 0;
    }
  };

  const sorted = [...group].sort((a, b) => keyOf(b) - keyOf(a));
  const result: StandingRow[] = [];
  let i = 0;
  while (i < sorted.length) {
    let j = i;
    while (j < sorted.length && keyOf(sorted[j]) === keyOf(sorted[i])) j++;
    const sub = sorted.slice(i, j);
    if (sub.length === 1) {
      result.push(sub[0]);
    } else {
      result.push(...rankTiedGroup(sub, matches, criteria, criterionIndex + 1, regIndex));
    }
    i = j;
  }
  return result;
}

/** Katılımcılar ve oynanmış maçlardan, seçilen moda göre puan tablosunu hesaplar. */
export function computeStandings(
  participants: Participant[],
  matches: Match[],
  mode: TiebreakerMode,
): StandingRow[] {
  const regIndex = new Map<string, number>();
  participants.forEach((p, i) => regIndex.set(p.uid, i));

  const rows = new Map<string, StandingRow>();
  const newRow = (uid: string, name: string): StandingRow => ({
    uid, name, played: 0, won: 0, drawn: 0, lost: 0, goalsFor: 0, goalsAgainst: 0,
  });
  for (const p of participants) rows.set(p.uid, newRow(p.uid, p.username));

  const rowFor = (uid: string, name: string): StandingRow => {
    if (!regIndex.has(uid)) regIndex.set(uid, regIndex.size);
    let r = rows.get(uid);
    if (!r) {
      r = newRow(uid, name);
      rows.set(uid, r);
    }
    return r;
  };

  const counted = matches.filter((m) => isPlayed(m) && !m.isBye);
  for (const m of counted) {
    const home = rowFor(m.homeUid, m.homeName);
    const away = rowFor(m.awayUid, m.awayName);
    const hs = m.homeScore as number;
    const as = m.awayScore as number;
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

  const all = [...rows.values()].sort((a, b) => points(b) - points(a));
  const criteria = criteriaFor(mode);
  const result: StandingRow[] = [];
  let i = 0;
  while (i < all.length) {
    let j = i;
    while (j < all.length && points(all[j]) === points(all[i])) j++;
    const group = all.slice(i, j);
    if (group.length === 1) {
      result.push(group[0]);
    } else {
      result.push(...rankTiedGroup(group, counted, criteria, 0, regIndex));
    }
    i = j;
  }
  return result;
}
