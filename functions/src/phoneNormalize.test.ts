import assert from "node:assert/strict";
import {describe, it} from "node:test";
import {
  guestCustomerIdFromPhone,
  nationalDigits,
  normalizeCustomerPhoneE164,
} from "./phoneNormalize";

describe("phoneNormalize", () => {
  it("normalizes local 07x numbers to +94", () => {
    const r = normalizeCustomerPhoneE164("0771234567");
    assert.equal(r.ok, true);
    if (r.ok) {
      assert.equal(r.e164, "+94771234567");
      assert.equal(r.digits, "771234567");
    }
  });

  it("accepts already-E.164 numbers", () => {
    const r = normalizeCustomerPhoneE164("+94 77 123 4567");
    assert.equal(r.ok, true);
    if (r.ok) {
      assert.equal(r.e164, "+94771234567");
    }
  });

  it("accepts 94-prefixed digits without plus", () => {
    const r = normalizeCustomerPhoneE164("94771234567");
    assert.equal(r.ok, true);
    if (r.ok) {
      assert.equal(r.e164, "+94771234567");
    }
  });

  it("rejects invalid lengths", () => {
    assert.equal(normalizeCustomerPhoneE164("07123").ok, false);
    assert.equal(normalizeCustomerPhoneE164("").ok, false);
  });

  it("builds stable guest customer ids", () => {
    assert.equal(guestCustomerIdFromPhone("+94771234567"), "guest_771234567");
    assert.equal(guestCustomerIdFromPhone("0771234567"), "guest_771234567");
    assert.equal(nationalDigits("077-123-4567"), "771234567");
  });
});
