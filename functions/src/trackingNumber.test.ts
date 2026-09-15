import assert from "node:assert/strict";
import {describe, it} from "node:test";
import {
  formatTrackingNumber,
  trackingDateKey,
  TRACKING_SEQUENCE_SHARD_RANGE,
  TRACKING_SEQUENCE_SHARDS,
} from "./trackingNumber";

describe("trackingDateKey", () => {
  it("formats as YYMMDD in Colombo wall-clock time", () => {
    // 2025-09-15T10:00:00Z is 15:30 in Colombo — same calendar day.
    assert.equal(
      trackingDateKey(new Date("2025-09-15T10:00:00Z")),
      "250915",
    );
  });

  it("rolls over at Colombo midnight, not UTC midnight", () => {
    // 2025-09-15T19:00:00Z is 2025-09-16T00:30 in Colombo (UTC+5:30).
    assert.equal(
      trackingDateKey(new Date("2025-09-15T19:00:00Z")),
      "250916",
    );
    // 2025-09-14T17:59:00Z is 2025-09-14T23:29 in Colombo — still the 14th.
    assert.equal(
      trackingDateKey(new Date("2025-09-14T17:59:00Z")),
      "250914",
    );
  });
});

describe("formatTrackingNumber", () => {
  it("builds prefix + date + 4-digit zero-padded shard-partitioned sequence", () => {
    assert.equal(formatTrackingNumber("MND", "250915", 0, 1), "MND2509150000");
    assert.equal(formatTrackingNumber("Trip", "250915", 0, 1), "Trip2509150000");
  });

  it("partitions the 0000-9999 space evenly across shards with no overlap", () => {
    assert.equal(TRACKING_SEQUENCE_SHARD_RANGE * TRACKING_SEQUENCE_SHARDS, 10000);
    const first = formatTrackingNumber("MND", "250915", 1, 1);
    const last = formatTrackingNumber(
      "MND",
      "250915",
      1,
      TRACKING_SEQUENCE_SHARD_RANGE,
    );
    assert.equal(first, "MND2509150200");
    assert.equal(last, "MND2509150399");
    // Next shard picks up immediately after the previous shard's range ends.
    assert.equal(formatTrackingNumber("MND", "250915", 2, 1), "MND2509150400");
  });
});
