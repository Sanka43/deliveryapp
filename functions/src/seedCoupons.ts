/**
 * One-time seed for default coupons (run via Firebase Admin or deploy script).
 *
 * firebase functions:shell
 * > const admin = require('firebase-admin');
 * > const db = admin.firestore();
 * > await db.collection('coupons').doc('SAVE100').set({...});
 */
export const DEFAULT_COUPONS = [
  {
    id: "SAVE100",
    code: "SAVE100",
    discountType: "flat" as const,
    value: 100,
    active: true,
    usedCount: 0,
  },
  {
    id: "MND10",
    code: "MND10",
    discountType: "percent" as const,
    value: 10,
    active: true,
    usedCount: 0,
  },
  {
    id: "WELCOME15",
    code: "WELCOME15",
    discountType: "percent" as const,
    value: 15,
    active: true,
    minSubtotalLkr: 500,
    usedCount: 0,
  },
];
