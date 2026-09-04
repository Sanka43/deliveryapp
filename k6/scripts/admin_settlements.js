// Load test for the admin panel's rider-payout approval flow:
// requestRiderWithdrawal (rider) -> adminSettleRiderWithdrawal (admin).
//
//   k6 run k6/scripts/admin_settlements.js
//
// Each iteration is a fresh withdrawal, so — unlike a cash-settlement
// handover — this genuinely sustains per-iteration load: nothing here is
// "already pending" the way a repeated settlement request would be.
//
// Like rider_payouts.js, riderFor(vu) cycles through the seeded rider pool,
// so at high VU counts reseed with more riders first (K6_NUM_RIDERS=200)
// or many VUs will contend on the same few riders' wallet documents.
import { sleep } from 'k6';
import { callCallable } from '../lib/callable.js';
import { riderFor, adminUser } from '../lib/users.js';

const MAX_VUS = Number(__ENV.MAX_VUS || 20);

export const options = {
  scenarios: {
    admin_settle_withdrawals: {
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

// One-time, once per seeded rider: request a cash handover, then have the
// admin confirm it — exercises adminConfirmCashSettlement at least once.
// This can't sustain per-iteration load the way withdrawals can: a
// settlement sweeps ALL open cash_ledger entries at once, so after the
// first request there's nothing left to hand over until new
// deliveries/rides create more open entries (see rider_payouts.js for the
// same limitation on the request side alone).
export function setup() {
  const admin = adminUser();
  const riderCount = Number(__ENV.K6_NUM_RIDERS || 10);
  for (let i = 1; i <= riderCount; i++) {
    const rider = riderFor(i);
    const { result } = callCallable(
      'riderRequestCashSettlement',
      { method: 'bank' },
      rider.idToken,
    );
    if (result?.settlementId) {
      callCallable(
        'adminConfirmCashSettlement',
        { riderId: rider.uid, settlementId: result.settlementId },
        admin.idToken,
      );
    }
  }
}

export default function () {
  const rider = riderFor(__VU);
  const admin = adminUser();

  const { result } = callCallable(
    'requestRiderWithdrawal',
    {
      amountLkr: 500,
      payoutMethod: 'bank',
      payoutAccount: `k6-account-${__VU}`,
    },
    rider.idToken,
  );

  if (result?.withdrawalId) {
    callCallable(
      'adminSettleRiderWithdrawal',
      { riderId: rider.uid, withdrawalId: result.withdrawalId, action: 'paid' },
      admin.idToken,
    );
  }

  sleep(1);
}
