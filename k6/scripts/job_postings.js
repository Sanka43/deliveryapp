// Load test for the job-posting approval flow:
// createJobPost (customer) -> approveJobPost (admin).
//
//   k6 run k6/scripts/job_postings.js
//
// createJobPost rejects a second post with the same title from the same
// user inside a 24h window, so the title includes __VU-__ITER to always be
// unique. It also requires a customers/{uid} doc with a jobPostCredits
// balance (each post spends one) — seeded very high so this can sustain a
// full ramp, same reasoning as the rider wallet balance elsewhere in this
// harness.
//
// Every post from one customer decrements that SAME customers/{uid} doc, so
// (same as rider_payouts.js / admin_settlements.js) reseed with more
// customers before a high-VU run: K6_NUM_CUSTOMERS=200.
import { sleep } from 'k6';
import { callCallable } from '../lib/callable.js';
import { customerFor, adminUser } from '../lib/users.js';

const MAX_VUS = Number(__ENV.MAX_VUS || 20);
// Included in every title so runs stay unique across separate k6
// invocations too, not just within one run — __VU/__ITER alone repeat
// every time k6 restarts, which collides with a title an earlier run
// already posted from the same customer inside the 24h duplicate window.
const RUN_ID = Date.now();

export const options = {
  scenarios: {
    job_postings: {
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
    http_req_duration: ['p(95)<1000'],
    checks: ['rate>0.95'],
  },
};

export default function () {
  const customer = customerFor(__VU);
  const admin = adminUser();

  const { result } = callCallable(
    'createJobPost',
    {
      title: `K6 Test Job ${RUN_ID}-${__VU}-${__ITER}`,
      category: 'Delivery',
      type: 'Full-time',
      salary: 'Rs. 30,000 - 40,000',
      location: 'Colombo',
      description: 'K6 load test job posting — synthetic listing, not a real vacancy.',
      companyName: 'K6 Load Test Co',
      contactPhone: '+94771234567',
    },
    customer.idToken,
  );

  if (result?.jobId) {
    callCallable('approveJobPost', { jobId: result.jobId }, admin.idToken);
  }

  sleep(1);
}
