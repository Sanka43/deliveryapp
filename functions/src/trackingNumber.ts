/** Shared date-scoped, sharded sequence numbers for order/ride tracking numbers. */

import {getFirestore} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

/** Sri Lanka — no DST. */
const COLOMBO_OFFSET_MS = (5 * 60 + 30) * 60 * 1000;

export const TRACKING_SEQUENCE_DIGITS = 4;
const SEQUENCE_SPACE = 10 ** TRACKING_SEQUENCE_DIGITS; // 10000, i.e. 0000-9999

/**
 * Sharded so concurrent bookings don't serialize on one hot document: with a
 * single counter, concurrent transactions racing to read+write it cause
 * Firestore transaction contention (aborts/retries surfacing as INTERNAL
 * errors, with multi-second latency). Each shard keeps its own independent
 * daily counter; the 4-digit sequence space is split evenly across shards
 * (200 each) so the final number stays unique without a cross-shard read.
 */
export const TRACKING_SEQUENCE_SHARDS = 50;
export const TRACKING_SEQUENCE_SHARD_RANGE = Math.floor(
  SEQUENCE_SPACE / TRACKING_SEQUENCE_SHARDS,
); // 200

/** `YYMMDD` in Asia/Colombo wall-clock time, so the number rolls over at local midnight. */
export function trackingDateKey(at: Date): string {
  const shifted = new Date(at.getTime() + COLOMBO_OFFSET_MS);
  const yy = String(shifted.getUTCFullYear() % 100).padStart(2, "0");
  const mm = String(shifted.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(shifted.getUTCDate()).padStart(2, "0");
  return `${yy}${mm}${dd}`;
}

/**
 * `shardSeq` is the shard's 1-indexed booking count for the day
 * (1..TRACKING_SEQUENCE_SHARD_RANGE). Maps to that shard's slice of the
 * 0000-9999 space so two shards never produce the same number.
 */
export function formatTrackingNumber(
  prefix: string,
  dateKey: string,
  shardId: number,
  shardSeq: number,
): string {
  const code = shardId * TRACKING_SEQUENCE_SHARD_RANGE + (shardSeq - 1);
  return `${prefix}${dateKey}${String(code).padStart(TRACKING_SEQUENCE_DIGITS, "0")}`;
}

/**
 * A shard can run out of its 200-per-day slice well before the platform's
 * overall ~9999/day capacity is reached (random shard assignment can land
 * unevenly), so a few retries on a different shard are cheap insurance
 * against that before giving up.
 */
const MAX_SHARD_ATTEMPTS = 5;

/**
 * Reserves the next tracking-number sequence value inside an in-flight
 * transaction. `counterPrefix` scopes the daily counter docs (e.g. "order",
 * "trip") so orders and rides don't share a sequence pool; `numberPrefix` is
 * the human-visible prefix on the formatted number (e.g. "MND", "Trip").
 */
export async function reserveTrackingNumber(
  tx: FirebaseFirestore.Transaction,
  counterPrefix: string,
  numberPrefix: string,
): Promise<string> {
  const db = getFirestore();
  const dateKey = trackingDateKey(new Date());
  const triedShards = new Set<number>();
  for (let attempt = 0; attempt < MAX_SHARD_ATTEMPTS; attempt++) {
    let shardId = Math.floor(Math.random() * TRACKING_SEQUENCE_SHARDS);
    while (
      triedShards.has(shardId) &&
      triedShards.size < TRACKING_SEQUENCE_SHARDS
    ) {
      shardId = Math.floor(Math.random() * TRACKING_SEQUENCE_SHARDS);
    }
    triedShards.add(shardId);

    const seqRef = db
      .collection("system")
      .doc(`${counterPrefix}_sequence_${dateKey}_shard_${shardId}`);
    const seqSnap = await tx.get(seqRef);
    const currentSeq = seqSnap.exists
      ? Math.floor(Number(seqSnap.data()?.value ?? 0))
      : 0;
    if (currentSeq >= TRACKING_SEQUENCE_SHARD_RANGE) {
      continue;
    }
    const nextSeq = currentSeq + 1;
    tx.set(seqRef, {value: nextSeq});
    return formatTrackingNumber(numberPrefix, dateKey, shardId, nextSeq);
  }
  throw new HttpsError(
    "resource-exhausted",
    "Too many bookings right now — please try again in a moment.",
  );
}
