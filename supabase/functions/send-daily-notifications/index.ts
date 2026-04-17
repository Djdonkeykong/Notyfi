import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface DeviceTokenRow {
  user_id: string;
  token: string;
}

interface UserRow {
  id: string;
  currency_code: string | null;
  language_code: string | null;
  monthly_budget: number | null;
}

interface BudgetPlanRow {
  id: string;
  monthly_limit: number;
  monthly_savings_target: number;
}

interface CategoryTargetRow {
  category: string;
  target_amount: number;
}

interface EntryRow {
  amount: number;
  entry_type: string;
  category: string | null;
  occurred_at: string;
}

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

// ---------------------------------------------------------------------------
// Firebase access token via service account JWT
// ---------------------------------------------------------------------------

async function getFirebaseAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const encode = (obj: object) =>
    btoa(JSON.stringify(obj))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");

  const signingInput = `${encode(header)}.${encode(payload)}`;

  const privateKey = await importPrivateKey(sa.private_key);
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    privateKey,
    new TextEncoder().encode(signingInput),
  );

  const sig = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

  const jwt = `${signingInput}.${sig}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const json = await res.json();
  if (!json.access_token) throw new Error(`OAuth failed: ${JSON.stringify(json)}`);
  return json.access_token;
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const pemContents = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\n/g, "");

  const binaryDer = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  return crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

// ---------------------------------------------------------------------------
// FCM send
// ---------------------------------------------------------------------------

async function sendFCMNotification(
  accessToken: string,
  projectId: string,
  fcmToken: string,
  title: string,
  body: string,
): Promise<void> {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: fcmToken,
          notification: { title, body },
          apns: {
            payload: { aps: { sound: "default" } },
          },
        },
      }),
    },
  );

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`FCM error ${res.status}: ${err}`);
  }
}

// ---------------------------------------------------------------------------
// Message selection
// ---------------------------------------------------------------------------

function pickMessage(
  user: UserRow,
  plan: BudgetPlanRow | null,
  targets: CategoryTargetRow[],
  entries: EntryRow[],
): { title: string; body: string } {
  const currency = user.currency_code ?? "USD";
  const now = new Date();
  const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
  const daysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
  const daysLeft = daysInMonth - now.getDate();

  const monthEntries = entries.filter(
    (e) => new Date(e.occurred_at) >= startOfMonth,
  );
  const monthExpenses = monthEntries
    .filter((e) => e.entry_type === "expense")
    .reduce((sum, e) => sum + e.amount, 0);
  const monthIncome = monthEntries
    .filter((e) => e.entry_type === "income")
    .reduce((sum, e) => sum + e.amount, 0);

  // Streak
  let streak = 0;
  let checkDate = new Date(now);
  checkDate.setHours(0, 0, 0, 0);
  while (true) {
    const hasEntry = entries.some((e) => {
      const d = new Date(e.occurred_at);
      d.setHours(0, 0, 0, 0);
      return d.getTime() === checkDate.getTime();
    });
    if (!hasEntry) break;
    streak++;
    checkDate.setDate(checkDate.getDate() - 1);
  }

  // Budget status
  if (plan && plan.monthly_limit > 0) {
    const pct = monthExpenses / plan.monthly_limit;
    const remaining = plan.monthly_limit - monthExpenses;
    const fmt = (n: number) => `${currency} ${n.toFixed(0)}`;

    if (pct >= 0.9) {
      return {
        title: "Budget nearly gone",
        body: `${Math.round(pct * 100)}% used this month. Only ${fmt(remaining)} left.`,
      };
    }

    if (pct >= 0.7) {
      return {
        title: "Budget check",
        body: `${Math.round(pct * 100)}% of your budget used. ${fmt(remaining)} left over ${daysLeft} days.`,
      };
    }
  }

  // Savings target
  if (plan && plan.monthly_savings_target > 0) {
    const saved = monthIncome - monthExpenses;
    const gap = plan.monthly_savings_target - saved;
    if (gap <= 0) {
      return {
        title: "Savings goal hit",
        body: "You've hit your savings target this month. Nice work.",
      };
    }
  }

  // Category over target
  for (const target of targets) {
    if (target.target_amount <= 0) continue;
    const spent = monthEntries
      .filter((e) => e.entry_type === "expense" && e.category === target.category)
      .reduce((sum, e) => sum + e.amount, 0);
    const ratio = spent / target.target_amount;
    if (ratio >= 1.1) {
      return {
        title: `${target.category} over target`,
        body: `You're at ${Math.round(ratio * 100)}% of your ${target.category} guide this month.`,
      };
    }
  }

  // Streak
  if (streak >= 3) {
    return {
      title: `${streak} days in a row`,
      body: "You've been consistent. Keep the streak alive today.",
    };
  }

  // Missed yesterday
  const yesterday = new Date(now);
  yesterday.setDate(yesterday.getDate() - 1);
  yesterday.setHours(0, 0, 0, 0);
  const loggedYesterday = entries.some((e) => {
    const d = new Date(e.occurred_at);
    d.setHours(0, 0, 0, 0);
    return d.getTime() === yesterday.getTime();
  });
  if (!loggedYesterday) {
    return {
      title: "Yesterday unlogged",
      body: "Nothing logged for yesterday — want to add anything from memory?",
    };
  }

  // Generic fallback pool — rotate by day of month for variety
  const generics = [
    { title: "Quick check-in", body: "Any spending today? Tap to log it while it's fresh." },
    { title: "Money notes", body: "The best time to log is right after spending. Second best? Now." },
    { title: "Stay on track", body: "Keeping track takes seconds. Your budget will thank you." },
    { title: "Log your day", body: "Your future self will thank you. Anything to add?" },
    { title: "Open Notyfi", body: "Capture today's spending while it's still fresh in your mind." },
    { title: "Journal time", body: "A quick log now saves a lot of guessing later." },
    { title: "Don't forget", body: "Small habits, big clarity. Take 30 seconds to log today." },
  ];

  return generics[now.getDate() % generics.length];
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------

Deno.serve(async (req) => {
  try {
    // Allow cron invocations (no auth header) or explicit calls with the service role key
    const authHeader = req.headers.get("Authorization") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const isCron = req.headers.get("x-supabase-cron") === "1";

    if (!isCron && authHeader !== `Bearer ${serviceRoleKey}`) {
      return new Response("Unauthorized", { status: 401 });
    }

    const saJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
    if (!saJson) {
      return new Response("FIREBASE_SERVICE_ACCOUNT_JSON not set", { status: 500 });
    }
    const sa: ServiceAccount = JSON.parse(saJson);

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      serviceRoleKey,
    );

    // Fetch all device tokens
    const { data: tokens, error: tokensErr } = await supabase
      .from("device_tokens")
      .select("user_id, token");

    if (tokensErr) throw tokensErr;
    if (!tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ sent: 0 }), { status: 200 });
    }

    const accessToken = await getFirebaseAccessToken(sa);
    const userIDs = [...new Set((tokens as DeviceTokenRow[]).map((t) => t.user_id))];

    // Fetch all user data in bulk
    const [usersRes, plansRes, entriesRes] = await Promise.all([
      supabase.from("users").select("id, currency_code, language_code, monthly_budget").in("id", userIDs),
      supabase.from("budget_plans").select("id, user_id, monthly_limit, monthly_savings_target").eq("is_active", true).in("user_id", userIDs),
      supabase.from("expense_entries").select("user_id, amount, entry_type, category, occurred_at").in("user_id", userIDs).gte("occurred_at", new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString()),
    ]);

    const users = (usersRes.data ?? []) as (UserRow & { id: string })[];
    const plans = (plansRes.data ?? []) as (BudgetPlanRow & { user_id: string })[];
    const allEntries = (entriesRes.data ?? []) as (EntryRow & { user_id: string })[];

    // Fetch category targets for each active plan
    const planIDs = plans.map((p) => p.id);
    const { data: allTargets } = planIDs.length > 0
      ? await supabase.from("budget_category_targets").select("plan_id, user_id, category, target_amount").in("plan_id", planIDs)
      : { data: [] };

    const targetsMap = new Map<string, CategoryTargetRow[]>();
    for (const t of (allTargets ?? []) as (CategoryTargetRow & { user_id: string })[]) {
      const existing = targetsMap.get(t.user_id) ?? [];
      existing.push(t);
      targetsMap.set(t.user_id, existing);
    }

    // Send one notification per token
    let sent = 0;
    let failed = 0;

    for (const { user_id, token } of tokens as DeviceTokenRow[]) {
      const user = users.find((u) => u.id === user_id);
      if (!user) continue;

      const plan = plans.find((p) => p.user_id === user_id) ?? null;
      const targets = targetsMap.get(user_id) ?? [];
      const entries = allEntries.filter((e) => e.user_id === user_id);

      const { title, body } = pickMessage(user, plan, targets, entries);

      try {
        await sendFCMNotification(accessToken, sa.project_id, token, title, body);
        sent++;
      } catch {
        failed++;
        // Remove stale tokens that FCM rejects
      }
    }

    return new Response(JSON.stringify({ sent, failed }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(String(err), { status: 500 });
  }
});
