/**
 * Sonraki tur üretimi — lib/services/fixture_generator.dart içindeki eleme tur
 * ilerletme fonksiyonlarının portu. Üretilen Map'ler doğrudan
 * `tournaments/{id}/matches` koleksiyonuna yazılabilir.
 */

import {kByeUid} from "./types";

function nextPowerOfTwo(n: number): number {
  let p = 1;
  while (p < n) p <<= 1;
  return p;
}

function knockoutRoundName(bracketSize: number): string {
  switch (bracketSize) {
    case 2:
      return "Final";
    case 4:
      return "Yarı Final";
    case 8:
      return "Çeyrek Final";
    case 16:
      return "Son 16";
    case 32:
      return "Son 32";
    default:
      return "Eleme Turu";
  }
}

/** Tek bir eleme maçı için Firestore'a yazılabilir Map (ortak şablon). */
function koMap(args: {
  homeUid: string;
  homeName: string;
  awayUid: string;
  awayName: string;
  isBye: boolean;
  roundNumber: number;
  order: number;
  roundName: string;
  leg?: number;
}): Record<string, unknown> {
  return {
    round: args.roundName,
    roundNumber: args.roundNumber,
    order: args.order,
    homeUid: args.homeUid,
    homeName: args.homeName,
    awayUid: args.awayUid,
    awayName: args.awayName,
    homeScore: null,
    awayScore: null,
    played: false,
    isBye: args.isBye,
    stage: "knockout",
    phase: "knockout",
    group: "",
    status: "pending",
    leg: args.leg ?? 1,
  };
}

/**
 * Bir eleme turu bittiğinde kazananlardan sonraki turun maçlarını üretir.
 *
 * [twoLegged] true ise her gerçek eşleşme için iki ayak (ev/deplasman) üretilir
 * (Şampiyonlar Ligi eleme aşaması); bye eşleşmeleri tek maçtır.
 */
export function generateNextKnockoutRound(
  winnerUids: string[],
  uidToName: Map<string, string>,
  nextRound: number,
  twoLegged = false,
): Record<string, unknown>[] {
  if (winnerUids.length < 2) return [];
  const roundName = knockoutRoundName(nextPowerOfTwo(winnerUids.length));
  const orderBase = nextRound * 1000;
  const matches: Record<string, unknown>[] = [];
  let order = 0;
  for (let i = 0; i < winnerUids.length; i += 2) {
    if (i + 1 < winnerUids.length) {
      const homeUid = winnerUids[i];
      const awayUid = winnerUids[i + 1];
      const homeName = uidToName.get(homeUid) ?? "Oyuncu";
      const awayName = uidToName.get(awayUid) ?? "Oyuncu";
      // 1. ayak.
      matches.push(koMap({
        homeUid, homeName, awayUid, awayName,
        isBye: false,
        roundNumber: nextRound,
        order: orderBase + order++,
        roundName,
        leg: 1,
      }));
      // 2. ayak (yalnızca iki ayaklıysa): ev/deplasman değişir.
      if (twoLegged) {
        matches.push(koMap({
          homeUid: awayUid, homeName: awayName, awayUid: homeUid, awayName: homeName,
          isBye: false,
          roundNumber: nextRound,
          order: orderBase + order++,
          roundName,
          leg: 2,
        }));
      }
    } else {
      matches.push(koMap({
        homeUid: winnerUids[i],
        homeName: uidToName.get(winnerUids[i]) ?? "Oyuncu",
        awayUid: kByeUid,
        awayName: "Bye",
        isBye: true,
        roundNumber: nextRound,
        order: orderBase + order++,
        roundName,
        leg: 1,
      }));
    }
  }
  return matches;
}

/** Grup birincileri/ikincilerini çapraz eşleştirerek ilk eleme turunu üretir. */
export function generateKnockoutFromGroups(
  groupWinners: string[][],
  uidToName: Map<string, string>,
  startRound: number,
): Record<string, unknown>[] {
  const valid = groupWinners.filter((g) => g.length >= 2);
  const g = valid.length;
  if (g === 0) return [];

  const pairs: [string, string][] = [];
  if (g % 2 === 0) {
    for (let i = 0; i < g; i += 2) pairs.push([valid[i][0], valid[i + 1][1]]);
    for (let i = 0; i < g; i += 2) pairs.push([valid[i + 1][0], valid[i][1]]);
  } else {
    for (let i = 0; i < g; i++) pairs.push([valid[i][0], valid[(i + 1) % g][1]]);
  }

  const roundName = knockoutRoundName(nextPowerOfTwo(pairs.length * 2));
  const orderBase = startRound * 1000;
  return pairs.map(([homeUid, awayUid], i) => koMap({
    homeUid,
    homeName: uidToName.get(homeUid) ?? "Oyuncu",
    awayUid,
    awayName: uidToName.get(awayUid) ?? "Oyuncu",
    isBye: false,
    roundNumber: startRound,
    order: orderBase + i,
    roundName,
  }));
}

/**
 * Sıralı (seeded) oyuncu listesinden çapraz eşleşmeli eleme turu üretir.
 *
 * Şampiyonlar Ligi eleme aşaması ÇİFT MAÇLIDIR (iki ayaklı): her gerçek eşleşme
 * için 1. ayak (üst sıralı ev sahibi) ve 2. ayak (ev/deplasman değişir) üretilir.
 * Bye eşleşmeleri tek maçtır.
 */
export function generateKnockoutFromSeeds(
  seedUids: string[],
  uidToName: Map<string, string>,
  startRound: number,
): Record<string, unknown>[] {
  const q = seedUids.length;
  if (q < 2) return [];
  const roundName = knockoutRoundName(nextPowerOfTwo(q));
  const orderBase = startRound * 1000;
  const matches: Record<string, unknown>[] = [];
  let order = 0;
  for (let i = 0; i * 2 < q; i++) {
    const awayIdx = q - 1 - i;
    if (awayIdx > i) {
      const homeUid = seedUids[i];
      const awayUid = seedUids[awayIdx];
      const homeName = uidToName.get(homeUid) ?? "Oyuncu";
      const awayName = uidToName.get(awayUid) ?? "Oyuncu";
      // 1. ayak: üst sıralı (seed) oyuncu ev sahibi.
      matches.push(koMap({
        homeUid, homeName, awayUid, awayName,
        isBye: false,
        roundNumber: startRound,
        order: orderBase + order++,
        roundName,
        leg: 1,
      }));
      // 2. ayak: ev/deplasman değişir.
      matches.push(koMap({
        homeUid: awayUid, homeName: awayName, awayUid: homeUid, awayName: homeName,
        isBye: false,
        roundNumber: startRound,
        order: orderBase + order++,
        roundName,
        leg: 2,
      }));
    } else if (awayIdx === i) {
      const homeUid = seedUids[i];
      matches.push(koMap({
        homeUid,
        homeName: uidToName.get(homeUid) ?? "Oyuncu",
        awayUid: kByeUid,
        awayName: "Bye",
        isBye: true,
        roundNumber: startRound,
        order: orderBase + order++,
        roundName,
        leg: 1,
      }));
    }
  }
  return matches;
}
