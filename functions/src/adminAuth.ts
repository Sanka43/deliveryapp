import {getFirestore} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

/**
 * Canonical admin check for callables. `users/{uid}.role` is the newer shape;
 * `customers/{uid}.role` is what the web admin session and firestore.rules
 * actually resolve against, so both are accepted.
 */
export async function assertAdmin(uid: string): Promise<void> {
  const db = getFirestore();
  const snap = await db.collection("users").doc(uid).get();
  const role = String(snap.data()?.role ?? "").trim().toLowerCase();
  if (role === "admin") {
    return;
  }
  const customerSnap = await db.collection("customers").doc(uid).get();
  const customerRole = String(customerSnap.data()?.role ?? "")
    .trim()
    .toLowerCase();
  if (customerRole !== "admin") {
    throw new HttpsError("permission-denied", "Admin only.");
  }
}
