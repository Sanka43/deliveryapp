// Loads the token pool written by seed/seed-and-mint-tokens.mjs (once,
// shared across all VUs via SharedArray) and hands each VU a consistent
// persona for the life of the test run.
import { SharedArray } from 'k6/data';

const pool = new SharedArray('mnd-k6-tokens', function () {
  const raw = open('../.tokens.json');
  return [JSON.parse(raw)];
})[0];

export function customerFor(vu) {
  const customers = pool.customers;
  if (!customers || customers.length === 0) {
    throw new Error('No seeded customers found in .tokens.json — run the seed script first.');
  }
  return customers[(vu - 1) % customers.length];
}

export function riderFor(vu) {
  const riders = pool.riders;
  if (!riders || riders.length === 0) {
    throw new Error('No seeded riders found in .tokens.json — run the seed script first.');
  }
  return riders[(vu - 1) % riders.length];
}

export function vendorInfo() {
  return pool.vendor;
}

export function couponCode() {
  return pool.couponCode;
}
