import assert from "node:assert/strict";
import {describe, it} from "node:test";
import {
  COLOMBO_OFFSET_MS,
  colomboDateTimeToUtc,
  desiredActive,
  nextScheduleBoundary,
  parseOpeningHours,
  syncVendorOpenStatus,
  toColomboParts,
} from "./vendorOpenHours";

const weekdayHours = {
  defaultOpen: "09:00",
  defaultClose: "21:00",
  closedSunday: true,
};

const overnightHours = {
  defaultOpen: "22:00",
  defaultClose: "02:00",
  closedSunday: true,
};

/** Build a UTC Date that is the given Colombo wall-clock time. */
function atColombo(
  year: number,
  month: number,
  day: number,
  hour: number,
  minute: number,
): Date {
  return colomboDateTimeToUtc(year, month, day, hour, minute);
}

describe("vendorOpenHours", () => {
  it("toColomboParts uses +05:30 offset", () => {
    // 2026-07-31 04:30 UTC = 10:00 Colombo
    const utc = new Date(Date.UTC(2026, 6, 31, 4, 30, 0));
    const parts = toColomboParts(utc);
    assert.equal(parts.hour, 10);
    assert.equal(parts.minute, 0);
    assert.equal(parts.day, 31);
    assert.equal(COLOMBO_OFFSET_MS, 5.5 * 60 * 60 * 1000);
  });

  it("desiredActive is true inside weekday window", () => {
    // Friday 2026-07-31 10:00 Colombo
    const now = atColombo(2026, 6, 31, 10, 0);
    assert.equal(desiredActive(now, weekdayHours), true);
  });

  it("desiredActive is false before open and after close", () => {
    assert.equal(
      desiredActive(atColombo(2026, 6, 31, 8, 59), weekdayHours),
      false,
    );
    assert.equal(
      desiredActive(atColombo(2026, 6, 31, 21, 0), weekdayHours),
      false,
    );
  });

  it("desiredActive is false all Sunday when closedSunday", () => {
    // Sunday 2026-08-02
    assert.equal(
      desiredActive(atColombo(2026, 7, 2, 12, 0), weekdayHours),
      false,
    );
  });

  it("desiredActive handles overnight windows", () => {
    // Saturday 23:00 open
    assert.equal(
      desiredActive(atColombo(2026, 7, 1, 23, 0), overnightHours),
      true,
    );
    // Sunday 01:00 — closedSunday forces closed even inside overnight close
    assert.equal(
      desiredActive(atColombo(2026, 7, 2, 1, 0), overnightHours),
      false,
    );
    // Monday 01:00 still in overnight from Sunday open? Sunday closed so no
    // Sunday open; Monday 01:00 is before Monday open → from Sunday 22 skipped.
    // Friday 23 → Saturday 02:
    assert.equal(
      desiredActive(atColombo(2026, 6, 31, 23, 30), overnightHours),
      true,
    );
    assert.equal(
      desiredActive(atColombo(2026, 7, 1, 1, 30), overnightHours),
      true,
    );
    assert.equal(
      desiredActive(atColombo(2026, 7, 1, 3, 0), overnightHours),
      false,
    );
  });

  it("nextScheduleBoundary returns next close while open", () => {
    const now = atColombo(2026, 6, 31, 10, 0);
    const next = nextScheduleBoundary(now, weekdayHours);
    assert.equal(next.getTime(), atColombo(2026, 6, 31, 21, 0).getTime());
  });

  it("nextScheduleBoundary skips closed Sunday to Monday open", () => {
    const now = atColombo(2026, 7, 2, 12, 0); // Sunday noon
    const next = nextScheduleBoundary(now, weekdayHours);
    assert.equal(next.getTime(), atColombo(2026, 7, 3, 9, 0).getTime());
  });

  it("nextScheduleBoundary ends overnight at Sunday midnight when closedSunday", () => {
    const now = atColombo(2026, 7, 1, 23, 0); // Sat 23:00
    const next = nextScheduleBoundary(now, overnightHours);
    assert.equal(next.getTime(), atColombo(2026, 7, 2, 0, 0).getTime());
  });

  it("syncVendorOpenStatus forces closed when pending", () => {
    const result = syncVendorOpenStatus(
      {
        approvalStatus: "pending",
        active: true,
        openingHours: weekdayHours,
        openOverrideUntil: atColombo(2026, 6, 31, 21, 0),
      },
      atColombo(2026, 6, 31, 10, 0),
    );
    assert.equal(result.active, false);
    assert.equal(result.openOverrideUntil, null);
    assert.equal(result.changed, true);
  });

  it("syncVendorOpenStatus holds manual override until boundary", () => {
    const overrideUntil = atColombo(2026, 6, 31, 21, 0);
    const result = syncVendorOpenStatus(
      {
        approvalStatus: "approved",
        active: false,
        openingHours: weekdayHours,
        openOverrideUntil: overrideUntil,
      },
      atColombo(2026, 6, 31, 10, 0),
    );
    assert.equal(result.skippedDueToOverride, true);
    assert.equal(result.changed, false);
    assert.equal(result.active, false);
  });

  it("syncVendorOpenStatus clears expired override and applies schedule", () => {
    const result = syncVendorOpenStatus(
      {
        approvalStatus: "approved",
        active: false,
        openingHours: weekdayHours,
        openOverrideUntil: atColombo(2026, 6, 31, 9, 0),
      },
      atColombo(2026, 6, 31, 10, 0),
    );
    assert.equal(result.skippedDueToOverride, false);
    assert.equal(result.active, true);
    assert.equal(result.openOverrideUntil, null);
    assert.equal(result.changed, true);
  });

  it("parseOpeningHours falls back to 09:00–21:00", () => {
    const h = parseOpeningHours({});
    assert.equal(h.defaultOpen, "09:00");
    assert.equal(h.defaultClose, "21:00");
    assert.equal(h.closedSunday, false);
  });
});
