import {HttpsError} from "firebase-functions/v2/https";

export type CheckoutOrderType = "standard" | "emergency" | "schedule";

/** A scheduled order can't be booked further ahead than this. */
export const MAX_SCHEDULE_AHEAD_MS = 3 * 24 * 60 * 60 * 1000;

export interface ResolvedCheckoutOrderType {
  orderType: CheckoutOrderType;
  scheduledFor: Date | null;
}

/** Ends with `Z` or a `+hh:mm` / `-hh:mm` / `+hhmm` UTC offset. */
const HAS_UTC_OFFSET = /(Z|[+-]\d{2}:?\d{2})$/i;

/**
 * Validates the customer's chosen checkout order type against the raw
 * callable request fields. Emergency only makes sense for delivery (the
 * customer isn't collecting it themselves), and a scheduled time must be a
 * real future timestamp within the booking window.
 *
 * Throws `HttpsError` on anything invalid — the caller (an `onCall`
 * function) can let it propagate as-is.
 */
export function resolveCheckoutOrderType(
  orderTypeRaw: unknown,
  isSelfPickup: boolean,
  scheduledForRaw: unknown,
  nowMs: number = Date.now(),
): ResolvedCheckoutOrderType {
  const raw = String(orderTypeRaw ?? "standard").trim();
  const orderType: CheckoutOrderType =
    raw === "emergency" || raw === "schedule" ? raw : "standard";

  if (orderType === "emergency" && isSelfPickup) {
    throw new HttpsError(
      "failed-precondition",
      "Emergency orders are only available for delivery.",
    );
  }

  if (orderType !== "schedule") {
    return {orderType, scheduledFor: null};
  }

  // The instant must be unambiguous: an ISO string with no "Z"/offset is read
  // as server-local (UTC) time, which silently shifts a customer's wall-clock
  // pick by their UTC offset (e.g. 8:45 PM in Sri Lanka became 2:15 AM).
  const rawString = scheduledForRaw == null ? "" : String(scheduledForRaw);
  const parsed = HAS_UTC_OFFSET.test(rawString) ? new Date(rawString) : null;
  if (!parsed || Number.isNaN(parsed.getTime())) {
    throw new HttpsError(
      "invalid-argument",
      "A valid scheduled date/time is required.",
    );
  }
  if (parsed.getTime() <= nowMs) {
    throw new HttpsError(
      "failed-precondition",
      "Scheduled time must be in the future.",
    );
  }
  if (parsed.getTime() > nowMs + MAX_SCHEDULE_AHEAD_MS) {
    throw new HttpsError(
      "failed-precondition",
      "Scheduled time is too far in the future.",
    );
  }
  return {orderType, scheduledFor: parsed};
}

/**
 * Whether a vendor doc may receive an order of [orderType] right now.
 *
 * `active` is flipped false by the opening-hours sync while a shop is
 * closed, so an inactive-but-approved shop is merely "closed for now" — fine
 * for a Schedule order (placed for later), not for an immediate one. Shops
 * that are pending/rejected or otherwise not approved never qualify.
 */
export function vendorAcceptsOrderType(
  vendor: {active?: unknown; approvalStatus?: unknown},
  orderType: CheckoutOrderType,
): boolean {
  if (vendor.active === true) {
    return true;
  }
  return orderType === "schedule" && vendor.approvalStatus === "approved";
}
