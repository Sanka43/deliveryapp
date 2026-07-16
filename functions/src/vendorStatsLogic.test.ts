import assert from "node:assert/strict";
import test from "node:test";
import {
  type OrderData,
  mutationsForOrderCreated,
  mutationsForOrderUpdated,
} from "./vendorStatsLogic";

const fixedDate = new Date("2026-07-10T10:15:00.000Z");

function completedOrder(overrides: OrderData = {}): OrderData {
  return {
    vendorId: "vendor-1",
    status: "completed",
    total: 1500,
    items: [
      {
        productKey: "rice_curry",
        productName: "Rice & Curry",
        quantity: 2,
        lineTotal: 1200,
      },
      {
        productKey: "faluda",
        productName: "Faluda",
        quantity: 1,
        lineTotal: 300,
      },
    ],
    ...overrides,
  };
}

test("completed order increments daily, weekly, monthly, and product stats once", () => {
  const mutations = mutationsForOrderCreated(completedOrder(), fixedDate);

  assert.deepEqual(
    mutations.map((mutation) => `${mutation.collection}/${mutation.docId}`),
    [
      "daily_stats/2026-07-10",
      "weekly_stats/2026-W28",
      "monthly_stats/2026-07",
      "yearly_stats/2026",
      "product_stats/rice_curry",
      "product_daily_stats/2026-07-10_rice_curry",
      "product_stats/faluda",
      "product_daily_stats/2026-07-10_faluda",
    ],
  );
  assert.deepEqual(mutations[0].increments, {
    grossLkr: 1500,
    netSalesLkr: 1500,
    discountLkr: 0,
    deliveryFeeLkr: 0,
    completedOrders: 1,
  });
  assert.deepEqual(mutations[4].increments, {
    grossLkr: 1200,
    quantity: 2,
    completedOrders: 1,
  });
});

test("completed to completed update does not duplicate sales", () => {
  const before = completedOrder({total: 1500});
  const after = completedOrder({total: 1800});

  assert.deepEqual(mutationsForOrderUpdated(before, after, fixedDate), []);
});

test("placed to completed update increments sales", () => {
  const before = completedOrder({status: "placed"});
  const after = completedOrder();

  const mutations = mutationsForOrderUpdated(before, after, fixedDate);

  assert.equal(mutations.length, 8);
  assert.deepEqual(mutations[0].increments, {
    grossLkr: 1500,
    netSalesLkr: 1500,
    discountLkr: 0,
    deliveryFeeLkr: 0,
    completedOrders: 1,
  });
});

test("placed to delivered update increments sales", () => {
  const before = completedOrder({status: "placed"});
  const after = completedOrder({status: "delivered"});

  const mutations = mutationsForOrderUpdated(before, after, fixedDate);

  assert.equal(mutations.length, 8);
  assert.deepEqual(mutations[0].increments, {
    grossLkr: 1500,
    netSalesLkr: 1500,
    discountLkr: 0,
    deliveryFeeLkr: 0,
    completedOrders: 1,
  });
});

test("completed to cancelled reverses sales and increments cancellations", () => {
  const before = completedOrder();
  const after = completedOrder({status: "cancelled"});

  const mutations = mutationsForOrderUpdated(before, after, fixedDate);

  assert.deepEqual(
    mutations.map((mutation) => `${mutation.collection}/${mutation.docId}`),
    [
      "daily_stats/2026-07-10",
      "weekly_stats/2026-W28",
      "monthly_stats/2026-07",
      "yearly_stats/2026",
      "product_stats/rice_curry",
      "product_daily_stats/2026-07-10_rice_curry",
      "product_stats/faluda",
      "product_daily_stats/2026-07-10_faluda",
      "daily_stats/2026-07-10",
      "weekly_stats/2026-W28",
      "monthly_stats/2026-07",
      "yearly_stats/2026",
    ],
  );
  assert.deepEqual(mutations[0].increments, {
    grossLkr: -1500,
    netSalesLkr: -1500,
    discountLkr: -0,
    deliveryFeeLkr: -0,
    completedOrders: -1,
  });
  assert.deepEqual(mutations[8].increments, {cancelledOrders: 1});
});
