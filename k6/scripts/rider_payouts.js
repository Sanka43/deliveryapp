// Load test for rider payout endpoints.
//
//   k6 run k6/scripts/rider_payouts.js
//
// requestRiderWithdrawal is the main ramped load here — it just needs
// sufficient wallet balance, which the seed script sets very high
// (K6_WALLET_BALANCE_LKR, default 5,000,000) so it can sustain the full
// test duration.
//
// riderRequestCashSettlement only succeeds ONCE per rider until an admin
// confirms the settlement (adminConfirmCashSettlement — not exercised here,
// it's an admin-only action), so it can't be hammered per-iteration like a
// withdrawal can. It's exercised once per seeded rider in setup() instead.
import { sleep } from 'k6';
import { callCallable } from '../lib/callable.js';
import { riderFor } from '../lib/users.js';

const MAX_VUS = Number(__ENV.MAX_VUS || 20);

export const options = {
  scenarios: {
    rider_withdrawals: {
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
  },
};

export function setup() {
  const riderCount = Number(__ENV.K6_NUM_RIDERS || 10);
  for (let i = 1; i <= riderCount; i++) {
    const rider = riderFor(i);
    callCallable('riderRequestCashSettlement', { method: 'bank' }, rider.idToken);
  }
}

export default function () {
  const rider = riderFor(__VU);

  callCallable(
    'requestRiderWithdrawal',
    {
      amountLkr: 500,
      payoutMethod: 'bank',
      payoutAccount: `k6-account-${__VU}`,
    },
    rider.idToken,
  );

  sleep(1);
}
