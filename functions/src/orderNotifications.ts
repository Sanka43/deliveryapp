import {getFirestore, FieldValue} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";

const SHOP_ORDERS_CHANNEL_ID = "mnd_shop_orders";
const SHOP_ORDER_SOUND = "new_order";

const STATUS_COPY: Record<string, {title: string; body: string}> = {
  placed: {
    title: "Order placed",
    body: "We received your order and notified the store.",
  },
  confirmed: {
    title: "Order confirmed",
    body: "The store confirmed your order.",
  },
  preparing: {
    title: "Preparing your order",
    body: "The kitchen is working on your items.",
  },
  ready: {
    title: "Order ready",
    body: "Your order is ready for pickup or delivery.",
  },
  out_for_delivery: {
    title: "Out for delivery",
    body: "A rider picked up your order.",
  },
  on_the_way: {
    title: "On the way",
    body: "Your order is almost there.",
  },
  picked_up: {
    title: "Picked up",
    body: "Your rider has picked up the order.",
  },
  delivered: {
    title: "Delivered",
    body: "Your order was delivered. Enjoy!",
  },
  completed: {
    title: "Order completed",
    body: "Thank you for ordering with MND.",
  },
  cancelled: {
    title: "Order cancelled",
    body: "Your order was cancelled.",
  },
};

type OrderNotificationData = Record<string, unknown>;

async function countOnlineApprovedRiders(): Promise<number> {
  const snap = await getFirestore()
    .collection("riders")
    .where("online", "==", true)
    .limit(20)
    .get();
  return snap.docs.filter((doc) => {
    const status = String(doc.data().status ?? "").trim().toLowerCase();
    return status === "approved" || status === "active";
  }).length;
}

function statusMessage(
  status: string,
  storeName?: string,
  trackingNumber?: string,
  options?: {noRidersOnline?: boolean; isDelivery?: boolean},
): {title: string; body: string} {
  const key = status.trim().toLowerCase();
  const base = STATUS_COPY[key] ?? {
    title: "Order update",
    body: `Status: ${status}`,
  };
  const store = (storeName ?? "").trim();
  const tracking = (trackingNumber ?? "").trim();
  let body = base.body;
  if (
    key === "ready" &&
    options?.isDelivery === true &&
    options?.noRidersOnline === true
  ) {
    body =
      "Your order is ready at the store. No riders are online right now — we are looking for someone to deliver.";
  } else if (key === "ready" && options?.isDelivery === true) {
    body =
      "Your order is ready — a nearby rider will be notified shortly.";
  }
  if (store) {
    body = `${store} — ${body}`;
  }
  if (tracking) {
    body = `${body} (${tracking})`;
  }
  return {title: base.title, body};
}

async function writeInboxNotification(input: {
  userId: string;
  orderId: string;
  type: string;
  title: string;
  body: string;
  status?: string;
}): Promise<void> {
  await getFirestore().collection("notifications").add({
    userId: input.userId,
    orderId: input.orderId,
    type: input.type,
    title: input.title,
    body: input.body,
    status: input.status ?? null,
    read: false,
    createdAt: FieldValue.serverTimestamp(),
  });
}

function moneyLabel(value: unknown): string {
  const n = Number(value ?? 0);
  if (!Number.isFinite(n) || n <= 0) {
    return "";
  }
  return `Rs. ${n.toFixed(2)}`;
}

function orderReference(data: OrderNotificationData): string {
  return String(data.trackingNumber ?? "").trim();
}

function vendorOrderBody(data: OrderNotificationData): string {
  const tracking = orderReference(data);
  const total = moneyLabel(data.total);
  const deliveryAddress =
    data.deliveryAddress != null && typeof data.deliveryAddress === "object" ?
      data.deliveryAddress as Record<string, unknown> :
      {};
  const customerPhone = String(deliveryAddress.phone ?? "").trim();
  const parts = [tracking, total, customerPhone].filter((part) => part.length > 0);
  return parts.length > 0 ? parts.join(" · ") : "Open the order board for details.";
}

async function writeVendorNotification(input: {
  vendorId: string;
  notificationId: string;
  orderId?: string;
  type: string;
  title: string;
  body: string;
  status?: string;
}): Promise<void> {
  const vendorId = input.vendorId.trim();
  if (!vendorId) {
    return;
  }
  await getFirestore()
    .collection("vendors")
    .doc(vendorId)
    .collection("notifications")
    .doc(input.notificationId)
    .set(
      {
        orderId: input.orderId ?? null,
        type: input.type,
        title: input.title,
        body: input.body,
        status: input.status ?? null,
        read: false,
        createdAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  await sendPushToVendor({
    vendorId,
    orderId: input.orderId,
    type: input.type,
    title: input.title,
    body: input.body,
    status: input.status,
  });
}

async function sendPushToVendor(input: {
  vendorId: string;
  orderId?: string;
  type: string;
  title: string;
  body: string;
  status?: string;
}): Promise<void> {
  const vendorSnap = await getFirestore()
    .collection("vendors")
    .doc(input.vendorId)
    .get();
  const token = String(vendorSnap.data()?.fcmToken ?? "").trim();
  if (!token) {
    logger.warn("No vendor FCM token; inbox notification only", {
      vendorId: input.vendorId,
      orderId: input.orderId ?? "",
      type: input.type,
    });
    return;
  }

  const payload = {
    notification: {title: input.title, body: input.body},
    data: {
      type: input.type,
      vendorId: input.vendorId,
      orderId: input.orderId ?? "",
      status: input.status ?? "",
      title: input.title,
      body: input.body,
    },
    android: {
      priority: "high" as const,
      notification: {
        channelId: SHOP_ORDERS_CHANNEL_ID,
        sound: SHOP_ORDER_SOUND,
      },
    },
    apns: {payload: {aps: {sound: "default"}}},
  };

  try {
    await getMessaging().send({token, ...payload});
  } catch (err) {
    logger.warn("Vendor FCM token send failed; inbox notification only", {
      err,
      vendorId: input.vendorId,
      orderId: input.orderId ?? "",
      type: input.type,
    });
  }
}

async function sendPushToCustomer(input: {
  customerId: string;
  orderId: string;
  title: string;
  body: string;
  status?: string;
}): Promise<void> {
  const customerSnap = await getFirestore()
    .collection("customers")
    .doc(input.customerId)
    .get();
  const token = String(customerSnap.data()?.fcmToken ?? "").trim();

  const payload = {
    notification: {title: input.title, body: input.body},
    data: {
      orderId: input.orderId,
      screen: "order",
      status: input.status ?? "",
    },
    android: {priority: "high" as const},
    apns: {payload: {aps: {sound: "default"}}},
  };

  const messaging = getMessaging();
  if (!token) {
    logger.warn("No customer FCM token; inbox notification only", {
      customerId: input.customerId,
      orderId: input.orderId,
    });
    return;
  }

  try {
    await messaging.send({token, ...payload});
  } catch (err) {
    logger.warn("Customer FCM token send failed; inbox notification only", {
      err,
      customerId: input.customerId,
      orderId: input.orderId,
    });
  }
}

async function notifyCustomerOrderEvent(input: {
  customerId: string;
  orderId: string;
  type: string;
  title: string;
  body: string;
  status?: string;
}): Promise<void> {
  if (!input.customerId) {
    return;
  }
  await writeInboxNotification({
    userId: input.customerId,
    orderId: input.orderId,
    type: input.type,
    title: input.title,
    body: input.body,
    status: input.status,
  });
  try {
    await sendPushToCustomer(input);
  } catch (err) {
    logger.error("Push delivery failed", {err, orderId: input.orderId});
  }
}

export const onOrderCreatedNotify = onDocumentCreated(
  {document: "orders/{orderId}", region: "asia-south1"},
  async (event) => {
    const data = event.data?.data();
    if (!data) {
      return;
    }
    const customerId = String(data.customerId ?? "");
    const status = String(data.status ?? "placed");
    const storeName = String(data.storeName ?? "");
    const trackingNumber = String(data.trackingNumber ?? "");
    const vendorId = String(data.vendorId ?? data.vendorStoreId ?? "");
    const msg = statusMessage(status, storeName, trackingNumber);

    await Promise.all([
      notifyCustomerOrderEvent({
        customerId,
        orderId: event.params.orderId,
        type: "order_status",
        title: msg.title,
        body: msg.body,
        status,
      }),
      writeVendorNotification({
        vendorId,
        notificationId: `${event.params.orderId}_order_new`,
        orderId: event.params.orderId,
        type: "order_new",
        title: "New order",
        body: vendorOrderBody(data),
        status,
      }),
    ]);
  },
);

export const onOrderStatusUpdatedNotify = onDocumentUpdated(
  {document: "orders/{orderId}", region: "asia-south1"},
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) {
      return;
    }

    const prevStatus = String(before.status ?? "");
    const nextStatus = String(after.status ?? "");
    if (prevStatus === nextStatus) {
      return;
    }

    const customerId = String(after.customerId ?? "");
    const storeName = String(after.storeName ?? "");
    const trackingNumber = String(after.trackingNumber ?? "");
    const vendorId = String(after.vendorId ?? after.vendorStoreId ?? "");
    const fulfillmentMode = String(after.fulfillmentMode ?? "delivery");
    const isDelivery = fulfillmentMode !== "selfPickup";
    let noRidersOnline = false;
    if (nextStatus === "ready" && isDelivery && after.openForRiders === true) {
      noRidersOnline = (await countOnlineApprovedRiders()) === 0;
    }
    const msg = statusMessage(nextStatus, storeName, trackingNumber, {
      isDelivery,
      noRidersOnline,
    });

    const writes: Array<Promise<void>> = [
      notifyCustomerOrderEvent({
        customerId,
        orderId: event.params.orderId,
        type: "order_status",
        title: msg.title,
        body: msg.body,
        status: nextStatus,
      }),
    ];
    if (nextStatus === "cancelled") {
      writes.push(
        writeVendorNotification({
          vendorId,
          notificationId: `${event.params.orderId}_order_cancelled`,
          orderId: event.params.orderId,
          type: "order_cancelled",
          title: "Order cancelled",
          body: vendorOrderBody(after),
          status: nextStatus,
        }),
      );
    }

    await Promise.all(writes);
  },
);

export const onVendorApprovalStatusUpdatedNotify = onDocumentUpdated(
  {document: "vendors/{vendorId}", region: "asia-south1"},
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) {
      return;
    }

    const prevStatus = String(before.approvalStatus ?? "").trim().toLowerCase();
    const nextStatus = String(after.approvalStatus ?? "").trim().toLowerCase();
    if (!nextStatus || prevStatus === nextStatus) {
      return;
    }

    let title = "Shop approval update";
    let body = `Your shop approval status changed to ${nextStatus}.`;
    if (nextStatus === "approved") {
      title = "Shop approved";
      body = "Your shop is approved. You can now open for orders.";
    } else if (nextStatus === "rejected") {
      title = "Shop needs changes";
      body = "Your shop was not approved yet. Check your details and contact support.";
    } else if (nextStatus === "pending") {
      title = "Shop pending approval";
      body = "Your shop is waiting for admin review.";
    }

    await writeVendorNotification({
      vendorId: event.params.vendorId,
      notificationId: `approval_${nextStatus}`,
      type: "approval",
      title,
      body,
      status: nextStatus,
    });
  },
);
