import assert from "node:assert/strict";
import test from "node:test";
import {
  mutationsForMonthlyInvoiceUpdated,
  mutationsForOrderUpdated,
  mutationsForPayoutUpdated,
  mutationsForTripUpdated,
  mutationsForWithdrawalUpdated,
  nestDottedFields,
} from "./platformCashFlowLogic";

test("nestDottedFields nests category.leaf keys and merges siblings", () => {
  assert.deepEqual(
    nestDottedFields({
      "income.orderCommissionLkr": 50,
      "income.ipgFeeLkr": 10,
      "outgoing.refundsPaidLkr": 200,
      "plainKey": "unchanged",
    }),
    {
      income: {orderCommissionLkr: 50, ipgFeeLkr: 10},
      outgoing: {refundsPaidLkr: 200},
      plainKey: "unchanged",
    },
  );
});

const fixedDate = new Date("2026-07-10T10:15:00.000Z");
const deliveredAt = {toDate: () => new Date("2026-07-11T09:00:00.000Z")};

function order(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    status: "placed",
    paymentStatus: "paid",
    productCashStatus: "",
    orderCommissionLkr: 120,
    ipgFeeLkr: 30,
    discount: 50,
    total: 1500,
    ...overrides,
  };
}

test("order placed to delivered counts commission, IPG fee, and discount cost once", () => {
  const before = order();
  const after = order({status: "delivered", deliveredAt});

  const mutations = mutationsForOrderUpdated(before, after, fixedDate);

  assert.deepEqual(mutations, [
    {docId: "2026-07-11", increments: {"income.orderCommissionLkr": 120}},
    {docId: "2026-07-11", increments: {"income.ipgFeeLkr": 30}},
    {docId: "2026-07-11", increments: {"discountCost.couponsAndReferralsLkr": 50}},
  ]);
});

test("delivered to delivered update does not double-count", () => {
  const before = order({status: "delivered", deliveredAt});
  const after = order({status: "delivered", deliveredAt, total: 1800});

  assert.deepEqual(mutationsForOrderUpdated(before, after, fixedDate), []);
});

test("delivered order reverted (e.g. status correction) reverses the income", () => {
  const before = order({status: "delivered", deliveredAt});
  const after = order({status: "placed", deliveredAt});

  const mutations = mutationsForOrderUpdated(before, after, fixedDate);

  assert.deepEqual(mutations, [
    {docId: "2026-07-11", increments: {"income.orderCommissionLkr": -120}},
    {docId: "2026-07-11", increments: {"income.ipgFeeLkr": -30}},
    {docId: "2026-07-11", increments: {"discountCost.couponsAndReferralsLkr": -50}},
  ]);
});

test("order refunded counts the refunded total as an outgoing", () => {
  const before = order({paymentStatus: "paid"});
  const after = order({
    paymentStatus: "refunded",
    refundedAt: {toDate: () => new Date("2026-07-12T00:00:00.000Z")},
    total: 1500,
  });

  const mutations = mutationsForOrderUpdated(before, after, fixedDate);

  assert.deepEqual(mutations, [
    {docId: "2026-07-12", increments: {"outgoing.refundsPaidLkr": 1500}},
  ]);
});

test("COD product cash settled to shop counts as an outgoing", () => {
  const before = order({productCashStatus: "remitted_to_admin"});
  const after = order({
    productCashStatus: "settled_to_shop",
    productCashSettledAt: {toDate: () => new Date("2026-07-13T00:00:00.000Z")},
    productCashLkr: 900,
  });

  const mutations = mutationsForOrderUpdated(before, after, fixedDate);

  assert.deepEqual(mutations, [
    {docId: "2026-07-13", increments: {"outgoing.codSettledToShopLkr": 900}},
  ]);
});

test("re-settling (already settled_to_shop) does not double-count", () => {
  const before = order({productCashStatus: "settled_to_shop", productCashLkr: 900});
  const after = order({productCashStatus: "settled_to_shop", productCashLkr: 900});

  assert.deepEqual(mutationsForOrderUpdated(before, after, fixedDate), []);
});

test("trip completed+paid counts ride commission capped at the fare", () => {
  const before = {status: "completed", paymentStatus: "pending"};
  const after = {
    status: "completed",
    paymentStatus: "paid",
    estimatedFareLkr: 350,
    createdAt: {toDate: () => new Date("2026-07-14T00:00:00.000Z")},
  };

  const mutations = mutationsForTripUpdated(before, after, 400, fixedDate);

  assert.deepEqual(mutations, [
    {docId: "2026-07-14", increments: {"income.rideCommissionLkr": 350}},
  ]);
});

test("trip already completed+paid does not fire again", () => {
  const before = {status: "completed", paymentStatus: "paid", estimatedFareLkr: 350};
  const after = {status: "completed", paymentStatus: "paid", estimatedFareLkr: 350};

  assert.deepEqual(mutationsForTripUpdated(before, after, 400, fixedDate), []);
});

test("withdrawal marked paid counts the amount as an outgoing", () => {
  const before = {status: "pending", amountLkr: 5000};
  const after = {
    status: "paid",
    amountLkr: 5000,
    processedAt: {toDate: () => new Date("2026-07-15T00:00:00.000Z")},
  };

  assert.deepEqual(mutationsForWithdrawalUpdated(before, after, fixedDate), [
    {docId: "2026-07-15", increments: {"outgoing.riderWithdrawalsPaidLkr": 5000}},
  ]);
});

test("withdrawal already paid does not fire again", () => {
  const before = {status: "paid", amountLkr: 5000};
  const after = {status: "paid", amountLkr: 5000};

  assert.deepEqual(mutationsForWithdrawalUpdated(before, after, fixedDate), []);
});

test("vendor payout marked paid counts the amount as an outgoing", () => {
  const before = {status: "pending", amountLkr: 12000};
  const after = {
    status: "paid",
    amountLkr: 12000,
    processedAt: {toDate: () => new Date("2026-07-16T00:00:00.000Z")},
  };

  assert.deepEqual(mutationsForPayoutUpdated(before, after, fixedDate), [
    {docId: "2026-07-16", increments: {"outgoing.vendorPayoutsPaidLkr": 12000}},
  ]);
});

test("monthly invoice marked paid counts the fee as income", () => {
  const before = {status: "invoiced", feeLkr: 3000};
  const after = {
    status: "paid",
    feeLkr: 3000,
    paidAt: {toDate: () => new Date("2026-07-17T00:00:00.000Z")},
  };

  assert.deepEqual(mutationsForMonthlyInvoiceUpdated(before, after, fixedDate), [
    {docId: "2026-07-17", increments: {"income.monthlyInvoiceLkr": 3000}},
  ]);
});
