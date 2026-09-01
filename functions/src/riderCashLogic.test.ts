import assert from "node:assert/strict";
import {describe, it} from "node:test";
import {
  applyCashEntry,
  applyCashSettlement,
  cashEntryForOrder,
  cashEntryForTrip,
  evaluateCashHold,
  readLkrConfig,
  DEFAULT_MAX_CASH_IN_HAND_LKR,
} from "./riderCashLogic";

const counters = {
  cashInHandLkr: 6800,
  cashOwedToAdminLkr: 900,
  cashPendingSettlementLkr: 0,
};

describe("evaluateCashHold", () => {
  it("leaves a rider clear while below the limit", () => {
    assert.equal(
      evaluateCashHold({cashInHandLkr: 6999, maxCashInHandLkr: 7000}),
      false,
    );
  });

  it("leaves a rider clear sitting exactly on the limit", () => {
    assert.equal(
      evaluateCashHold({cashInHandLkr: 7000, maxCashInHandLkr: 7000}),
      false,
    );
  });

  it("holds one rupee above the limit", () => {
    assert.equal(
      evaluateCashHold({cashInHandLkr: 7001, maxCashInHandLkr: 7000}),
      true,
    );
  });

  it("never holds when the limit is disabled", () => {
    assert.equal(
      evaluateCashHold({cashInHandLkr: 999999, maxCashInHandLkr: 0}),
      false,
    );
  });
});

describe("readLkrConfig", () => {
  it("keeps a valid whole-rupee value", () => {
    assert.equal(readLkrConfig(7000, DEFAULT_MAX_CASH_IN_HAND_LKR), 7000);
  });

  it("falls back on missing, negative, and absurd values", () => {
    assert.equal(readLkrConfig(undefined, 7000), 7000);
    assert.equal(readLkrConfig(-1, 7000), 7000);
    assert.equal(readLkrConfig(10_000_000, 7000), 7000);
    assert.equal(readLkrConfig("not a number", 7000), 7000);
  });
});

describe("cashEntryForTrip", () => {
  it("records the full fare with the commission owed for a cash ride", () => {
    assert.deepEqual(
      cashEntryForTrip({fareLkr: 450, commissionLkr: 50, paymentMethod: "cash"}),
      {
        cashLkr: 450,
        owedLkr: 50,
        breakdown: {productCashLkr: 0, serviceChargeLkr: 0, rideCommissionLkr: 50},
      },
    );
  });

  it("records nothing for a PayHere ride", () => {
    assert.equal(
      cashEntryForTrip({
        fareLkr: 450,
        commissionLkr: 50,
        paymentMethod: "payhere",
      }),
      null,
    );
  });

  it("caps commission at the fare actually collected", () => {
    assert.deepEqual(
      cashEntryForTrip({fareLkr: 120, commissionLkr: 300, paymentMethod: "cash"}),
      {
        cashLkr: 120,
        owedLkr: 120,
        breakdown: {productCashLkr: 0, serviceChargeLkr: 0, rideCommissionLkr: 120},
      },
    );
  });

  it("ignores a zero-fare trip", () => {
    assert.equal(
      cashEntryForTrip({fareLkr: 0, commissionLkr: 50, paymentMethod: "cash"}),
      null,
    );
  });
});

describe("cashEntryForOrder", () => {
  it("uses amountDueFromCustomer when the delivery flow set it", () => {
    assert.deepEqual(
      cashEntryForOrder({
        amountDueFromCustomerLkr: 2400,
        totalLkr: 2400,
        productCashLkr: 1800,
        serviceChargeLkr: 0,
        paymentStatus: "pending",
      }),
      {
        cashLkr: 2400,
        owedLkr: 1800,
        breakdown: {productCashLkr: 1800, serviceChargeLkr: 0, rideCommissionLkr: 0},
      },
    );
  });

  it("falls back to the order total for a plain COD order", () => {
    assert.deepEqual(
      cashEntryForOrder({
        amountDueFromCustomerLkr: undefined,
        totalLkr: 1500,
        productCashLkr: undefined,
        serviceChargeLkr: undefined,
        paymentStatus: "pending",
      }),
      {
        cashLkr: 1500,
        owedLkr: 0,
        breakdown: {productCashLkr: 0, serviceChargeLkr: 0, rideCommissionLkr: 0},
      },
    );
  });

  it("records nothing once the customer has paid online", () => {
    assert.equal(
      cashEntryForOrder({
        amountDueFromCustomerLkr: 0,
        totalLkr: 1500,
        productCashLkr: 0,
        serviceChargeLkr: 0,
        paymentStatus: "paid",
      }),
      null,
    );
  });

  it("counts service charge as owed alongside the product cost", () => {
    assert.deepEqual(
      cashEntryForOrder({
        amountDueFromCustomerLkr: 2400,
        totalLkr: 2400,
        productCashLkr: 1800,
        serviceChargeLkr: 100,
        paymentStatus: "pending",
      }),
      {
        cashLkr: 2400,
        owedLkr: 1900,
        breakdown: {productCashLkr: 1800, serviceChargeLkr: 100, rideCommissionLkr: 0},
      },
    );
  });

  it("owes just the service charge when the shop was already paid directly", () => {
    assert.deepEqual(
      cashEntryForOrder({
        amountDueFromCustomerLkr: 350,
        totalLkr: 350,
        productCashLkr: 0,
        serviceChargeLkr: 150,
        paymentStatus: "pending",
      }),
      {
        cashLkr: 350,
        owedLkr: 150,
        breakdown: {productCashLkr: 0, serviceChargeLkr: 150, rideCommissionLkr: 0},
      },
    );
  });

  it("clamps owedLkr when product cost + service charge overshoot cash collected", () => {
    // Not reachable via the real order math (amountDueFromCustomer always
    // includes a non-negative deliveryFee on top of these two), but defended
    // anyway. Note breakdown is left unclamped/raw here — its components can
    // sum to more than owedLkr in this edge case; callers that display the
    // breakdown are expected to fall back to just the total when it doesn't
    // reconcile, same convention as the rider app's existing collect-summary.
    assert.deepEqual(
      cashEntryForOrder({
        amountDueFromCustomerLkr: 500,
        totalLkr: 500,
        productCashLkr: 400,
        serviceChargeLkr: 300,
        paymentStatus: "pending",
      }),
      {
        cashLkr: 500,
        owedLkr: 500,
        breakdown: {productCashLkr: 400, serviceChargeLkr: 300, rideCommissionLkr: 0},
      },
    );
  });
});

describe("applyCashEntry", () => {
  it("adds the collected cash and flips the hold once over the limit", () => {
    const result = applyCashEntry({
      counters,
      entry: {
        cashLkr: 450,
        owedLkr: 50,
        breakdown: {productCashLkr: 0, serviceChargeLkr: 0, rideCommissionLkr: 50},
      },
      maxCashInHandLkr: 7000,
    });
    assert.equal(result.counters.cashInHandLkr, 7250);
    assert.equal(result.counters.cashOwedToAdminLkr, 950);
    assert.equal(result.holdActive, true);
  });

  it("stays clear while the running total is under the limit", () => {
    const result = applyCashEntry({
      counters: {
        cashInHandLkr: 0,
        cashOwedToAdminLkr: 0,
        cashPendingSettlementLkr: 0,
      },
      entry: {
        cashLkr: 300,
        owedLkr: 50,
        breakdown: {productCashLkr: 50, serviceChargeLkr: 0, rideCommissionLkr: 0},
      },
      maxCashInHandLkr: 7000,
    });
    assert.equal(result.counters.cashInHandLkr, 300);
    assert.equal(result.holdActive, false);
  });
});

describe("applyCashSettlement", () => {
  const held = {
    cashInHandLkr: 7250,
    cashOwedToAdminLkr: 950,
    cashPendingSettlementLkr: 950,
  };

  it("clears the covered cash and lifts the hold on confirm", () => {
    const result = applyCashSettlement({
      action: "confirmed",
      status: "requested",
      amountLkr: 950,
      cashCoveredLkr: 7250,
      counters: held,
      maxCashInHandLkr: 7000,
    });
    assert.equal(result.alreadyDone, false);
    assert.equal(result.nextStatus, "confirmed");
    assert.equal(result.counters.cashInHandLkr, 0);
    assert.equal(result.counters.cashOwedToAdminLkr, 0);
    assert.equal(result.counters.cashPendingSettlementLkr, 0);
    assert.equal(result.holdActive, false);
  });

  it("leaves cash collected after the request still outstanding", () => {
    const result = applyCashSettlement({
      action: "confirmed",
      status: "requested",
      amountLkr: 950,
      cashCoveredLkr: 7250,
      // A ride completed between request and confirm.
      counters: {
        cashInHandLkr: 7650,
        cashOwedToAdminLkr: 1000,
        cashPendingSettlementLkr: 950,
      },
      maxCashInHandLkr: 7000,
    });
    assert.equal(result.counters.cashInHandLkr, 400);
    assert.equal(result.counters.cashOwedToAdminLkr, 50);
    assert.equal(result.holdActive, false);
  });

  it("only releases the pending lock on reject", () => {
    const result = applyCashSettlement({
      action: "rejected",
      status: "requested",
      amountLkr: 950,
      cashCoveredLkr: 7250,
      counters: held,
      maxCashInHandLkr: 7000,
    });
    assert.equal(result.nextStatus, "rejected");
    assert.equal(result.counters.cashInHandLkr, 7250);
    assert.equal(result.counters.cashPendingSettlementLkr, 0);
    assert.equal(result.holdActive, true);
  });

  it("is idempotent for a replayed terminal status", () => {
    const settled = {
      cashInHandLkr: 0,
      cashOwedToAdminLkr: 0,
      cashPendingSettlementLkr: 0,
    };
    const result = applyCashSettlement({
      action: "confirmed",
      status: "confirmed",
      amountLkr: 950,
      cashCoveredLkr: 7250,
      counters: settled,
      maxCashInHandLkr: 7000,
    });
    assert.equal(result.alreadyDone, true);
    assert.deepEqual(result.counters, settled);
  });

  it("refuses to settle a rejected request", () => {
    assert.throws(
      () =>
        applyCashSettlement({
          action: "confirmed",
          status: "rejected",
          amountLkr: 950,
          cashCoveredLkr: 7250,
          counters: held,
          maxCashInHandLkr: 7000,
        }),
      /Cannot mark confirmed from "rejected"/,
    );
  });

  it("refuses a settlement that covers no cash", () => {
    assert.throws(
      () =>
        applyCashSettlement({
          action: "confirmed",
          status: "requested",
          amountLkr: 0,
          cashCoveredLkr: 0,
          counters: held,
          maxCashInHandLkr: 7000,
        }),
      /Invalid settlement amount/,
    );
  });
});
