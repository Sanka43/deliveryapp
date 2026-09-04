// Load test (or smoke check) for getDrivingRoute.
//
//   k6 run k6/scripts/driving_route.js                  # smoke: 1 VU, 5 requests
//   k6 run -e MAX_VUS=100 k6/scripts/driving_route.js    # ramped load
//
// getDrivingRoute proxies the REAL Google Maps Directions API — a real,
// billed call every time, even against the local emulator. Never ramp this
// against the real GOOGLE_MAPS_KEY from functions/.env.
//
// To load-test for free, start the emulator with MAPS_API_MOCK=true
// exported first (never edit functions/.env itself):
//   MAPS_API_MOCK=true firebase --config k6/firebase.emulators.json \
//     emulators:start --only functions,firestore,auth --project mnd-masterndelivery
// functions/src/mapsProxy.ts checks that flag and returns a synthetic
// response before ever calling Google, so this is genuinely zero-cost —
// unlike faking the API key itself, which does NOT work (the emulator's own
// .env loading overrides a shell-exported key regardless).
import http from 'k6/http';
import { check, sleep } from 'k6';
import { BASE_URL } from '../config.js';

const MAX_VUS = Number(__ENV.MAX_VUS || 0);

export const options = MAX_VUS > 0
  ? {
    scenarios: {
      driving_route: {
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
  }
  : {
    vus: 1,
    iterations: Number(__ENV.ITERATIONS || 5),
  };

const ROUTES = [
  { origin: '6.9271,79.8612', destination: '6.9147,79.9724' },
  { origin: '6.9319,79.8478', destination: '6.8905,79.8558' },
  { origin: '6.9147,79.9724', destination: '6.8905,79.8558' },
  { origin: '7.2906,80.6337', destination: '6.9271,79.8612' },
];

export default function () {
  const route = ROUTES[__ITER % ROUTES.length];
  const res = http.post(`${BASE_URL}/getDrivingRoute`, JSON.stringify(route), {
    headers: { 'Content-Type': 'application/json' },
  });
  check(res, { 'getDrivingRoute: status 200': (r) => r.status === 200 });
  sleep(1);
}
