import * as admin from 'firebase-admin';
const FieldValue = admin.firestore.FieldValue;
const Timestamp = admin.firestore.Timestamp;

export const K_FACTOR = 32;
export const DEFAULT_ELO = 1000;
export const MAX_ELO_HISTORY = 20;

export function expectedScore(ratingA: number, ratingB: number): number {
  return 1 / (1 + Math.pow(10, (ratingB - ratingA) / 400));
}

export function newRating(
  rating: number,
  expected: number,
  actual: number
): number {
  return Math.round(rating + K_FACTOR * (actual - expected));
}

export async function updateElo(
  db: admin.firestore.Firestore,
  homeUid: string,
  awayUid: string,
  homeScore: number,
  awayScore: number
): Promise<void> {
  const [homeSnap, awaySnap] = await Promise.all([
    db.collection('users').doc(homeUid).get(),
    db.collection('users').doc(awayUid).get(),
  ]);

  const homeR = (homeSnap.data()?.eloRating as number) ?? DEFAULT_ELO;
  const awayR = (awaySnap.data()?.eloRating as number) ?? DEFAULT_ELO;

  const homeExp = expectedScore(homeR, awayR);
  const awayExp = expectedScore(awayR, homeR);

  let homeActual: number, awayActual: number;
  if (homeScore > awayScore) { homeActual = 1; awayActual = 0; }
  else if (awayScore > homeScore) { homeActual = 0; awayActual = 1; }
  else { homeActual = 0.5; awayActual = 0.5; }

  const newHome = newRating(homeR, homeExp, homeActual);
  const newAway = newRating(awayR, awayExp, awayActual);
  const now = Timestamp.now();

  await Promise.all([
    db.collection('users').doc(homeUid).update({
      eloRating: newHome,
      eloHistory: FieldValue.arrayUnion([{
        rating: newHome,
        change: newHome - homeR,
        date: now,
      }]),
    }),
    db.collection('users').doc(awayUid).update({
      eloRating: newAway,
      eloHistory: FieldValue.arrayUnion([{
        rating: newAway,
        change: newAway - awayR,
        date: now,
      }]),
    }),
  ]);
}
