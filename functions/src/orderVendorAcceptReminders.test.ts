import assert from "node:assert/strict";
import {describe, it} from "node:test";
import {
  AUTO_CANCEL_MS,
  REMINDER_1_MS,
  REMINDER_2_MS,
  createdAtMillis,
  dueVendorAcceptAction,
  reminderStage,
} from "./orderVendorAcceptReminders";

const createdAt = Date.parse("2026-08-14T07:00:00.000Z");

describe("dueVendorAcceptAction", () => {
  it("sends reminder 1 at +2 min when still placed", () => {
    assert.equal(
      dueVendorAcceptAction({
        status: "placed",
        createdAtMs: createdAt,
        stage: 0,
        nowMs: createdAt + REMINDER_1_MS,
      }),
      "reminder_1",
    );
  });

  it("sends reminder 2 at +5 min after first reminder", () => {
    assert.equal(
      dueVendorAcceptAction({
        status: "placed",
        createdAtMs: createdAt,
        stage: 1,
        nowMs: createdAt + REMINDER_2_MS,
      }),
      "reminder_2",
    );
  });

  it("cancels at +7 min after both reminders", () => {
    assert.equal(
      dueVendorAcceptAction({
        status: "placed",
        createdAtMs: createdAt,
        stage: 2,
        nowMs: createdAt + AUTO_CANCEL_MS,
      }),
      "cancel",
    );
  });

  it("skips vendor_manual and non-placed orders", () => {
    assert.equal(
      dueVendorAcceptAction({
        status: "placed",
        orderSource: "vendor_manual",
        createdAtMs: createdAt,
        stage: 0,
        nowMs: createdAt + AUTO_CANCEL_MS,
      }),
      "none",
    );
    assert.equal(
      dueVendorAcceptAction({
        status: "confirmed",
        createdAtMs: createdAt,
        stage: 0,
        nowMs: createdAt + AUTO_CANCEL_MS,
      }),
      "none",
    );
  });

  it("does not re-send a completed reminder stage", () => {
    assert.equal(
      dueVendorAcceptAction({
        status: "placed",
        createdAtMs: createdAt,
        stage: 1,
        nowMs: createdAt + REMINDER_1_MS + 30_000,
      }),
      "none",
    );
  });

  it("jumps to cancel when sweep is late", () => {
    assert.equal(
      dueVendorAcceptAction({
        status: "placed",
        createdAtMs: createdAt,
        stage: 0,
        nowMs: createdAt + AUTO_CANCEL_MS,
      }),
      "cancel",
    );
  });
});

describe("reminder helpers", () => {
  it("reminderStage floors invalid values to 0", () => {
    assert.equal(reminderStage(undefined), 0);
    assert.equal(reminderStage("2"), 2);
    assert.equal(reminderStage(-1), 0);
  });

  it("createdAtMillis reads Date and number", () => {
    const d = new Date(createdAt);
    assert.equal(createdAtMillis(d), createdAt);
    assert.equal(createdAtMillis(createdAt), createdAt);
    assert.equal(createdAtMillis(null), null);
  });
});
