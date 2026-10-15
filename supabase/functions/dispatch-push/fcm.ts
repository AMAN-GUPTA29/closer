// Firebase Cloud Messaging HTTP v1 client (Android and, through APNs, iOS).
// Authenticates with a Google service account using a signed JWT (RS256).

import type { PushMessage, SendResult } from "./logic.ts";

export interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

function base64url(data: Uint8Array | string): string {
  const bytes = typeof data === "string"
    ? new TextEncoder().encode(data)
    : data;
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function pemToPkcs8(pem: string): Uint8Array<ArrayBuffer> {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const bin = atob(b64);
  const out = new Uint8Array(new ArrayBuffer(bin.length));
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

/** Builds and signs the OAuth assertion JWT for the FCM scope. */
export async function signAssertion(
  sa: ServiceAccount,
  nowSeconds: number,
): Promise<string> {
  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: nowSeconds,
    exp: nowSeconds + 3600,
  }));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToPkcs8(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      key,
      new TextEncoder().encode(`${header}.${claims}`),
    ),
  );
  return `${header}.${claims}.${base64url(signature)}`;
}

/** Maps an FCM HTTP v1 response to a send result. */
export function classifyFcmResponse(status: number, body: string): SendResult {
  if (status >= 200 && status < 300) return "ok";
  if (status === 404 || body.includes("UNREGISTERED")) return "invalid";
  if (status === 400 && body.includes("INVALID_ARGUMENT")) return "invalid";
  if (status === 403 && body.includes("SENDER_ID_MISMATCH")) return "invalid";
  return "retry"; // 429, 5xx, auth hiccups: try again later
}

export class FcmClient {
  #token: { value: string; expires: number } | null = null;

  constructor(
    private readonly sa: ServiceAccount,
    private readonly fetchFn: typeof fetch = fetch,
  ) {}

  async #accessToken(): Promise<string> {
    const now = Math.floor(Date.now() / 1000);
    if (this.#token && this.#token.expires - 60 > now) return this.#token.value;
    const assertion = await signAssertion(this.sa, now);
    const res = await this.fetchFn("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion,
      }),
    });
    if (!res.ok) throw new Error(`oauth ${res.status}`);
    const json = await res.json() as {
      access_token: string;
      expires_in: number;
    };
    this.#token = { value: json.access_token, expires: now + json.expires_in };
    return json.access_token;
  }

  async send(token: string, message: PushMessage): Promise<SendResult> {
    const access = await this.#accessToken();
    const res = await this.fetchFn(
      `https://fcm.googleapis.com/v1/projects/${this.sa.project_id}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${access}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title: message.title, body: message.body },
            data: message.data,
            android: {
              priority: "high",
              notification: { channel_id: "closer_activity" },
            },
            apns: {
              payload: { aps: { sound: "default", "content-available": 1 } },
            },
          },
        }),
      },
    );
    return classifyFcmResponse(res.status, await res.text());
  }
}
