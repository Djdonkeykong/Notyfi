const BUNDLE_ID = "com.djdonkeykong.notely";

async function generateClientSecret(): Promise<string> {
  const teamId = Deno.env.get("APPLE_TEAM_ID")!;
  const keyId = Deno.env.get("APPLE_KEY_ID")!;
  const pem = Deno.env.get("APPLE_PRIVATE_KEY")!;

  const pemContent = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");

  const binaryKey = Uint8Array.from(atob(pemContent), (c) => c.charCodeAt(0));

  const key = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );

  const now = Math.floor(Date.now() / 1000);

  const headerJson = JSON.stringify({ alg: "ES256", kid: keyId });
  const payloadJson = JSON.stringify({
    iss: teamId,
    iat: now,
    exp: now + 15552000,
    aud: "https://appleid.apple.com",
    sub: BUNDLE_ID,
  });

  const toBase64Url = (str: string) =>
    btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");

  const headerB64 = toBase64Url(headerJson);
  const payloadB64 = toBase64Url(payloadJson);
  const signingInput = `${headerB64}.${payloadB64}`;

  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );

  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=/g, "");

  return `${signingInput}.${sigB64}`;
}

export async function exchangeAuthCodeForRefreshToken(
  authorizationCode: string,
): Promise<string> {
  const clientSecret = await generateClientSecret();

  const body = new URLSearchParams({
    client_id: BUNDLE_ID,
    client_secret: clientSecret,
    code: authorizationCode,
    grant_type: "authorization_code",
  });

  const res = await fetch("https://appleid.apple.com/auth/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Apple token exchange failed: ${text}`);
  }

  const data = await res.json();
  if (!data.refresh_token) {
    throw new Error("Apple token response missing refresh_token");
  }

  return data.refresh_token as string;
}

export async function revokeAppleRefreshToken(
  refreshToken: string,
): Promise<void> {
  const clientSecret = await generateClientSecret();

  const body = new URLSearchParams({
    client_id: BUNDLE_ID,
    client_secret: clientSecret,
    token: refreshToken,
    token_type_hint: "refresh_token",
  });

  const res = await fetch("https://appleid.apple.com/auth/revoke", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Apple token revocation failed: ${text}`);
  }
}
