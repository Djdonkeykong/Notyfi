import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface DeviceTokenRow {
  user_id: string;
  token: string;
  timezone: string;
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

interface UserContext {
  streak: number;
  loggedYesterday: boolean;
  budgetPct: number | null;
  budgetRemaining: number | null;
  daysLeftInMonth: number;
  currency: string;
  categoryOverTarget: { category: string; ratio: number } | null;
  savedVsTarget: { saved: number; target: number } | null;
  language: string;
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
// User context derivation
// ---------------------------------------------------------------------------

const LANGUAGE_NAMES: Record<string, string> = {
  en: "English",
  da: "Danish",
  de: "German",
  es: "Spanish",
  fi: "Finnish",
  fr: "French",
  it: "Italian",
  nb: "Norwegian",
  nl: "Dutch",
  pl: "Polish",
  pt: "Portuguese",
  sv: "Swedish",
};

function deriveContext(
  user: UserRow,
  plan: BudgetPlanRow | null,
  targets: CategoryTargetRow[],
  entries: EntryRow[],
): UserContext {
  const currency = user.currency_code ?? "USD";
  const language = LANGUAGE_NAMES[user.language_code ?? ""] ?? "English";
  const now = new Date();
  const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
  const daysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
  const daysLeftInMonth = daysInMonth - now.getDate();

  const monthEntries = entries.filter((e) => new Date(e.occurred_at) >= startOfMonth);
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

  // Yesterday
  const yesterday = new Date(now);
  yesterday.setDate(yesterday.getDate() - 1);
  yesterday.setHours(0, 0, 0, 0);
  const loggedYesterday = entries.some((e) => {
    const d = new Date(e.occurred_at);
    d.setHours(0, 0, 0, 0);
    return d.getTime() === yesterday.getTime();
  });

  // Budget
  let budgetPct: number | null = null;
  let budgetRemaining: number | null = null;
  if (plan && plan.monthly_limit > 0) {
    budgetPct = monthExpenses / plan.monthly_limit;
    budgetRemaining = plan.monthly_limit - monthExpenses;
  }

  // Worst category over target
  let categoryOverTarget: { category: string; ratio: number } | null = null;
  for (const target of targets) {
    if (target.target_amount <= 0) continue;
    const spent = monthEntries
      .filter((e) => e.entry_type === "expense" && e.category === target.category)
      .reduce((sum, e) => sum + e.amount, 0);
    const ratio = spent / target.target_amount;
    if (ratio >= 1.1 && (!categoryOverTarget || ratio > categoryOverTarget.ratio)) {
      categoryOverTarget = { category: target.category, ratio };
    }
  }

  // Savings vs target
  let savedVsTarget: { saved: number; target: number } | null = null;
  if (plan && plan.monthly_savings_target > 0) {
    savedVsTarget = { saved: monthIncome - monthExpenses, target: plan.monthly_savings_target };
  }

  return {
    streak,
    loggedYesterday,
    budgetPct,
    budgetRemaining,
    daysLeftInMonth,
    currency,
    categoryOverTarget,
    savedVsTarget,
    language,
  };
}

// ---------------------------------------------------------------------------
// Claude notification generation
// ---------------------------------------------------------------------------

const SYSTEM_PROMPT =
  `You write push notification copy for Notyfi, a personal finance journaling app. ` +
  `Write a short, personal, and varied daily check-in notification based on the user's actual financial context.\n\n` +
  `Rules:\n` +
  `- Title: 2-5 words, punchy and direct\n` +
  `- Body: 8-15 words, warm and conversational\n` +
  `- Never open with "Hey", "Hi", or "Hello"\n` +
  `- Reference specific numbers when available (amounts, streak count, percentages)\n` +
  `- Vary the tone — sometimes motivating, sometimes playful, sometimes a gentle nudge, sometimes matter-of-fact\n` +
  `- Occasionally use a single emoji in the title or body — not every notification, maybe 1 in 3\n` +
  `- Write entirely in the language specified in the context\n` +
  `- Return only valid JSON with no markdown or extra keys: {"title": "...", "body": "..."}`;

async function generateNotification(
  context: UserContext,
  openAIApiKey: string,
): Promise<{ title: string; body: string }> {
  const facts: string[] = [];

  if (context.streak >= 2) {
    facts.push(`Logging streak: ${context.streak} consecutive days`);
  }
  if (!context.loggedYesterday) {
    facts.push("Did not log anything yesterday");
  }
  if (context.budgetPct !== null && context.budgetRemaining !== null) {
    facts.push(
      `Budget: ${Math.round(context.budgetPct * 100)}% used this month, ` +
        `${context.currency} ${Math.round(context.budgetRemaining)} remaining, ` +
        `${context.daysLeftInMonth} days left`,
    );
  }
  if (context.categoryOverTarget) {
    facts.push(
      `${context.categoryOverTarget.category} spending is at ` +
        `${Math.round(context.categoryOverTarget.ratio * 100)}% of monthly guide`,
    );
  }
  if (context.savedVsTarget) {
    const gap = context.savedVsTarget.target - context.savedVsTarget.saved;
    if (gap <= 0) {
      facts.push("Has hit monthly savings goal");
    } else {
      facts.push(
        `${context.currency} ${Math.round(gap)} away from monthly savings goal`,
      );
    }
  }
  if (facts.length === 0) {
    facts.push("No notable financial events this month yet");
  }

  const userMessage =
    `User context:\n${facts.join("\n")}\nLanguage: ${context.language}`;

  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${openAIApiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-4.1-mini",
      max_tokens: 100,
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: userMessage },
      ],
    }),
  });

  if (!res.ok) {
    throw new Error(`OpenAI API error ${res.status}: ${await res.text()}`);
  }

  const json = await res.json();
  const text: string = json.choices?.[0]?.message?.content ?? "";
  return JSON.parse(text);
}

function fallbackNotification(): { title: string; body: string } {
  const pool = [
    { title: "Quick check-in", body: "Any spending today? Tap to log it while it's fresh." },
    { title: "Money notes", body: "The best time to log is right after spending. Second best? Now." },
    { title: "Stay on track", body: "Keeping track takes seconds. Your budget will thank you." },
    { title: "Log your day", body: "Your future self will thank you. Anything to add?" },
    { title: "Open Notyfi", body: "Capture today's spending while it's still fresh in your mind." },
    { title: "Journal time", body: "A quick log now saves a lot of guessing later." },
    { title: "Don't forget", body: "Small habits, big clarity. Take 30 seconds to log today." },
  ];
  return pool[new Date().getDate() % pool.length];
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------

Deno.serve(async (req) => {
  try {
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

    const openAIApiKey = Deno.env.get("OPENAI_API_KEY");
    if (!openAIApiKey) {
      return new Response("OPENAI_API_KEY not set", { status: 500 });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      serviceRoleKey,
    );

    const { data: allTokens, error: tokensErr } = await supabase
      .from("device_tokens")
      .select("user_id, token, timezone");

    if (tokensErr) throw tokensErr;
    if (!allTokens || allTokens.length === 0) {
      return new Response(JSON.stringify({ sent: 0 }), { status: 200 });
    }

    // Only send to users whose local time is currently 20:00 — this matches the
    // hour that FCM covers so local notifications can safely skip it.
    const tokens = (allTokens as DeviceTokenRow[]).filter((t) => {
      try {
        const localHour = parseInt(
          new Intl.DateTimeFormat("en-US", {
            timeZone: t.timezone,
            hour: "2-digit",
            hour12: false,
          }).format(new Date()),
          10,
        );
        return localHour === 20;
      } catch {
        return false;
      }
    });

    if (tokens.length === 0) {
      return new Response(JSON.stringify({ sent: 0, skipped: allTokens.length }), { status: 200 });
    }

    const accessToken = await getFirebaseAccessToken(sa);
    const userIDs = [...new Set((tokens as DeviceTokenRow[]).map((t) => t.user_id))];

    const [usersRes, plansRes, entriesRes] = await Promise.all([
      supabase.from("users").select("id, currency_code, language_code, monthly_budget").in("id", userIDs),
      supabase.from("budget_plans").select("id, user_id, monthly_limit, monthly_savings_target").eq("is_active", true).in("user_id", userIDs),
      supabase.from("expense_entries").select("user_id, amount, entry_type, category, occurred_at").in("user_id", userIDs).gte("occurred_at", new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString()),
    ]);

    const users = (usersRes.data ?? []) as (UserRow & { id: string })[];
    const plans = (plansRes.data ?? []) as (BudgetPlanRow & { user_id: string })[];
    const allEntries = (entriesRes.data ?? []) as (EntryRow & { user_id: string })[];

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

    let sent = 0;
    let failed = 0;

    for (const { user_id, token } of tokens as DeviceTokenRow[]) {
      const user = users.find((u) => u.id === user_id);
      if (!user) continue;

      const plan = plans.find((p) => p.user_id === user_id) ?? null;
      const targets = targetsMap.get(user_id) ?? [];
      const entries = allEntries.filter((e) => e.user_id === user_id);

      const context = deriveContext(user, plan, targets, entries);

      let title: string;
      let body: string;
      try {
        ({ title, body } = await generateNotification(context, openAIApiKey));
      } catch {
        ({ title, body } = fallbackNotification());
      }

      try {
        await sendFCMNotification(accessToken, sa.project_id, token, title, body);
        sent++;
      } catch {
        failed++;
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
