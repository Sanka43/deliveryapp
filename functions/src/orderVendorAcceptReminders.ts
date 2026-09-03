import {
  FieldValue,
  Timestamp,
  getFirestore,
  type DocumentData,
  type Query,
  type QueryDocumentSnapshot,
} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import {
  vendorOrderBody,
  writeVendorNotification,
} from "./orderNotifications";

export const REMINDER_1_MS = 2 * 60 * 1000;
export const REMINDER_2_MS = 5 * 60 * 1000;
export const AUTO_CANCEL_MS = 7 * 60 * 1000;

export type VendorAcceptAction = "none" | "reminder_1" | "reminder_2" | "cancel";

const ADMIN_ROLES = ["admin", "Admin", "ADMIN"];
const SWEEP_PAGE_SIZE = 200;
const MAX_PROCESS_PER_SWEEP = 80;

export function createdAtMillis(value: unknown): number | null {
  if (value instanceof Timestamp) {
    return value.toMillis();
  }
  if (value instanceof Date) {
    return value.getTime();
  }
  if (
    value != null &&
    typeof value === "object" &&
    "toMillis" in value &&
    typeof (value as {toMillis: unknown}).toMillis === "function"
  ) {
    const ms = (value as Timestamp).toMillis();
    return Number.isFinite(ms) ? ms : null;
  }
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  return null;
}

export function reminderStage(value: unknown): number {
  const n = Number(value ?? 0);
  if (!Number.isFinite(n) || n < 0) {
    return 0;
  }
  return Math.floor(n);
}

export function dueVendorAcceptAction(input: {
  status: string;
  orderSource?: string;
  createdAtMs: number | null;
  stage: number;
  nowMs: number;
}): VendorAcceptAction {
  if (String(input.status ?? "").trim().toLowerCase() !== "placed") {
    return "none";
  }
  if (String(input.orderSource ?? "").trim().toLowerCase() === "vendor_manual") {
    return "none";
  }
  if (input.createdAtMs == null) {
    return "none";
  }
  const age = input.nowMs - input.createdAtMs;
  const stage = reminderStage(input.stage);
  if (age >= AUTO_CANCEL_MS && stage < 3) {
    return "cancel";
  }
  if (age >= REMINDER_2_MS && stage < 2) {
    return "reminder_2";
  }
  if (age >= REMINDER_1_MS && stage < 1) {
    return "reminder_1";
  }
  return "none";
}

function reminderCopy(action: "reminder_1" | "reminder_2"): {
  title: string;
  type: string;
} {
  if (action === "reminder_1") {
    return {title: "Order waiting", type: "order_reminder"};
  }
  return {title: "Final reminder — confirm order", type: "order_reminder"};
}

async function notifyAdminsOfMissedOrder(input: {
  orderId: string;
  vendorId: string;
  storeName: string;
  trackingNumber: string;
}): Promise<void> {
  const db = getFirestore();
  const admins = await db
    .collection("customers")
    .where("role", "in", ADMIN_ROLES)
    .limit(50)
    .get();
  const title = "Shop missed an order";
  const tracking = input.trackingNumber || input.orderId;
  const store = input.storeName || "A shop";
  const body = `${store} did not confirm ${tracking} — order auto-cancelled.`;
  const messaging = getMessaging();

  await Promise.all(
    admins.docs.map(async (doc) => {
      const token = String(doc.data()?.fcmToken ?? "").trim();
      if (!token) {
        return;
      }
      try {
        await messaging.send({
          token,
          notification: {title, body},
          data: {
            type: "admin_alert",
            orderId: input.orderId,
            vendorId: input.vendorId,
            screen: "order",
            title,
            body,
          },
          android: {priority: "high" as const},
          apns: {payload: {aps: {sound: "default"}}},
        });
      } catch (err) {
        logger.warn("Admin FCM send failed", {
          err,
          adminId: doc.id,
          orderId: input.orderId,
        });
      }
    }),
  );
}

type SweepResult = {
  action: VendorAcceptAction;
  vendorId: string;
  storeName: string;
  trackingNumber: string;
  orderData: DocumentData;
  /** Stage read at decision time — `reminder_1`/`reminder_2` only. */
  priorStage?: number;
};

async function applyDueAction(
  orderId: string,
  nowMs: number,
): Promise<SweepResult | null> {
  const db = getFirestore();
  const ref = db.collection("orders").doc(orderId);

  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data();
    if (!data) {
      return null;
    }
    const priorStage = reminderStage(data.vendorAcceptReminderStage);
    const action = dueVendorAcceptAction({
      status: String(data.status ?? ""),
      orderSource: String(data.orderSource ?? ""),
      createdAtMs: createdAtMillis(data.createdAt),
      stage: priorStage,
      nowMs,
    });
    if (action === "none") {
      return null;
    }

    const vendorId = String(data.vendorId ?? data.vendorStoreId ?? "").trim();
    const storeName = String(data.storeName ?? "").trim();
    const trackingNumber = String(data.trackingNumber ?? "").trim();

    if (action === "cancel") {
      tx.update(ref, {
        status: "cancelled",
        cancelledBy: "system",
        cancellationReason: "vendor_no_response",
        cancelledAt: FieldValue.serverTimestamp(),
        adminEscalated: true,
        adminEscalatedAt: FieldValue.serverTimestamp(),
        adminEscalationReason: "vendor_no_response",
        vendorAcceptReminderStage: 2,
        updatedAt: FieldValue.serverTimestamp(),
      });
      tx.set(
        db.collection("admin_alerts").doc(orderId),
        {
          type: "vendor_no_response",
          orderId,
          vendorId,
          storeName,
          trackingNumber,
          customerId: String(data.customerId ?? ""),
          createdAt: FieldValue.serverTimestamp(),
          read: false,
        },
        {merge: true},
      );
      return {
        action,
        vendorId,
        storeName,
        trackingNumber,
        orderData: data,
      } satisfies SweepResult;
    }

    // Don't bump the stage yet for reminder_1/reminder_2 — only after the
    // notification actually goes out (see commitReminderStage below), so a
    // failed FCM/Firestore send can't silently fast-forward the order
    // toward auto-cancel without the vendor ever having been notified.
    return {
      action,
      vendorId,
      storeName,
      trackingNumber,
      orderData: data,
      priorStage,
    } satisfies SweepResult;
  });

  return result;
}

async function sendReminder(
  orderId: string,
  action: "reminder_1" | "reminder_2",
  result: SweepResult,
): Promise<void> {
  const copy = reminderCopy(action);
  const suffix = action === "reminder_1" ? "1" : "2";
  await writeVendorNotification({
    vendorId: result.vendorId,
    notificationId: `${orderId}_order_reminder_${suffix}`,
    orderId,
    type: copy.type,
    title: copy.title,
    body: vendorOrderBody(result.orderData),
    status: "placed",
  });
}

/**
 * Advances `vendorAcceptReminderStage` only after `sendReminder` above has
 * actually succeeded, and only if nothing else (a concurrent sweep, or the
 * vendor confirming) has already moved the stage since we decided to send.
 */
async function commitReminderStage(
  orderId: string,
  action: "reminder_1" | "reminder_2",
  priorStage: number,
): Promise<void> {
  const db = getFirestore();
  const ref = db.collection("orders").doc(orderId);
  const newStage = action === "reminder_1" ? 1 : 2;
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data();
    if (!data) {
      return;
    }
    if (reminderStage(data.vendorAcceptReminderStage) !== priorStage) {
      return;
    }
    tx.update(ref, {
      vendorAcceptReminderStage: newStage,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
}

export const sweepStalePlacedOrders = onSchedule(
  {
    schedule: "every 1 minutes",
    timeZone: "Asia/Colombo",
    region: "asia-south1",
    timeoutSeconds: 120,
    memory: "256MiB",
  },
  async () => {
    const db = getFirestore();
    const nowMs = Date.now();
    const cutoff = Timestamp.fromMillis(nowMs - REMINDER_1_MS);
    let last: QueryDocumentSnapshot | undefined;
    let scanned = 0;
    let processed = 0;
    const counts = {reminder_1: 0, reminder_2: 0, cancel: 0};

    pageLoop: for (;;) {
      let query: Query = db
        .collection("orders")
        .where("status", "==", "placed")
        .where("createdAt", "<=", cutoff)
        .orderBy("createdAt", "asc")
        .limit(SWEEP_PAGE_SIZE);
      if (last) {
        query = query.startAfter(last);
      }
      const snap = await query.get();
      if (snap.empty) {
        break;
      }
      last = snap.docs[snap.docs.length - 1];
      scanned += snap.size;

      for (const doc of snap.docs) {
        if (processed >= MAX_PROCESS_PER_SWEEP) {
          break pageLoop;
        }
        const data = doc.data();
        const preview = dueVendorAcceptAction({
          status: String(data.status ?? ""),
          orderSource: String(data.orderSource ?? ""),
          createdAtMs: createdAtMillis(data.createdAt),
          stage: reminderStage(data.vendorAcceptReminderStage),
          nowMs,
        });
        if (preview === "none") {
          continue;
        }

        try {
          const result = await applyDueAction(doc.id, nowMs);
          if (!result) {
            continue;
          }
          processed += 1;
          if (result.action === "reminder_1" || result.action === "reminder_2") {
            counts[result.action] += 1;
            await sendReminder(doc.id, result.action, result);
            await commitReminderStage(
              doc.id,
              result.action,
              result.priorStage ?? 0,
            );
          } else if (result.action === "cancel") {
            counts.cancel += 1;
            await notifyAdminsOfMissedOrder({
              orderId: doc.id,
              vendorId: result.vendorId,
              storeName: result.storeName,
              trackingNumber: result.trackingNumber,
            });
          }
        } catch (err) {
          logger.error("Vendor accept reminder sweep failed for order", {
            err,
            orderId: doc.id,
          });
        }
      }

      if (snap.size < SWEEP_PAGE_SIZE) {
        break;
      }
    }

    logger.info("Vendor accept reminder sweep complete", {
      scanned,
      processed,
      ...counts,
    });
  },
);
