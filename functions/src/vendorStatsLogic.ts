export type OrderData = Record<string, unknown>;

export type StatMutation = {
  collection:
    | "daily_stats"
    | "weekly_stats"
    | "monthly_stats"
    | "yearly_stats"
    | "product_stats"
    | "product_daily_stats";
  docId: string;
  data: Record<string, unknown>;
  increments: Record<string, number>;
};

export function readString(value: unknown): string {
  return String(value ?? "").trim();
}

export function readNumber(value: unknown): number {
  const n = Number(value ?? 0);
  return Number.isFinite(n) ? n : 0;
}

export function orderVendorId(order: OrderData): string {
  return readString(order.vendorId) || readString(order.vendorStoreId);
}

export function orderStatus(order: OrderData): string {
  return readString(order.status).toLowerCase();
}

export function isCompletedStatus(status: string): boolean {
  return status === "completed" || status === "delivered";
}

export function orderDate(order: OrderData, fallback = new Date()): Date {
  const createdAt = order.createdAt;
  if (
    createdAt != null &&
    typeof createdAt === "object" &&
    "toDate" in createdAt &&
    typeof createdAt.toDate === "function"
  ) {
    const d = createdAt.toDate();
    if (d instanceof Date && !Number.isNaN(d.getTime())) {
      return d;
    }
  }
  return fallback;
}

export function dayKey(date: Date): string {
  return date.toISOString().slice(0, 10);
}

export function monthKey(date: Date): string {
  return date.toISOString().slice(0, 7);
}

export function yearKey(date: Date): string {
  return date.toISOString().slice(0, 4);
}

export function weekKey(date: Date): string {
  const d = new Date(Date.UTC(
    date.getUTCFullYear(),
    date.getUTCMonth(),
    date.getUTCDate(),
  ));
  const day = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const week = Math.ceil((((d.getTime() - yearStart.getTime()) / 86400000) + 1) / 7);
  return `${d.getUTCFullYear()}-W${week.toString().padStart(2, "0")}`;
}

export function safeDocId(value: string): string {
  const normalized = value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_-]+/g, "_")
    .replace(/_+/g, "_")
    .replace(/^_|_$/g, "");
  return normalized || "unknown";
}

function orderItems(order: OrderData): Array<Record<string, unknown>> {
  return Array.isArray(order.items) ?
    order.items.filter((item): item is Record<string, unknown> => {
      return item != null && typeof item === "object" && !Array.isArray(item);
    }) :
    [];
}

export function productStats(order: OrderData): Array<{
  id: string;
  name: string;
  quantity: number;
  grossLkr: number;
}> {
  return orderItems(order).map((item) => {
    const name = readString(item.productName) || "Order item";
    const key = readString(item.productKey) || name;
    return {
      id: safeDocId(key),
      name,
      quantity: Math.max(0, Math.round(readNumber(item.quantity))),
      grossLkr: readNumber(item.lineTotal),
    };
  }).filter((item) => item.quantity > 0 || item.grossLkr > 0);
}

function periodMutations(
  order: OrderData,
  direction: 1 | -1,
  fallbackDate?: Date,
): StatMutation[] {
  const date = orderDate(order, fallbackDate);
  const grossLkr = readNumber(order.total) * direction;
  const discountLkr = readNumber(order.discount) * direction;
  const deliveryFeeLkr = readNumber(order.deliveryFee) * direction;
  const netSalesLkr = (readNumber(order.total) - readNumber(order.deliveryFee)) * direction;
  return [
    {
      collection: "daily_stats",
      docId: dayKey(date),
      data: {date: dayKey(date)},
      increments: {
        grossLkr,
        netSalesLkr,
        discountLkr,
        deliveryFeeLkr,
        completedOrders: direction,
      },
    },
    {
      collection: "weekly_stats",
      docId: weekKey(date),
      data: {week: weekKey(date)},
      increments: {
        grossLkr,
        netSalesLkr,
        discountLkr,
        deliveryFeeLkr,
        completedOrders: direction,
      },
    },
    {
      collection: "monthly_stats",
      docId: monthKey(date),
      data: {month: monthKey(date)},
      increments: {
        grossLkr,
        netSalesLkr,
        discountLkr,
        deliveryFeeLkr,
        completedOrders: direction,
      },
    },
    {
      collection: "yearly_stats",
      docId: yearKey(date),
      data: {year: yearKey(date)},
      increments: {
        grossLkr,
        netSalesLkr,
        discountLkr,
        deliveryFeeLkr,
        completedOrders: direction,
      },
    },
  ];
}

function productMutations(
  order: OrderData,
  direction: 1 | -1,
  fallbackDate?: Date,
): StatMutation[] {
  const date = orderDate(order, fallbackDate);
  const dateKey = dayKey(date);
  return productStats(order).flatMap((item) => [
    {
      collection: "product_stats",
      docId: item.id,
      data: {
        productKey: item.id,
        productName: item.name,
      },
      increments: {
        grossLkr: item.grossLkr * direction,
        quantity: item.quantity * direction,
        completedOrders: direction,
      },
    },
    {
      collection: "product_daily_stats",
      docId: `${dateKey}_${item.id}`,
      data: {
        date: dateKey,
        productKey: item.id,
        productName: item.name,
      },
      increments: {
        grossLkr: item.grossLkr * direction,
        quantity: item.quantity * direction,
        completedOrders: direction,
      },
    },
  ]);
}

function cancellationMutations(order: OrderData, fallbackDate?: Date): StatMutation[] {
  const date = orderDate(order, fallbackDate);
  return [
    {
      collection: "daily_stats",
      docId: dayKey(date),
      data: {date: dayKey(date)},
      increments: {cancelledOrders: 1},
    },
    {
      collection: "weekly_stats",
      docId: weekKey(date),
      data: {week: weekKey(date)},
      increments: {cancelledOrders: 1},
    },
    {
      collection: "monthly_stats",
      docId: monthKey(date),
      data: {month: monthKey(date)},
      increments: {cancelledOrders: 1},
    },
    {
      collection: "yearly_stats",
      docId: yearKey(date),
      data: {year: yearKey(date)},
      increments: {cancelledOrders: 1},
    },
  ];
}

export function mutationsForOrderCreated(
  order: OrderData,
  fallbackDate?: Date,
): StatMutation[] {
  const status = orderStatus(order);
  if (isCompletedStatus(status)) {
    return [
      ...periodMutations(order, 1, fallbackDate),
      ...productMutations(order, 1, fallbackDate),
    ];
  }
  if (status === "cancelled") {
    return cancellationMutations(order, fallbackDate);
  }
  return [];
}

export function mutationsForOrderUpdated(
  before: OrderData,
  after: OrderData,
  fallbackDate?: Date,
): StatMutation[] {
  const mutations: StatMutation[] = [];
  const beforeCompleted = isCompletedStatus(orderStatus(before));
  const afterCompleted = isCompletedStatus(orderStatus(after));
  if (beforeCompleted && !afterCompleted) {
    mutations.push(
      ...periodMutations(before, -1, fallbackDate),
      ...productMutations(before, -1, fallbackDate),
    );
  } else if (!beforeCompleted && afterCompleted) {
    mutations.push(
      ...periodMutations(after, 1, fallbackDate),
      ...productMutations(after, 1, fallbackDate),
    );
  }

  if (orderStatus(before) !== "cancelled" && orderStatus(after) === "cancelled") {
    mutations.push(...cancellationMutations(after, fallbackDate));
  }
  return mutations;
}
