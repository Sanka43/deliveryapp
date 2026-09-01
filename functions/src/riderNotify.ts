import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import * as logger from "firebase-functions/logger";

/**
 * Shared rider inbox + push helpers. Lives on its own so the earnings
 * triggers and the cash-settlement callables use one implementation instead
 * of each keeping a private copy.
 */

export async function writeRiderInboxNotification(input: {
  riderId: string;
  notificationId: string;
  type: string;
  title: string;
  body: string;
  amountLkr?: number;
}): Promise<void> {
  const riderId = input.riderId.trim();
  if (!riderId) {
    return;
  }
  await getFirestore()
    .collection("riders")
    .doc(riderId)
    .collection("notifications")
    .doc(input.notificationId)
    .set(
      {
        type: input.type,
        title: input.title,
        body: input.body,
        amountLkr: input.amountLkr ?? null,
        read: false,
        createdAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
}

export async function sendPushToRider(input: {
  riderId: string;
  title: string;
  body: string;
  type: string;
}): Promise<void> {
  const riderSnap = await getFirestore()
    .collection("riders")
    .doc(input.riderId)
    .get();
  const token = String(riderSnap.data()?.fcmToken ?? "").trim();
  if (!token) {
    return;
  }
  try {
    await getMessaging().send({
      token,
      notification: {title: input.title, body: input.body},
      data: {
        type: input.type,
        title: input.title,
        body: input.body,
      },
      android: {priority: "high" as const},
      apns: {payload: {aps: {sound: "default"}}},
    });
  } catch (err) {
    logger.warn("Rider FCM send failed", {err, riderId: input.riderId});
  }
}

/** Inbox + push in one call — the shape every rider alert here needs. */
export async function notifyRider(input: {
  riderId: string;
  notificationId: string;
  type: string;
  title: string;
  body: string;
  amountLkr?: number;
}): Promise<void> {
  await writeRiderInboxNotification(input);
  await sendPushToRider({
    riderId: input.riderId,
    title: input.title,
    body: input.body,
    type: input.type,
  });
}
