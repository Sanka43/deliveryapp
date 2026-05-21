/**
 * Seeds Firestore with vendors, products, and banners that match the Flutter app
 * (collections: vendors, products, banners — see lib/core/constants/firebase_collections.dart).
 *
 * Prerequisites:
 *   1. Firebase Console → Project settings → Service accounts → Generate new private key → save JSON.
 *   2. PowerShell:
 *        $env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\to\serviceAccount.json"
 *        $env:FIREBASE_PROJECT_ID="mnd-masterndelivery"   # optional if JSON contains project_id
 *   3. npm install
 *   4. node seed.mjs
 */

import { readFileSync } from 'node:fs';

import admin from 'firebase-admin';

const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
if (!credPath) {
  console.error('Set GOOGLE_APPLICATION_CREDENTIALS to your Firebase service account JSON path.');
  process.exit(1);
}

const serviceAccount = JSON.parse(readFileSync(credPath, 'utf8'));
const projectId =
  process.env.FIREBASE_PROJECT_ID || serviceAccount.project_id || 'mnd-masterndelivery';

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId,
});

const db = admin.firestore();
const { GeoPoint, FieldValue } = admin.firestore;

const vendors = {
  'freshmart-grocery': {
    name: 'FreshMart Grocery',
    tag: 'Groceries',
    category: 'Groceries',
    rating: 4.7,
    eta: '20-30 min',
    deliveryFee: 'LKR 120',
    active: true,
    imageUrl:
      'https://images.unsplash.com/photo-1542838132-92c53300491e?q=80&w=600&auto=format&fit=crop',
    location: new GeoPoint(6.9271, 79.8612),
    updatedAt: FieldValue.serverTimestamp(),
  },
  'spice-hub-restaurant': {
    name: 'Spice Hub Restaurant',
    tag: 'Food',
    category: 'Food',
    rating: 4.6,
    eta: '15-25 min',
    deliveryFee: 'LKR 180',
    active: true,
    imageUrl:
      'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?q=80&w=600&auto=format&fit=crop',
    location: new GeoPoint(6.9147, 79.9727),
    updatedAt: FieldValue.serverTimestamp(),
  },
  'medicare-pharmacy': {
    name: 'MediCare Pharmacy',
    tag: 'Pharmacy',
    category: 'Pharmacy',
    rating: 4.8,
    eta: '25-35 min',
    deliveryFee: 'LKR 90',
    active: true,
    imageUrl:
      'https://images.unsplash.com/photo-1587854692152-cbe660dbde88?q=80&w=600&auto=format&fit=crop',
    location: new GeoPoint(6.8941, 79.9024),
    updatedAt: FieldValue.serverTimestamp(),
  },
};

const products = [
  {
    id: 'fm_avocado',
    data: {
      name: 'Fresh Avocado Pack',
      storeId: 'freshmart-grocery',
      storeName: 'FreshMart Grocery',
      lookupKey: 'fresh_avocado_pack',
      price: 980,
      active: true,
      isAvailable: true,
      imageUrl:
        'https://images.unsplash.com/photo-1519162808019-7de1683fa2ad?q=80&w=600&auto=format&fit=crop',
      updatedAt: FieldValue.serverTimestamp(),
    },
  },
  {
    id: 'fm_milk',
    data: {
      name: 'Protein Milk 1L',
      storeId: 'freshmart-grocery',
      storeName: 'FreshMart Grocery',
      lookupKey: 'protein_milk_1l',
      price: 540,
      active: true,
      isAvailable: true,
      imageUrl:
        'https://images.unsplash.com/photo-1563636619-e9143da7973b?q=80&w=600&auto=format&fit=crop',
      updatedAt: FieldValue.serverTimestamp(),
    },
  },
  {
    id: 'sh_cake',
    data: {
      name: 'Chocolate Cake',
      storeId: 'spice-hub-restaurant',
      storeName: 'Spice Hub Restaurant',
      lookupKey: 'chocolate_cake',
      price: 1650,
      active: true,
      isAvailable: true,
      imageUrl:
        'https://images.unsplash.com/photo-1578985545062-69928b1d9587?q=80&w=600&auto=format&fit=crop',
      updatedAt: FieldValue.serverTimestamp(),
    },
  },
  {
    id: 'sh_burger',
    data: {
      name: 'Chicken Burger',
      storeId: 'spice-hub-restaurant',
      storeName: 'Spice Hub Restaurant',
      lookupKey: 'chicken_burger',
      price: 980,
      active: true,
      isAvailable: true,
      imageUrl:
        'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?q=80&w=600&auto=format&fit=crop',
      updatedAt: FieldValue.serverTimestamp(),
    },
  },
  {
    id: 'mc_vitamins',
    data: {
      name: 'Vitamin C Tablets',
      storeId: 'medicare-pharmacy',
      storeName: 'MediCare Pharmacy',
      lookupKey: 'vitamin_c_tablets',
      price: 1250,
      active: true,
      isAvailable: true,
      imageUrl:
        'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?q=80&w=600&auto=format&fit=crop',
      updatedAt: FieldValue.serverTimestamp(),
    },
  },
];

const banners = [
  {
    id: 'banner_welcome',
    data: {
      title: 'Welcome to MND',
      subtitle: 'Live data from Firestore — order in a few taps',
      startColor: 0xff2563eb,
      endColor: 0xff1d4ed8,
      iconKey: 'delivery',
      order: 1,
      active: true,
      updatedAt: FieldValue.serverTimestamp(),
    },
  },
  {
    id: 'banner_offers',
    data: {
      title: 'Weekly Offers',
      subtitle: 'Groceries & meals — check Search tab',
      startColor: 0xff16a34a,
      endColor: 0xff15803d,
      iconKey: 'grocery',
      order: 2,
      active: true,
      updatedAt: FieldValue.serverTimestamp(),
    },
  },
];

async function main() {
  const batch = db.batch();
  for (const [id, data] of Object.entries(vendors)) {
    batch.set(db.collection('vendors').doc(id), data, { merge: true });
  }
  for (const { id, data } of products) {
    batch.set(db.collection('products').doc(id), data, { merge: true });
  }
  for (const { id, data } of banners) {
    batch.set(db.collection('banners').doc(id), data, { merge: true });
  }
  await batch.commit();
  console.log(`Seeded project "${projectId}": vendors, products, banners (merge).`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
