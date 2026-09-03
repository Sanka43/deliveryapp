// 1 VU, 1 iteration through every priority endpoint. Run this first after
// seeding to confirm everything is wired up before running a real load test.
//
//   k6 run k6/scripts/smoke.js
import http from 'k6/http';
import { check, sleep } from 'k6';
import { BASE_URL } from '../config.js';
import { callCallable } from '../lib/callable.js';
import { customerFor, riderFor, vendorInfo, couponCode } from '../lib/users.js';

export const options = { vus: 1, iterations: 1 };

const PICKUP = { lat: 6.9271, lng: 79.8612, label: 'Colombo Fort' };
const DROPOFF = { lat: 6.9147, lng: 79.9724, label: 'Malabe' };
const TEST_PHONE = '+94771234567';

export default function () {
  const customer = customerFor(__VU);
  const rider = riderFor(__VU);
  const vendor = vendorInfo();

  // --- Ride quoting -> booking ---
  const { result: fares } = callCallable(
    'quoteRideFares',
    { pickup: PICKUP, dropoff: DROPOFF },
    customer.idToken,
  );
  const quote = fares?.quotes?.[0];
  if (quote) {
    callCallable(
      'confirmCashRide',
      { quoteId: quote.quoteId, contactPhone: TEST_PHONE },
      customer.idToken,
    );
  }

  // --- Coupon validation ---
  callCallable(
    'validateCoupon',
    { code: couponCode(), subtotalLkr: 2000 },
    customer.idToken,
  );

  // --- Order placement (self-pickup: skips the real Google Maps distance call) ---
  callCallable(
    'placeCashOnDeliveryOrder',
    {
      vendorId: vendor.vendorId,
      items: [{ productKey: vendor.productIds[0], quantity: 1 }],
      fulfillmentMode: 'selfPickup',
      deliveryAddress: { phone: TEST_PHONE },
    },
    customer.idToken,
  );

  // --- Rider payouts ---
  callCallable(
    'requestRiderWithdrawal',
    { amountLkr: 500, payoutMethod: 'bank', payoutAccount: '1234567890' },
    rider.idToken,
  );
  callCallable('riderRequestCashSettlement', { method: 'bank' }, rider.idToken);

  // --- Driving route: no auth, hits the real Google Maps API even via the
  // emulator, so this stays a single smoke check, never a load test. ---
  const routeRes = http.post(
    `${BASE_URL}/getDrivingRoute`,
    JSON.stringify({
      origin: `${PICKUP.lat},${PICKUP.lng}`,
      destination: `${DROPOFF.lat},${DROPOFF.lng}`,
    }),
    { headers: { 'Content-Type': 'application/json' } },
  );
  check(routeRes, { 'getDrivingRoute: status 200': (r) => r.status === 200 });

  sleep(1);
}
