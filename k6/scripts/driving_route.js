// Smoke check (NOT a load test) for getDrivingRoute.
//
//   k6 run k6/scripts/driving_route.js
//
// This endpoint proxies the REAL Google Maps Directions API server-side —
// even against the local Firebase emulator, a call here reaches Google and
// burns real quota/billing (GOOGLE_MAPS_KEY from functions/.env). Keep this
// at a small, fixed request count; do not ramp VUs on this script.
import http from 'k6/http';
import { check, sleep } from 'k6';
import { BASE_URL } from '../config.js';

export const options = {
  vus: 1,
  iterations: Number(__ENV.ITERATIONS || 5),
};

const ROUTES = [
  { origin: '6.9271,79.8612', destination: '6.9147,79.9724' },
  { origin: '6.9319,79.8478', destination: '6.8905,79.8558' },
];

export default function () {
  const route = ROUTES[__ITER % ROUTES.length];
  const res = http.post(`${BASE_URL}/getDrivingRoute`, JSON.stringify(route), {
    headers: { 'Content-Type': 'application/json' },
  });
  check(res, { 'getDrivingRoute: status 200': (r) => r.status === 200 });
  sleep(1);
}
