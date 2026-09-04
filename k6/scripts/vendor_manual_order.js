// Load test for the vendor-side phone/walk-in order flow:
// lookupVendorOrderCustomer -> placeVendorManualOrder.
//
//   k6 run k6/scripts/vendor_manual_order.js
//
// This exercises the SAME reserveTrackingNumber() sharded-counter fix as
// place_order.js, through the other code path that used to duplicate it
// (see functions/src/placeOrder.ts) — a regression check that fix 03 from
// the earlier investigation holds under load on this endpoint too.
import { sleep } from 'k6';
import { callCallable } from '../lib/callable.js';
import { vendorOwnerFor } from '../lib/users.js';

const MAX_VUS = Number(__ENV.MAX_VUS || 50);

export const options = {
  scenarios: {
    vendor_manual_order: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '30s', target: Math.ceil(MAX_VUS * 0.2) },
        { duration: '2m', target: MAX_VUS },
        { duration: '30s', target: 0 },
      ],
      gracefulRampDown: '10s',
    },
  },
  thresholds: {
    // Naturally heavier than a single-transaction endpoint: vendor auth
    // check, customer lookup, the order transaction, and a post-commit
    // guest-confirmation update are each their own Firestore round trip.
    http_req_duration: ['p(95)<3000'],
    checks: ['rate>0.95'],
  },
};

export default function () {
  const vendor = vendorOwnerFor(__VU);
  const digits = String(700000000 + ((__VU * 100000 + __ITER) % 99999999)).slice(0, 9);
  const phone = `+94${digits}`;

  callCallable('lookupVendorOrderCustomer', { phone }, vendor.idToken);

  callCallable(
    'placeVendorManualOrder',
    {
      customerPhone: phone,
      customerName: `K6 Guest ${__VU}-${__ITER}`,
      deliveryAddress: {
        line1: '1 Load Test Road',
        line2: '',
        city: 'Colombo',
        phone,
      },
      productsPaid: false,
      packagePriceLkr: 500 + (__ITER % 10) * 100,
      packageDescription: 'K6 test package',
    },
    vendor.idToken,
  );

  sleep(1);
}
