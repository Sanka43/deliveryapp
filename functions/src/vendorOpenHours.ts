import {
  FieldValue,
  getFirestore,
  type DocumentData,
  type Query,
  type QueryDocumentSnapshot,
} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {onSchedule} from "firebase-functions/v2/scheduler";

/** Sri Lanka — no DST. */
export const COLOMBO_OFFSET_MS = (5 * 60 + 30) * 60 * 1000;

export interface OpeningHours {
  defaultOpen: string;
  defaultClose: string;
  closedSunday: boolean;
}

export interface VendorOpenDoc {
  approvalStatus?: string | null;
  active?: boolean | null;
  openingHours?: unknown;
  openOverrideUntil?: Date | null;
}

export interface SyncVendorOpenResult {
  active: boolean;
  /** `null` means clear the Firestore field. */
  openOverrideUntil: Date | null;
  changed: boolean;
  skippedDueToOverride: boolean;
}

export interface ColomboParts {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  second: number;
  dayOfWeek: number;
}

const DEFAULT_OPEN = "09:00";
const DEFAULT_CLOSE = "21:00";

export function toColomboParts(utc: Date): ColomboParts {
  const local = new Date(utc.getTime() + COLOMBO_OFFSET_MS);
  return {
    year: local.getUTCFullYear(),
    month: local.getUTCMonth(),
    day: local.getUTCDate(),
    hour: local.getUTCHours(),
    minute: local.getUTCMinutes(),
    second: local.getUTCSeconds(),
    dayOfWeek: local.getUTCDay(),
  };
}

export function colomboDateTimeToUtc(
  year: number,
  month: number,
  day: number,
  hour: number,
  minute: number,
): Date {
  return new Date(
    Date.UTC(year, month, day, hour, minute, 0, 0) - COLOMBO_OFFSET_MS,
  );
}

export function parseHm(raw: string | null | undefined): {
  hour: number;
  minute: number;
} | null {
  if (typeof raw !== "string") {
    return null;
  }
  const m = /^(\d{1,2}):(\d{2})$/.exec(raw.trim());
  if (!m) {
    return null;
  }
  const hour = Number(m[1]);
  const minute = Number(m[2]);
  if (
    !Number.isInteger(hour) ||
    !Number.isInteger(minute) ||
    hour < 0 ||
    hour > 23 ||
    minute < 0 ||
    minute > 59
  ) {
    return null;
  }
  return {hour, minute};
}

export function parseOpeningHours(raw: unknown): OpeningHours {
  const map =
    raw && typeof raw === "object" ? (raw as Record<string, unknown>) : {};
  const open =
    parseHm(typeof map.defaultOpen === "string" ? map.defaultOpen : null) ?
      String(map.defaultOpen).trim() :
      DEFAULT_OPEN;
  const close =
    parseHm(typeof map.defaultClose === "string" ? map.defaultClose : null) ?
      String(map.defaultClose).trim() :
      DEFAULT_CLOSE;
  return {
    defaultOpen: open,
    defaultClose: close,
    closedSunday: map.closedSunday === true,
  };
}

function minutesOfDay(hour: number, minute: number): number {
  return hour * 60 + minute;
}

function addCalendarDays(parts: ColomboParts, days: number): ColomboParts {
  const noonUtc = colomboDateTimeToUtc(
    parts.year,
    parts.month,
    parts.day,
    12,
    0,
  );
  const shifted = new Date(noonUtc.getTime() + days * 24 * 60 * 60 * 1000);
  return toColomboParts(shifted);
}

/**
 * Whether the shop should accept orders at `now` based on opening hours
 * (Asia/Colombo). Closed all day Sunday when `closedSunday` is set.
 */
export function desiredActive(now: Date, hours: OpeningHours): boolean {
  const parts = toColomboParts(now);
  if (hours.closedSunday && parts.dayOfWeek === 0) {
    return false;
  }
  const open = parseHm(hours.defaultOpen) ?? {hour: 9, minute: 0};
  const close = parseHm(hours.defaultClose) ?? {hour: 21, minute: 0};
  const nowMin = minutesOfDay(parts.hour, parts.minute);
  const openMin = minutesOfDay(open.hour, open.minute);
  const closeMin = minutesOfDay(close.hour, close.minute);

  if (openMin < closeMin) {
    return nowMin >= openMin && nowMin < closeMin;
  }
  // Overnight window, e.g. 22:00 → 02:00.
  return nowMin >= openMin || nowMin < closeMin;
}

/**
 * Next open or close instant after `now` (Asia/Colombo).
 */
export function nextScheduleBoundary(now: Date, hours: OpeningHours): Date {
  const open = parseHm(hours.defaultOpen) ?? {hour: 9, minute: 0};
  const close = parseHm(hours.defaultClose) ?? {hour: 21, minute: 0};
  const openMin = minutesOfDay(open.hour, open.minute);
  const closeMin = minutesOfDay(close.hour, close.minute);
  const overnight = openMin >= closeMin;
  const nowMs = now.getTime();
  const candidates: Date[] = [];
  const start = toColomboParts(now);

  for (let offset = 0; offset <= 8; offset++) {
    const d = addCalendarDays(start, offset);
    const closedDay = hours.closedSunday && d.dayOfWeek === 0;

    if (!overnight) {
      if (closedDay) {
        continue;
      }
      candidates.push(
        colomboDateTimeToUtc(d.year, d.month, d.day, open.hour, open.minute),
      );
      candidates.push(
        colomboDateTimeToUtc(d.year, d.month, d.day, close.hour, close.minute),
      );
      continue;
    }

    if (closedDay) {
      continue;
    }
    candidates.push(
      colomboDateTimeToUtc(d.year, d.month, d.day, open.hour, open.minute),
    );
    const next = addCalendarDays(d, 1);
    if (hours.closedSunday && next.dayOfWeek === 0) {
      candidates.push(
        colomboDateTimeToUtc(next.year, next.month, next.day, 0, 0),
      );
    } else {
      candidates.push(
        colomboDateTimeToUtc(
          next.year,
          next.month,
          next.day,
          close.hour,
          close.minute,
        ),
      );
    }
  }

  candidates.sort((a, b) => a.getTime() - b.getTime());
  for (const c of candidates) {
    if (c.getTime() > nowMs) {
      return c;
    }
  }
  return new Date(nowMs + 24 * 60 * 60 * 1000);
}

export function isApprovalBlocking(approvalStatus: string | null | undefined): boolean {
  return approvalStatus === "pending" || approvalStatus === "rejected";
}

export function syncVendorOpenStatus(
  data: VendorOpenDoc,
  now: Date,
): SyncVendorOpenResult {
  if (isApprovalBlocking(data.approvalStatus ?? null)) {
    const changed =
      data.active !== false || data.openOverrideUntil != null;
    return {
      active: false,
      openOverrideUntil: null,
      changed,
      skippedDueToOverride: false,
    };
  }

  const overrideUntil = data.openOverrideUntil ?? null;
  if (overrideUntil != null && now.getTime() < overrideUntil.getTime()) {
    return {
      active: data.active === true,
      openOverrideUntil: overrideUntil,
      changed: false,
      skippedDueToOverride: true,
    };
  }

  const hours = parseOpeningHours(data.openingHours);
  const desired = desiredActive(now, hours);
  const hadOverride = overrideUntil != null;
  const changed = data.active !== desired || hadOverride;
  return {
    active: desired,
    openOverrideUntil: null,
    changed,
    skippedDueToOverride: false,
  };
}

export function asDate(value: unknown): Date | null {
  if (value == null) {
    return null;
  }
  if (value instanceof Date) {
    return Number.isNaN(value.getTime()) ? null : value;
  }
  if (typeof value === "object" && value !== null && "toDate" in value) {
    const fn = (value as {toDate: () => Date}).toDate;
    if (typeof fn === "function") {
      const d = fn.call(value);
      return d instanceof Date && !Number.isNaN(d.getTime()) ? d : null;
    }
  }
  if (
    typeof value === "object" &&
    value !== null &&
    "seconds" in value &&
    typeof (value as {seconds: unknown}).seconds === "number"
  ) {
    const stamped = value as {
      seconds: number;
      nanoseconds?: unknown;
      _nanoseconds?: unknown;
    };
    const seconds = stamped.seconds;
    const nanos =
      typeof stamped._nanoseconds === "number" ?
        stamped._nanoseconds :
        typeof stamped.nanoseconds === "number" ?
          stamped.nanoseconds :
          0;
    return new Date(seconds * 1000 + Math.floor(nanos / 1e6));
  }
  return null;
}

export function vendorDocFromFirestore(
  data: DocumentData | undefined,
): VendorOpenDoc {
  if (!data) {
    return {};
  }
  return {
    approvalStatus:
      typeof data.approvalStatus === "string" ? data.approvalStatus : null,
    active: typeof data.active === "boolean" ? data.active : null,
    openingHours: data.openingHours,
    openOverrideUntil: asDate(data.openOverrideUntil),
  };
}

/**
 * Scheduled sync: align `vendors.active` with opening hours unless a manual
 * override is still in effect.
 */
export const syncVendorOpenHours = onSchedule(
  {
    schedule: "every 1 minutes",
    timeZone: "Asia/Colombo",
    region: "asia-south1",
    timeoutSeconds: 120,
    memory: "256MiB",
  },
  async () => {
    const db = getFirestore();
    const now = new Date();
    let updated = 0;
    let scanned = 0;
    let last: QueryDocumentSnapshot | undefined;

    for (;;) {
      let query: Query = db
        .collection("vendors")
        .orderBy("__name__")
        .limit(200);
      if (last) {
        query = query.startAfter(last);
      }
      const snap = await query.get();
      if (snap.empty) {
        break;
      }

      let batch = db.batch();
      let batchCount = 0;

      const commitBatch = async () => {
        if (batchCount === 0) {
          return;
        }
        await batch.commit();
        batch = db.batch();
        batchCount = 0;
      };

      for (const doc of snap.docs) {
        scanned += 1;
        const result = syncVendorOpenStatus(
          vendorDocFromFirestore(doc.data()),
          now,
        );
        if (!result.changed) {
          continue;
        }
        const patch: Record<string, unknown> = {
          active: result.active,
        };
        if (result.openOverrideUntil == null) {
          patch.openOverrideUntil = FieldValue.delete();
        } else {
          patch.openOverrideUntil = result.openOverrideUntil;
        }
        batch.set(doc.ref, patch, {merge: true});
        batchCount += 1;
        updated += 1;
        if (batchCount >= 400) {
          await commitBatch();
        }
      }
      await commitBatch();

      last = snap.docs[snap.docs.length - 1];
      if (snap.size < 200) {
        break;
      }
    }

    logger.info("syncVendorOpenHours complete", {scanned, updated});
  },
);
