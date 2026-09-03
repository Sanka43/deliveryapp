import assert from "node:assert/strict";
import {describe, it} from "node:test";
import {computeServiceChargeLkr, SERVICE_CHARGE_PERCENT} from "./serviceCharge";

describe("computeServiceChargeLkr", () => {
  it("is zero for zero, negative, or invalid subtotal", () => {
    assert.equal(computeServiceChargeLkr(0), 0);
    assert.equal(computeServiceChargeLkr(-100), 0);
    assert.equal(computeServiceChargeLkr(Number.NaN), 0);
  });

  it("floors 5% of subtotal", () => {
    assert.equal(computeServiceChargeLkr(1000), 50);
    // 5% of 999 = 49.95 -> 49
    assert.equal(computeServiceChargeLkr(999), 49);
    assert.equal(computeServiceChargeLkr(19), 0);
  });

  it("scales with large subtotals", () => {
    assert.equal(computeServiceChargeLkr(1_000_000), 50_000);
  });

  it("uses the documented percent constant", () => {
    assert.equal(SERVICE_CHARGE_PERCENT, 5);
  });
});
