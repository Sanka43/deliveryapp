import {FieldValue, Timestamp, getFirestore} from "firebase-admin/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";

/**
 * Dead-man switch for rider presence. The app heartbeats
 * `locationUpdatedAt` every ~60s while online; if the app is killed, loses
 * network, or crashes, this sweep flips `online: false` so customers and
 * dispatch logic stop seeing ghost riders.
 */
export const STALE_PRESENCE_MS = 3 * 60 * 1000;

export function isPresenceFresh(
  locationUpdatedAt: unknown,
  nowMs: number = Date.now(),
): boolean {
  if (!(locationUpdatedAt instanceof Timestamp)) {
    return false;
  }
  return locationUpdatedAt.toMillis() >= nowMs - STALE_PRESENCE_MS;
}

export const sweepStaleRiderPresence = onSchedule(
  {schedule: "every 5 minutes", region: "asia-south1"},
  async () => {
    const db = getFirestore();
    const snap = await db
      .collection("riders")
      .where("online", "==", true)
      .get();

    const stale = snap.docs.filter(
      (doc) => !isPresenceFresh(doc.data().locationUpdatedAt),
    );
    if (stale.length === 0) {
      logger.info(`Presence sweep: ${snap.size} online, none stale`);
      return;
    }

    // Firestore batches cap at 500 writes; chunk defensively.
    for (let i = 0; i < stale.length; i += 400) {
      const batch = db.batch();
      for (const doc of stale.slice(i, i + 400)) {
        batch.set(
          doc.ref,
          {online: false, updatedAt: FieldValue.serverTimestamp()},
          {merge: true},
        );
      }
      await batch.commit();
    }

    logger.info(
      `Presence sweep: ${snap.size} online, ${stale.length} flipped offline`,
      {staleRiderIds: stale.map((d) => d.id)},
    );
  },
);
