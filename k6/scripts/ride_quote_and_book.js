// Load test for the ride-booking hot path: quoteRideFares -> confirmCashRide.
//
//   k6 run k6/scripts/ride_quote_and_book.js
// Tune the ramp with -e MAX_VUS=100, or override the whole scenario by
// editing the stages below.
import { sleep } from 'k6';
import { callCallable } from '../lib/callable.js';
import { customerFor } from '../lib/users.js';

const MAX_VUS = Number(__ENV.MAX_VUS || 50);

export const options = {
  scenarios: {
    ride_quote_and_book: {
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
    http_req_duration: ['p(95)<800'],
    checks: ['rate>0.95'],
  },
};

const PICKUP = { lat: 6.9271, lng: 79.8612, label: 'Colombo Fort' };
const DROPOFF = { lat: 6.9147, lng: 79.9724, label: 'Malabe' };
const TEST_PHONE = '+94771234567';

export default function () {
  const customer = customerFor(__VU);

  const { result } = callCallable(
    'quoteRideFares',
    { pickup: PICKUP, dropoff: DROPOFF },
    customer.idToken,
  );

  const quote = result?.quotes?.[0];
  if (quote) {
    callCallable(
      'confirmCashRide',
      { quoteId: quote.quoteId, contactPhone: TEST_PHONE },
      customer.idToken,
    );
  }

  sleep(1);
}
