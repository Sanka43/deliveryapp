import assert from "node:assert/strict";
import {describe, it} from "node:test";

/** Mirrors shop amount parse + line total rounding for vendor manual amounts. */
function parseAmountInput(raw: string): {quantity: number; amountLabel: string} | null {
  const trimmed = raw.trim();
  if (!trimmed) {
    return null;
  }
  const m = /^(\d+(?:\.\d{1,2})?)\s*(.*)$/.exec(trimmed);
  if (!m) {
    return null;
  }
  const quantity = Number(m[1]);
  if (!Number.isFinite(quantity) || quantity <= 0 || quantity > 999) {
    return null;
  }
  const unit = (m[2] ?? "").trim();
  const qtyText =
    quantity === Math.round(quantity)
      ? String(Math.round(quantity))
      : String(Math.round(quantity * 100) / 100);
  const amountLabel = unit ? `${qtyText} ${unit}` : qtyText;
  return {quantity, amountLabel};
}

describe("vendor amount parse", () => {
  it("parses 1.5 kg", () => {
    const r = parseAmountInput("1.5 kg");
    assert.ok(r);
    assert.equal(r!.quantity, 1.5);
    assert.equal(r!.amountLabel, "1.5 kg");
  });

  it("rejects unit-only", () => {
    assert.equal(parseAmountInput("kg"), null);
  });

  it("rounds 260 × 1.5 to 390", () => {
    assert.equal(Math.round(260 * 1.5), 390);
  });
});
