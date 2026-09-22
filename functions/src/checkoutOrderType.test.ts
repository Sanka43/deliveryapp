import assert from "node:assert/strict";
import {describe, it} from "node:test";
import {HttpsError} from "firebase-functions/v2/https";
import {
  MAX_SCHEDULE_AHEAD_MS,
  resolveCheckoutOrderType,
  vendorAcceptsOrderType,
} from "./checkoutOrderType";

const NOW = Date.parse("2026-01-01T12:00:00.000Z");

describe("resolveCheckoutOrderType", () => {
  it("defaults to standard with no scheduledFor", () => {
    assert.deepEqual(resolveCheckoutOrderType(undefined, false, undefined, NOW), {
      orderType: "standard",
      scheduledFor: null,
    });
  });

  it("treats an unrecognized orderType as standard", () => {
    assert.deepEqual(resolveCheckoutOrderType("bogus", false, undefined, NOW), {
      orderType: "standard",
      scheduledFor: null,
    });
  });

  it("allows emergency for delivery", () => {
    assert.deepEqual(resolveCheckoutOrderType("emergency", false, undefined, NOW), {
      orderType: "emergency",
      scheduledFor: null,
    });
  });

  it("rejects emergency for self-pickup", () => {
    assert.throws(
      () => resolveCheckoutOrderType("emergency", true, undefined, NOW),
      (err: unknown) =>
        err instanceof HttpsError && err.code === "failed-precondition",
    );
  });

  it("resolves a valid future scheduled time within the window", () => {
    const target = new Date(NOW + 60 * 60 * 1000).toISOString();
    const result = resolveCheckoutOrderType("schedule", false, target, NOW);
    assert.equal(result.orderType, "schedule");
    assert.equal(result.scheduledFor?.getTime(), Date.parse(target));
  });

  it("accepts an explicit UTC offset and keeps the same instant", () => {
    // 8:45 PM in Sri Lanka (+05:30) is 15:15 UTC.
    const result = resolveCheckoutOrderType(
      "schedule",
      false,
      "2026-01-01T20:45:00.000+05:30",
      NOW,
    );
    assert.equal(
      result.scheduledFor?.toISOString(),
      "2026-01-01T15:15:00.000Z",
    );
  });

  it("rejects a scheduledFor with no timezone (ambiguous wall-clock time)", () => {
    const naive = new Date(NOW + 60 * 60 * 1000).toISOString().replace("Z", "");
    assert.throws(
      () => resolveCheckoutOrderType("schedule", false, naive, NOW),
      (err: unknown) =>
        err instanceof HttpsError && err.code === "invalid-argument",
    );
  });

  it("rejects a missing scheduledFor when type is schedule", () => {
    assert.throws(
      () => resolveCheckoutOrderType("schedule", false, undefined, NOW),
      (err: unknown) =>
        err instanceof HttpsError && err.code === "invalid-argument",
    );
  });

  it("rejects an unparseable scheduledFor", () => {
    assert.throws(
      () => resolveCheckoutOrderType("schedule", false, "not-a-date", NOW),
      (err: unknown) =>
        err instanceof HttpsError && err.code === "invalid-argument",
    );
  });

  it("rejects a scheduledFor in the past", () => {
    const target = new Date(NOW - 1000).toISOString();
    assert.throws(
      () => resolveCheckoutOrderType("schedule", false, target, NOW),
      (err: unknown) =>
        err instanceof HttpsError && err.code === "failed-precondition",
    );
  });

  it("rejects a scheduledFor beyond the booking window", () => {
    const target = new Date(NOW + MAX_SCHEDULE_AHEAD_MS + 60_000).toISOString();
    assert.throws(
      () => resolveCheckoutOrderType("schedule", false, target, NOW),
      (err: unknown) =>
        err instanceof HttpsError && err.code === "failed-precondition",
    );
  });

  it("accepts a scheduledFor right at the edge of the booking window", () => {
    const target = new Date(NOW + MAX_SCHEDULE_AHEAD_MS - 1000).toISOString();
    const result = resolveCheckoutOrderType("schedule", false, target, NOW);
    assert.equal(result.orderType, "schedule");
  });
});

describe("vendorAcceptsOrderType", () => {
  it("accepts any order type while the shop is open", () => {
    for (const t of ["standard", "emergency", "schedule"] as const) {
      assert.equal(vendorAcceptsOrderType({active: true}, t), true);
    }
  });

  it("lets an approved but closed shop take a Schedule order only", () => {
    const closed = {active: false, approvalStatus: "approved"};
    assert.equal(vendorAcceptsOrderType(closed, "schedule"), true);
    assert.equal(vendorAcceptsOrderType(closed, "standard"), false);
    assert.equal(vendorAcceptsOrderType(closed, "emergency"), false);
  });

  it("never accepts from a pending, rejected, or unapproved inactive shop", () => {
    for (const approvalStatus of ["pending", "rejected", undefined]) {
      assert.equal(
        vendorAcceptsOrderType({active: false, approvalStatus}, "schedule"),
        false,
      );
    }
  });
});
