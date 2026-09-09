import * as logger from "firebase-functions/logger";

const OAUTH_PATH = "/merchant/v1/oauth/token";
const REFUND_PATH = "/merchant/v1/payment/refund";

type PayHereTokenResponse = {access_token?: string};
type PayHereRefundResponse = {status?: number; msg?: string; data?: number};

export type RefundPayHerePaymentResult =
  | {ok: true; refundId: string}
  | {ok: false; error: string};

function payHereApiBase(): string {
  const mode = (process.env.PAYHERE_MODE ?? "sandbox").trim().toLowerCase();
  return mode === "live" ?
    "https://www.payhere.lk" :
    "https://sandbox.payhere.lk";
}

async function getPayHereAccessToken(): Promise<string> {
  const appId = (process.env.PAYHERE_APP_ID ?? "").trim();
  const appSecret = (process.env.PAYHERE_APP_SECRET ?? "").trim();
  if (!appId || !appSecret) {
    throw new Error(
      "PayHere refund API not configured (PAYHERE_APP_ID / PAYHERE_APP_SECRET).",
    );
  }
  const basic = Buffer.from(`${appId}:${appSecret}`).toString("base64");
  const res = await fetch(`${payHereApiBase()}${OAUTH_PATH}`, {
    method: "POST",
    headers: {
      Authorization: `Basic ${basic}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: "grant_type=client_credentials",
  });
  const text = await res.text();
  let json: PayHereTokenResponse | undefined;
  try {
    json = JSON.parse(text) as PayHereTokenResponse;
  } catch {
    // fall through — reported as missing access_token below
  }
  if (!res.ok || !json?.access_token) {
    throw new Error(`PayHere OAuth token request failed: ${res.status} ${text}`);
  }
  return json.access_token;
}

/**
 * Issues a refund for a completed PayHere payment (card payment_id, the
 * value stored as `paymentTransactionId` on orders/trips). Requires the
 * "Automated Charging API" app credentials (PAYHERE_APP_ID/APP_SECRET) —
 * separate from the merchant checkout secrets used elsewhere in payHere.ts.
 */
export async function refundPayHerePayment(
  paymentId: string,
  amount: number,
  description: string,
): Promise<RefundPayHerePaymentResult> {
  try {
    const token = await getPayHereAccessToken();
    const res = await fetch(`${payHereApiBase()}${REFUND_PATH}`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        payment_id: paymentId,
        description,
        amount: amount.toFixed(2),
      }),
    });
    const text = await res.text();
    let json: PayHereRefundResponse | undefined;
    try {
      json = JSON.parse(text) as PayHereRefundResponse;
    } catch {
      // fall through — reported below
    }
    if (!res.ok || json?.status !== 1) {
      const msg = json?.msg ?? `HTTP ${res.status}: ${text}`;
      logger.error("PayHere refund request failed", {paymentId, msg});
      return {ok: false, error: msg};
    }
    return {ok: true, refundId: String(json.data ?? "")};
  } catch (e) {
    const error = e instanceof Error ? e.message : String(e);
    logger.error("PayHere refund threw", {paymentId, error});
    return {ok: false, error};
  }
}
