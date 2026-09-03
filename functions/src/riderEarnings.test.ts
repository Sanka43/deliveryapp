import assert from "node:assert/strict";
import {describe, it} from "node:test";
import {applyWithdrawalSettlement} from "./riderEarnings";

const wallet = {
  balanceLkr: 2000,
  pendingWithdrawalLkr: 1500,
  lifetimeEarnedLkr: 8000,
  lifetimeWithdrawnLkr: 4500,
};

describe("applyWithdrawalSettlement", () => {
  it("marks paid by moving pending into lifetime withdrawn", () => {
    const result = applyWithdrawalSettlement({
      action: "paid",
      status: "pending",
      amountLkr: 1500,
      wallet,
    });
    assert.equal(result.alreadyDone, false);
    assert.equal(result.nextStatus, "paid");
    assert.equal(result.ledgerStatus, "completed");
    assert.equal(result.wallet.balanceLkr, 2000);
    assert.equal(result.wallet.pendingWithdrawalLkr, 0);
    assert.equal(result.wallet.lifetimeWithdrawnLkr, 6000);
  });

  it("rejects by restoring available balance", () => {
    const result = applyWithdrawalSettlement({
      action: "rejected",
      status: "pending",
      amountLkr: 1500,
      wallet,
    });
    assert.equal(result.nextStatus, "rejected");
    assert.equal(result.ledgerStatus, "cancelled");
    assert.equal(result.wallet.balanceLkr, 3500);
    assert.equal(result.wallet.pendingWithdrawalLkr, 0);
    assert.equal(result.wallet.lifetimeWithdrawnLkr, 4500);
  });

  it("is idempotent for the same terminal status", () => {
    const paid = applyWithdrawalSettlement({
      action: "paid",
      status: "paid",
      amountLkr: 1500,
      wallet,
    });
    assert.equal(paid.alreadyDone, true);
    assert.deepEqual(paid.wallet, wallet);

    const rejected = applyWithdrawalSettlement({
      action: "rejected",
      status: "rejected",
      amountLkr: 1500,
      wallet,
    });
    assert.equal(rejected.alreadyDone, true);
    assert.deepEqual(rejected.wallet, wallet);
  });

  it("rejects illegal transitions", () => {
    assert.throws(
      () =>
        applyWithdrawalSettlement({
          action: "paid",
          status: "rejected",
          amountLkr: 500,
          wallet,
        }),
      /Cannot mark paid/,
    );
  });
});
