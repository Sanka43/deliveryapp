// Load test for order placement: placeCashOnDeliveryOrder against the
// seeded vendor/products. Uses fulfillmentMode "selfPickup" by default so
// it never triggers the real Google Maps driving-distance lookup that a
// delivery-mode order would make.
//
//   k6 run k6/scripts/place_order.js
import { sleep } from 'k6';
import { callCallable } from '../lib/callable.js';
import { customerFor, vendorInfo, couponCode } from '../lib/users.js';

const MAX_VUS = Number(__ENV.MAX_VUS || 50);
const TEST_PHONE = '+94771234567';

export const options = {
  scenarios: {
    place_order: {
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
  const vendor = vendorInfo();
  const productKey = vendor.productIds[__ITER % vendor.productIds.length];

  callCallable(
    'placeCashOnDeliveryOrder',
    {
      vendorId: vendor.vendorId,
      items: [{ productKey, quantity: 1 + (__ITER % 3) }],
      fulfillmentMode: 'selfPickup',
      couponCode: __ITER % 5 === 0 ? couponCode() : undefined,
      deliveryAddress: { phone: TEST_PHONE },
    },
    customer.idToken,
  );

  sleep(1);
}
