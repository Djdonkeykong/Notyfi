import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const OPENAI_API_URL = "https://api.openai.com/v1/chat/completions";
const MODEL = "gpt-4.1-mini";

const INSIGHT_TAGS = [
  "overspending",
  "saving_opportunity",
  "pattern",
  "positive",
] as const;
type InsightTag = (typeof INSIGHT_TAGS)[number];

const SUPPORTED_LANGUAGE_NAMES: Record<string, string> = {
  da: "Danish",
  de: "German",
  en: "English",
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

type CategoryTotal = {
  category: string;
  total: number;
  entryCount: number;
};

type InsightsRequest = {
  monthLabel: string;
  currencyCode: string;
  languageCode: string;
  expenseTotal: number;
  incomeTotal: number;
  budgetLimit: number;
  categoryTotals: CategoryTotal[];
  previousMonthExpenseTotal: number;
  topMerchants: string[];
};

type Insight = {
  id: string;
  headline: string;
  body: string;
  tag: InsightTag;
};

type InsightsResponse = {
  narrative: string;
  insights: Insight[];
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function errorResponse(code: string, message: string, status: number) {
  return jsonResponse({ error: { code, message } }, status);
}

function getBearerToken(req: Request): string | null {
  const [scheme, token] = (req.headers.get("Authorization") ?? "").split(" ");
  return scheme === "Bearer" && token ? token : null;
}

function resolveLanguage(code: string) {
  const normalized = (code ?? "en").toLowerCase();
  const resolved = SUPPORTED_LANGUAGE_NAMES[normalized] ? normalized : "en";
  return { code: resolved, name: SUPPORTED_LANGUAGE_NAMES[resolved] };
}

function insightSchema() {
  return {
    type: "object",
    additionalProperties: false,
    properties: {
      id: { type: "string" },
      headline: { type: "string" },
      body: { type: "string" },
      tag: { type: "string", enum: [...INSIGHT_TAGS] },
    },
    required: ["id", "headline", "body", "tag"],
  };
}

function makeRequestBody(req: InsightsRequest) {
  const lang = resolveLanguage(req.languageCode);
  const categoryLines = [...req.categoryTotals]
    .sort((a, b) => b.total - a.total)
    .map(
      (c) =>
        `  ${c.category}: ${req.currencyCode} ${c.total.toFixed(0)} (${c.entryCount} entries)`
    )
    .join("\n");
  const merchantLine =
    req.topMerchants.length > 0
      ? req.topMerchants.slice(0, 5).join(", ")
      : "none";

  const userContent = `Month: ${req.monthLabel}
Currency: ${req.currencyCode}
Total expenses: ${req.expenseTotal.toFixed(0)}
Total income: ${req.incomeTotal.toFixed(0)}
Monthly budget limit: ${req.budgetLimit > 0 ? req.budgetLimit.toFixed(0) : "not set"}
Previous month expenses: ${req.previousMonthExpenseTotal.toFixed(0)}
Category breakdown:
${categoryLines || "  no data"}
Frequent merchants: ${merchantLine}
Target language: ${lang.name} (${lang.code})

Return a JSON object with:
- "narrative": 2-3 sentences giving an honest, plain-language summary of the month. Reference actual numbers. Write like a trusted advisor, not a chatbot. Do not start with "This month".
- "insights": exactly 3 objects, each with a short headline (max 8 words), a 1-2 sentence body with specific numbers and a concrete suggestion, and a tag (overspending / saving_opportunity / pattern / positive). Do not state the obvious.
Write all natural-language text in ${lang.name}.`;

  return {
    model: MODEL,
    temperature: 0.4,
    messages: [
      {
        role: "system",
        content:
          "You are a sharp personal finance analyst for a budgeting app. Generate concise, data-driven spending analysis. Always write in the requested target language.",
      },
      { role: "user", content: userContent },
    ],
    response_format: {
      type: "json_schema",
      json_schema: {
        name: "notyfi_spending_insights",
        strict: true,
        schema: {
          type: "object",
          additionalProperties: false,
          properties: {
            narrative: { type: "string" },
            insights: {
              type: "array",
              items: insightSchema(),
              minItems: 1,
              maxItems: 3,
            },
          },
          required: ["narrative", "insights"],
        },
      },
    },
  };
}

const INSIGHTS_MONTHLY_LIMIT = 3;

async function checkSubscription(userId: string): Promise<boolean> {
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );
  const { data } = await admin
    .from("users")
    .select("subscription_status")
    .eq("id", userId)
    .maybeSingle();
  return data?.subscription_status === "active";
}

async function enforceInsightsQuota(userId: string): Promise<void> {
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  const currentMonth = new Date().toISOString().slice(0, 7); // "2026-05"

  const { data } = await admin
    .from("users")
    .select("insights_month, insights_month_count")
    .eq("id", userId)
    .maybeSingle();

  const sameMonth = data?.insights_month === currentMonth;
  const count = sameMonth ? (data?.insights_month_count ?? 0) : 0;

  if (count >= INSIGHTS_MONTHLY_LIMIT) {
    throw new Error("insights_rate_limit_exceeded");
  }

  await admin
    .from("users")
    .update({ insights_month: currentMonth, insights_month_count: count + 1 })
    .eq("id", userId);
}

async function callOpenAI(
  body: Record<string, unknown>,
  apiKey: string
): Promise<string> {
  const response = await fetch(OPENAI_API_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const payload = await response.text();
    console.error("OpenAI error", response.status, payload.slice(0, 400));
    throw new Error("openai_request_failed");
  }

  const completion = await response.json();
  const content = completion?.choices?.[0]?.message?.content;
  if (typeof content !== "string" || !content.trim()) {
    throw new Error("empty_model_response");
  }
  return content;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return errorResponse("method_not_allowed", "Method not allowed.", 405);
  }

  const openAIKey = Deno.env.get("OPENAI_API_KEY")?.trim();
  if (!openAIKey) {
    return errorResponse(
      "ai_service_unavailable",
      "AI insights are temporarily unavailable.",
      503
    );
  }

  const token = getBearerToken(req);
  if (!token) {
    return errorResponse("unauthorized", "Missing authorization header.", 401);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    {
      global: {
        headers: { Authorization: req.headers.get("Authorization")! },
      },
    }
  );

  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser(token);

  if (userError || !user) {
    return errorResponse("unauthorized", "Unauthorized.", 401);
  }

  const hasSubscription = await checkSubscription(user.id);
  if (!hasSubscription) {
    return errorResponse("subscription_required", "An active Notyfi Pro subscription is required.", 403);
  }

  try {
    await enforceInsightsQuota(user.id);
  } catch {
    return errorResponse("rate_limit_exceeded", "Monthly insights limit reached. Try again next month.", 429);
  }

  let body: InsightsRequest;
  try {
    body = (await req.json()) as InsightsRequest;
    if (
      !body.monthLabel ||
      !body.currencyCode ||
      !Array.isArray(body.categoryTotals)
    ) {
      throw new Error("invalid_payload");
    }
  } catch {
    return errorResponse("invalid_request", "Invalid request payload.", 400);
  }

  try {
    const content = await callOpenAI(makeRequestBody(body), openAIKey);
    const parsed = JSON.parse(content) as InsightsResponse;
    const result: InsightsResponse = {
      narrative: parsed.narrative ?? "",
      insights: Array.isArray(parsed.insights)
        ? parsed.insights.slice(0, 3)
        : [],
    };
    return jsonResponse(result);
  } catch (error) {
    console.error("spending-insights failed", error);
    return errorResponse(
      "ai_service_unavailable",
      "AI insights are temporarily unavailable.",
      503
    );
  }
});
