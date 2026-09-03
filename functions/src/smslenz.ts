import {logger} from "firebase-functions";

const SEND_SMS_URL = "https://smslenz.lk/api/send-sms";

export type SmslenzConfig = {
  userId: string;
  apiKey: string;
  senderId: string;
};

export type SendSmsResult =
  | {ok: true; raw: unknown}
  | {ok: false; error: string; raw?: unknown};

/**
 * Send one SMS via SMSlenz REST API (form-urlencoded POST).
 * Contact must be E.164 like +9477XXXXXXX.
 */
export async function sendSmslenzSms(
  config: SmslenzConfig,
  contactE164: string,
  message: string,
): Promise<SendSmsResult> {
  const userId = config.userId.trim();
  const apiKey = config.apiKey.trim();
  const senderId = config.senderId.trim();
  if (!userId || !apiKey || !senderId) {
    return {ok: false, error: "SMS gateway is not configured."};
  }

  const body = new URLSearchParams({
    user_id: userId,
    api_key: apiKey,
    sender_id: senderId,
    contact: contactE164,
    message,
  });

  let response: Response;
  try {
    response = await fetch(SEND_SMS_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        Accept: "application/json",
      },
      body,
    });
  } catch (e) {
    logger.error("SMSlenz network error", e);
    return {ok: false, error: "Could not reach SMS gateway."};
  }

  const text = await response.text();
  let raw: unknown = text;
  try {
    raw = JSON.parse(text) as unknown;
  } catch {
    // keep text
  }

  if (!response.ok) {
    logger.error("SMSlenz HTTP error", {
      status: response.status,
      body: typeof raw === "string" ? raw.slice(0, 300) : raw,
    });
    return {ok: false, error: "SMS gateway rejected the request.", raw};
  }

  if (raw && typeof raw === "object" && "success" in raw) {
    const payload = raw as {success?: unknown; message?: unknown};
    if (payload.success === false) {
      const msg =
        typeof payload.message === "string"
          ? payload.message
          : "SMS send failed.";
      logger.error("SMSlenz success=false", {message: msg});
      return {ok: false, error: msg, raw};
    }
  }

  return {ok: true, raw};
}
