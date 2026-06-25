import {computeStandings} from "../src/standings";
import {Match, Participant, TiebreakerMode} from "../src/types";

/**
 * test/domain/standings_test.dart (Dart tarafı) ile BİREBİR aynı kurgu —
 * bu dosyanın amacı istemci/sunucu pariteyi doğrulamaktır.
 */
function match(opts: {
  id: string;
  home: string;
  away: string;
  homeScore: number | null;
  awayScore: number | null;
  isBye?: boolean;
}): Match {
  return {
    id: opts.id,
    round: "1",
    roundNumber: 1,
    phase: "",
    group: "",
    order: 0,
    homeUid: opts.home,
    homeName: opts.home,
    awayUid: opts.away,
    awayName: opts.away,
    homeScore: opts.homeScore,
    awayScore: opts.awayScore,
    isBye: opts.isBye ?? false,
    status: "completed",
    leg: 1,
  };
}

const a: Participant = {uid: "A", username: "A"};
const b: Participant = {uid: "B", username: "B"};
const c: Participant = {uid: "C", username: "C"};

/**
 * test/domain/standings_test.dart::_threeWayCycleMatches ile aynı fikstür:
 * A,B,C kendi aralarında 1'er kez oynar (A 3-0 B, B 1-0 C, C 1-0 A) + her biri
 * "D" rakibine karşı 1 galibiyet + 1 mağlubiyet alır. Sonuç: genel puan ve
 * genel averaj üçü için de eşit, ama ikili averaj (h2h) farklı.
 */
function threeWayCycleMatches(): Match[] {
  return [
    match({id: "1", home: "A", away: "B", homeScore: 3, awayScore: 0}),
    match({id: "2", home: "B", away: "C", homeScore: 1, awayScore: 0}),
    match({id: "3", home: "C", away: "A", homeScore: 1, awayScore: 0}),
    match({id: "4", home: "A", away: "D", homeScore: 1, awayScore: 0}),
    match({id: "5", home: "D", away: "A", homeScore: 3, awayScore: 0}),
    match({id: "6", home: "B", away: "D", homeScore: 3, awayScore: 0}),
    match({id: "7", home: "D", away: "B", homeScore: 1, awayScore: 0}),
    match({id: "8", home: "C", away: "D", homeScore: 1, awayScore: 0}),
    match({id: "9", home: "D", away: "C", homeScore: 1, awayScore: 0}),
  ];
}

describe("computeStandings (TS - Dart ile parite)", () => {
  test("2 oyuncu: net kazanan birinci sıraya gelir (Dart testiyle parite)", () => {
    const result = computeStandings(
      [a, b],
      [match({id: "1", home: "A", away: "B", homeScore: 3, awayScore: 0})],
      "uefa" as TiebreakerMode,
    );

    expect(result[0].uid).toBe("A");
    expect(result[0].won * 3 + result[0].drawn).toBe(3);
    expect(result[result.length - 1].won * 3 + result[result.length - 1].drawn).toBe(0);
  });

  test(
    "3 oyuncu eşit puan + eşit genel averaj: UEFA ikili averaj kuralı " +
      "Dart fixture ile aynı sonucu üretir (A, C, B)",
    () => {
      const participants = [a, b, c];
      const matches = threeWayCycleMatches();

      const result = computeStandings(participants, matches, "uefa" as TiebreakerMode);

      const points = (uid: string) => {
        const r = result.find((row) => row.uid === uid)!;
        return r.won * 3 + r.drawn;
      };
      const goalDiff = (uid: string) => {
        const r = result.find((row) => row.uid === uid)!;
        return r.goalsFor - r.goalsAgainst;
      };

      // Genel puan/averajın gerçekten eşit olduğunu doğrula (Dart testiyle aynı).
      expect(points("A")).toBe(points("B"));
      expect(points("B")).toBe(points("C"));
      expect(goalDiff("A")).toBe(0);
      expect(goalDiff("B")).toBe(0);
      expect(goalDiff("C")).toBe(0);

      const order = result.map((r) => r.uid).filter((uid) => ["A", "B", "C"].includes(uid));
      expect(order).toEqual(["A", "C", "B"]);
    },
  );

  test("FIFA ve UEFA modu aynı girdide farklı sıralama üretir (Dart ile parite)", () => {
    const participants = [a, b, c];
    const matches = threeWayCycleMatches();

    const fifaOrder = computeStandings(participants, matches, "fifa" as TiebreakerMode)
      .map((r) => r.uid)
      .filter((uid) => ["A", "B", "C"].includes(uid));
    const uefaOrder = computeStandings(participants, matches, "uefa" as TiebreakerMode)
      .map((r) => r.uid)
      .filter((uid) => ["A", "B", "C"].includes(uid));

    expect(fifaOrder).toEqual(["A", "B", "C"]);
    expect(uefaOrder).toEqual(["A", "C", "B"]);
    expect(fifaOrder).not.toEqual(uefaOrder);
  });
});
