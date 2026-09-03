/**
 * Phone helpers shared by vendor manual order placement.
 * Mirrors mnd_customer PhoneNumberUtils (+94 national length).
 */

export type NormalizePhoneResult =
  | {ok: true; e164: string; digits: string}
  | {ok: false; error: string};

/** Strip to digits and drop a leading trunk 0. */
export function nationalDigits(value: string): string {
  let digits = String(value ?? "").replace(/[^0-9]/g, "");
  if (digits.startsWith("0")) {
    digits = digits.substring(1);
  }
  return digits;
}

/**
 * Normalize a Sri Lanka-first phone to E.164.
 * Accepts `077…`, `77…`, `9477…`, or `+9477…`.
 */
export function normalizeCustomerPhoneE164(raw: unknown): NormalizePhoneResult {
  const input = String(raw ?? "").trim();
  if (!input) {
    return {ok: false, error: "Phone number is required."};
  }

  let digits = input.replace(/[^0-9]/g, "");
  if (!digits) {
    return {ok: false, error: "Enter a valid phone number."};
  }

  // Already country-coded without +
  if (digits.startsWith("94") && digits.length >= 11) {
    digits = digits.slice(2);
  }

  if (digits.startsWith("0")) {
    digits = digits.substring(1);
  }

  if (digits.length !== 9) {
    return {ok: false, error: "Enter a valid Sri Lankan mobile number."};
  }

  return {ok: true, e164: `+94${digits}`, digits};
}

/** Stable guest customerId — not a Firebase Auth UID. */
export function guestCustomerIdFromPhone(e164OrDigits: string): string {
  const normalized = normalizeCustomerPhoneE164(e164OrDigits);
  if (normalized.ok) {
    return `guest_${normalized.digits}`;
  }
  const digits = nationalDigits(e164OrDigits);
  return `guest_${digits}`;
}
