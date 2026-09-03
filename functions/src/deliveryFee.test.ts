import assert from "node:assert/strict";
import {describe, it} from "node:test";
import {
  clampTraveledKmToPlausibleRange,
  FALLBACK_FLAT_FEE_LKR,
  MAX_FEE_LKR,
  MINIMUM_FEE_LKR,
  feeLkrForActualTripKm,
  feeLkrForDistanceKm,
  plausibleTripKmBounds,
  roundTraveledKm,
} from "./deliveryFee";

describe("feeLkrForDistanceKm", () => {
  it("returns minimum within included km", () => {
    assert.equal(feeLkrForDistanceKm(0), MINIMUM_FEE_LKR);
    assert.equal(feeLkrForDistanceKm(1.5), MINIMUM_FEE_LKR);
  });

  it("adds per-km after included", () => {
    // 3.5 km → 120 + ceil(2×42) = 204
    assert.equal(feeLkrForDistanceKm(3.5), 204);
  });

  it("caps at max", () => {
    assert.equal(feeLkrForDistanceKm(100), MAX_FEE_LKR);
  });

  it("falls back for invalid distance", () => {
    assert.equal(feeLkrForDistanceKm(Number.NaN), FALLBACK_FLAT_FEE_LKR);
    assert.equal(feeLkrForDistanceKm(-1), FALLBACK_FLAT_FEE_LKR);
  });
});

describe("feeLkrForActualTripKm", () => {
  it("uses flat fee when km is zero or missing", () => {
    assert.equal(feeLkrForActualTripKm(0), FALLBACK_FLAT_FEE_LKR);
    assert.equal(feeLkrForActualTripKm(-0.1), FALLBACK_FLAT_FEE_LKR);
    assert.equal(feeLkrForActualTripKm(Number.NaN), FALLBACK_FLAT_FEE_LKR);
  });

  it("matches distance curve for positive km", () => {
    assert.equal(feeLkrForActualTripKm(1.5), MINIMUM_FEE_LKR);
    assert.equal(feeLkrForActualTripKm(3.5), 204);
    assert.equal(feeLkrForActualTripKm(100), MAX_FEE_LKR);
  });
});

describe("roundTraveledKm", () => {
  it("rounds to one decimal", () => {
    assert.equal(roundTraveledKm(1.24), 1.2);
    assert.equal(roundTraveledKm(1.25), 1.3);
  });
});

describe("plausibleTripKmBounds", () => {
  it("is unbounded when straight-line distance is unknown", () => {
    const bounds = plausibleTripKmBounds(Number.NaN);
    assert.equal(bounds.min, 0);
    assert.equal(bounds.max, Number.POSITIVE_INFINITY);
  });

  it("scales with straight-line distance", () => {
    // 4 km straight line → min 2, max 4*3.5+3 = 17
    const bounds = plausibleTripKmBounds(4);
    assert.equal(bounds.min, 2);
    assert.equal(bounds.max, 17);
  });
});

describe("clampTraveledKmToPlausibleRange", () => {
  it("passes through a plausible value unflagged", () => {
    const result = clampTraveledKmToPlausibleRange(5, 4);
    assert.equal(result.km, 5);
    assert.equal(result.flagged, false);
  });

  it("clamps and flags an over-reported value", () => {
    // straight line 2 km → max = 2*3.5+3 = 10
    const result = clampTraveledKmToPlausibleRange(40, 2);
    assert.equal(result.km, 10);
    assert.equal(result.flagged, true);
  });

  it("clamps and flags an under-reported value", () => {
    // straight line 10 km → min = 5
    const result = clampTraveledKmToPlausibleRange(1, 10);
    assert.equal(result.km, 5);
    assert.equal(result.flagged, true);
  });
});
