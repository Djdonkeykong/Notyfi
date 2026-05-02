import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const ACTIVE_EVENTS = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "UNCANCELLATION",
  "TRIAL_STARTED",
  "TRIAL_CONVERTED",
  "PRODUCT_CHANGE",
  "NON_RENEWING_PURCHASE",
  "SUBSCRIPTION_EXTENDED",
  "TEMPORARY_ENTITLEMENT_GRANT",
]);

const INACTIVE_EVENTS = new Set([
  "EXPIRATION",
  "SUBSCRIPTION_PAUSED",
]);

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(null, { status: 405 });
  }

  const secret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");
  if (!secret) {
    console.error("REVENUECAT_WEBHOOK_SECRET not configured");
    return new Response(null, { status: 500 });
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  if (authHeader !== `Bearer ${secret}`) {
    console.error("Webhook authorization failed");
    return new Response(null, { status: 401 });
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return new Response(null, { status: 400 });
  }

  const event = body.event as Record<string, unknown> | undefined;
  if (!event) {
    return new Response(null, { status: 400 });
  }

  const eventType = String(event.type ?? "").toUpperCase();
  const appUserId = String(event.app_user_id ?? "").toLowerCase();
  const expirationAtMs = event.expiration_at_ms != null ? Number(event.expiration_at_ms) : null;
  const productId = event.product_id != null ? String(event.product_id) : null;

  if (!appUserId) {
    console.error("Missing app_user_id in webhook event");
    return new Response(null, { status: 400 });
  }

  if (!ACTIVE_EVENTS.has(eventType) && !INACTIVE_EVENTS.has(eventType)) {
    return new Response(null, { status: 200 });
  }

  const isActive = ACTIVE_EVENTS.has(eventType);

  const update: Record<string, unknown> = {
    subscription_status: isActive ? "active" : "inactive",
    updated_at: new Date().toISOString(),
  };
  if (expirationAtMs != null) {
    update.subscription_expires_at = new Date(expirationAtMs).toISOString();
  }
  if (productId != null) {
    update.subscription_product_id = productId;
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  const { error } = await admin
    .from("users")
    .update(update)
    .eq("id", appUserId);

  if (error) {
    console.error("Failed to update subscription status", appUserId, error);
    return new Response(null, { status: 500 });
  }

  console.log(`Subscription updated: user=${appUserId} event=${eventType} status=${isActive ? "active" : "inactive"}`);
  return new Response(null, { status: 200 });
});
