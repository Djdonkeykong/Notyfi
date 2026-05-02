import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const OPENAI_API_URL = "https://api.openai.com/v1/chat/completions";
const TEXT_MODEL = "gpt-4.1-mini";
const IMAGE_MODEL = "gpt-4.1";
const MAX_TEXT_LENGTH = 4000;
const MAX_IMAGE_BYTES = 6 * 1024 * 1024;

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

const CATEGORIES = [
  "food",
  "groceries",
  "transport",
  "housing",
  "travel",
  "shopping",
  "bills",
  "health",
  "social",
  "entertainment",
  "uncategorized",
] as const;

const TRANSACTION_KINDS = ["expense", "income"] as const;
const CONFIDENCE_VALUES = ["certain", "review", "uncertain"] as const;
const RECURRING_FREQUENCIES = ["weekly", "monthly", "yearly"] as const;

type ParseRequest =
  | {
      kind: "text";
      rawText: string;
      date: string;
      currencyCode: string;
      targetLanguageCode?: string | null;
    }
  | {
      kind: "image";
      imageBase64: string;
      mimeType: string;
      date: string;
      currencyCode: string;
      targetLanguageCode?: string | null;
    };

type ParsedExpenseDraft = {
  rawText: string;
  title: string;
  amount: number;
  currencyCode: string;
  transactionKind: (typeof TRANSACTION_KINDS)[number];
  category: (typeof CATEGORIES)[number];
  merchant: string | null;
  note: string;
  confidence: (typeof CONFIDENCE_VALUES)[number];
  isAmountEstimated: boolean;
  isRecurring: boolean;
  recurringFrequency: (typeof RECURRING_FREQUENCIES)[number] | null;
};

type TextParseResponse = { entry: ParsedExpenseDraft };
type ImageParseResponse = { entries: ParsedExpenseDraft[] };

function jsonResponse(body: unknown, status = 200, headers?: HeadersInit) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...headers,
    },
  });
}

function errorResponse(
  code: string,
  message: string,
  status: number,
  headers?: HeadersInit
) {
  return jsonResponse({ error: { code, message } }, status, headers);
}

function getBearerToken(req: Request) {
  const authHeader = req.headers.get("Authorization") ?? "";
  const [scheme, token] = authHeader.split(" ");
  if (scheme !== "Bearer" || !token) {
    return null;
  }
  return token;
}

function resolveLanguageContext(languageCode?: string | null) {
  const normalizedCode = (languageCode ?? "en").toLowerCase();
  const code = SUPPORTED_LANGUAGE_NAMES[normalizedCode] ? normalizedCode : "en";
  return {
    code,
    name: SUPPORTED_LANGUAGE_NAMES[code],
  };
}

function normalizeCurrencyCode(value: string) {
  const normalized = value.trim().toUpperCase();
  if (!/^[A-Z]{3}$/.test(normalized)) {
    throw new Error("invalid_currency_code");
  }
  return normalized;
}

function normalizeDate(value: string) {
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new Error("invalid_date");
  }
  return parsed.toISOString();
}

function parseRequestPayload(payload: unknown): ParseRequest {
  if (!payload || typeof payload !== "object") {
    throw new Error("invalid_payload");
  }

  const candidate = payload as Record<string, unknown>;
  const kind = candidate.kind;
  if (kind !== "text" && kind !== "image") {
    throw new Error("invalid_payload");
  }

  const date = normalizeDate(String(candidate.date ?? ""));
  const currencyCode = normalizeCurrencyCode(String(candidate.currencyCode ?? ""));
  const targetLanguageCode =
    candidate.targetLanguageCode == null
      ? null
      : String(candidate.targetLanguageCode);

  if (kind === "text") {
    const rawText = String(candidate.rawText ?? "").trim();
    if (!rawText || rawText.length > MAX_TEXT_LENGTH) {
      throw new Error("invalid_text");
    }

    return {
      kind,
      rawText,
      date,
      currencyCode,
      targetLanguageCode,
    };
  }

  const imageBase64 = String(candidate.imageBase64 ?? "").trim();
  const mimeType = String(candidate.mimeType ?? "").trim().toLowerCase();
  if (!imageBase64 || !["image/jpeg", "image/png", "image/webp"].includes(mimeType)) {
    throw new Error("invalid_image");
  }

  const estimatedBytes = Math.floor((imageBase64.length * 3) / 4);
  if (estimatedBytes <= 0 || estimatedBytes > MAX_IMAGE_BYTES) {
    throw new Error("image_too_large");
  }

  return {
    kind,
    imageBase64,
    mimeType,
    date,
    currencyCode,
    targetLanguageCode,
  };
}

function parsedExpenseDraftSchema() {
  return {
    type: "object",
    additionalProperties: false,
    properties: {
      rawText: { type: "string" },
      title: { type: "string" },
      amount: { type: "number" },
      currencyCode: { type: "string" },
      transactionKind: {
        type: "string",
        enum: [...TRANSACTION_KINDS],
      },
      category: {
        type: "string",
        enum: [...CATEGORIES],
      },
      merchant: {
        anyOf: [{ type: "string" }, { type: "null" }],
      },
      note: { type: "string" },
      confidence: {
        type: "string",
        enum: [...CONFIDENCE_VALUES],
      },
      isAmountEstimated: { type: "boolean" },
      isRecurring: { type: "boolean" },
      recurringFrequency: {
        anyOf: [
          {
            type: "string",
            enum: [...RECURRING_FREQUENCIES],
          },
          { type: "null" },
        ],
      },
    },
    required: [
      "rawText",
      "title",
      "amount",
      "currencyCode",
      "transactionKind",
      "category",
      "merchant",
      "note",
      "confidence",
      "isAmountEstimated",
      "isRecurring",
      "recurringFrequency",
    ],
  };
}

function sanitizeDraft(
  draft: ParsedExpenseDraft,
  fallbackRawText: string,
  fallbackCurrencyCode: string
): ParsedExpenseDraft {
  const trimmedTitle = draft.title.trim();
  const trimmedRawText = draft.rawText.trim();
  const fallbackText = fallbackRawText.trim();

  return {
    rawText: trimmedRawText || trimmedTitle || fallbackText,
    title: trimmedTitle || fallbackText,
    amount: Math.max(0, Number(draft.amount) || 0),
    currencyCode: /^[A-Z]{3}$/.test(draft.currencyCode)
      ? draft.currencyCode
      : fallbackCurrencyCode,
    transactionKind: draft.transactionKind,
    category: draft.category,
    merchant: draft.merchant?.trim() || null,
    note: draft.note.trim(),
    confidence: draft.confidence,
    isAmountEstimated: Boolean(draft.isAmountEstimated),
    isRecurring: Boolean(draft.isRecurring),
    recurringFrequency: draft.isRecurring
      ? draft.recurringFrequency ?? "monthly"
      : null,
  };
}

function makeTextRequestBody(payload: Extract<ParseRequest, { kind: "text" }>) {
  const language = resolveLanguageContext(payload.targetLanguageCode);
  const userContent = `Note: ${payload.rawText}
Date: ${payload.date}
Currency: ${payload.currencyCode}
Target language: ${language.name} (${language.code})

Return one transaction JSON object. Infer a short title, amount as a positive number, transactionKind as expense/income, one allowed category, merchant if explicit, note as "" unless useful, confidence as certain/review/uncertain, isAmountEstimated as true/false, and recurrence intent.
All natural-language fields must be written in ${language.name}. Do not write English unless the target language is English.
Write title and note in the target language above. Keep merchant in its original spelling when it is a brand or proper name.
Keep transactionKind, category, confidence, recurrence, and boolean fields as schema values.
Use transactionKind "income" for salary, freelance pay, refunds, reimbursements, gifts received, or money coming in. Use "expense" for spending, bills, purchases, subscriptions, or money going out.
Set isRecurring true when the note explicitly says recurring, monthly, weekly, yearly, every month, every week, every year, or otherwise clearly describes a repeating income or expense.
When isRecurring is true, recurringFrequency must be one of weekly, monthly, or yearly.
If the note says something repeats but does not include a cadence, default recurringFrequency to monthly.
If the note does not indicate recurrence, set isRecurring false and recurringFrequency null.
If no amount is written but the note mentions a concrete item/place, estimate a plausible amount in the given currency, set confidence "review", and set isAmountEstimated true. If there is not enough context to estimate, use amount 0, confidence "review", and isAmountEstimated false.`;

  return {
    model: TEXT_MODEL,
    temperature: 0,
    messages: [
      {
        role: "system",
        content:
          "You convert personal finance notes into strict transaction JSON for a budgeting app. Always write natural-language output fields in the requested target language.",
      },
      {
        role: "user",
        content: userContent,
      },
    ],
    response_format: {
      type: "json_schema",
      json_schema: {
        name: "notyfi_transaction_parse",
        strict: true,
        schema: parsedExpenseDraftSchema(),
      },
    },
  };
}

function makeImageRequestBody(payload: Extract<ParseRequest, { kind: "image" }>) {
  const language = resolveLanguageContext(payload.targetLanguageCode);
  const imageDataURL = `data:${payload.mimeType};base64,${payload.imageBase64}`;
  const userPrompt = `Analyze this personal-finance photo and return one or more transaction JSON objects.
Date context: ${payload.date}
Default currency: ${payload.currencyCode}
Target language: ${language.name} (${language.code})

Rules:
- Return one entry per distinct money movement visible in the image.
- A receipt, invoice, utility bill, order confirmation, brokerage trade, bank transfer, or payment confirmation is usually one entry.
- If the image clearly contains multiple separate purchases, bills, trades, or transfers, return multiple entries.
- Do not split a single receipt or bill into separate line-item transactions unless the image clearly shows separate payments.
- rawText should be a concise journal note the user could have typed manually.
- title should be short and clean.
- amount must be positive.
- Use the visible currency when explicit, otherwise use the default currency.
- Use category uncategorized when no listed category fits well, including stock purchases or investment-related documents.
- Use note for useful extra context from the image, such as billing period, share count, ticker, provider, or order details.
- If any detail is unclear, keep the entry but lower confidence to review or uncertain.
- All natural-language fields must be written in ${language.name}. Do not write English unless the target language is English.
- Write rawText, title, and note in the target language above.
- Keep merchant in its original spelling when it is a brand or proper name.
- Only set isRecurring true when the image clearly indicates a repeating charge or income, such as a subscription, recurring invoice, monthly plan, annual fee, or repeating paycheck.
- When isRecurring is true, recurringFrequency must be weekly, monthly, or yearly. If the document looks recurring but does not say how often, default recurringFrequency to monthly.
- If recurrence is unclear, set isRecurring false and recurringFrequency null.`;

  return {
    model: IMAGE_MODEL,
    temperature: 0,
    messages: [
      {
        role: "system",
        content:
          "You convert finance-related photos into strict transaction JSON for a budgeting app. Always write natural-language output fields in the requested target language.",
      },
      {
        role: "user",
        content: [
          {
            type: "text",
            text: userPrompt,
          },
          {
            type: "image_url",
            image_url: {
              url: imageDataURL,
              detail: "high",
            },
          },
        ],
      },
    ],
    response_format: {
      type: "json_schema",
      json_schema: {
        name: "notyfi_image_transaction_parse",
        strict: true,
        schema: {
          type: "object",
          additionalProperties: false,
          properties: {
            entries: {
              type: "array",
              items: parsedExpenseDraftSchema(),
            },
          },
          required: ["entries"],
        },
      },
    },
  };
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
    console.error("OpenAI error", response.status, payload.slice(0, 600));
    throw new Error("openai_request_failed");
  }

  const completion = await response.json();
  const content = completion?.choices?.[0]?.message?.content;
  if (typeof content !== "string" || !content.trim()) {
    throw new Error("empty_model_response");
  }

  return content;
}

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

async function enforceQuota(userId: string, requestKind: "text" | "image", ip: string | null) {
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  const { data, error } = await admin.rpc("consume_ai_parse_quota", {
    p_user_id: userId,
    p_request_kind: requestKind,
    p_ip: ip,
  });

  if (error) {
    console.error("Quota RPC failed", error);
    throw new Error("quota_check_failed");
  }

  const quotaRow = Array.isArray(data) ? data[0] : data;
  if (!quotaRow?.allowed) {
    return {
      allowed: false,
      retryAfterSeconds: Number(quotaRow?.retry_after_seconds) || 60,
    };
  }

  return {
    allowed: true,
    retryAfterSeconds: 0,
  };
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return errorResponse("method_not_allowed", "Method not allowed.", 405);
  }

  const openAIKey = Deno.env.get("OPENAI_API_KEY")?.trim();
  if (!openAIKey) {
    return errorResponse(
      "ai_service_unavailable",
      "AI parsing is temporarily unavailable right now.",
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
        headers: {
          Authorization: req.headers.get("Authorization")!,
        },
      },
    }
  );

  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser(token);

  if (userError || !user) {
    console.error("Auth lookup failed", userError);
    return errorResponse("unauthorized", "Unauthorized.", 401);
  }

  const hasSubscription = await checkSubscription(user.id);
  if (!hasSubscription) {
    return errorResponse("subscription_required", "An active Notyfi Pro subscription is required.", 403);
  }

  let payload: ParseRequest;
  try {
    payload = parseRequestPayload(await req.json());
  } catch (error) {
    console.error("Invalid parse request", error);
    return errorResponse("invalid_request", "Invalid parse request.", 400);
  }

  const forwardedFor = req.headers.get("x-forwarded-for");
  try {
    const quota = await enforceQuota(user.id, payload.kind, forwardedFor);
    if (!quota.allowed) {
      return errorResponse(
        "rate_limit_exceeded",
        "AI assist is temporarily unavailable right now. Please try again later.",
        429,
        {
          "Retry-After": String(quota.retryAfterSeconds),
        }
      );
    }

    if (payload.kind === "text") {
      const content = await callOpenAI(makeTextRequestBody(payload), openAIKey);
      const parsed = JSON.parse(content) as ParsedExpenseDraft;
      const sanitized = sanitizeDraft(parsed, payload.rawText, payload.currencyCode);
      const response: TextParseResponse = { entry: sanitized };
      return jsonResponse(response);
    }

    const content = await callOpenAI(makeImageRequestBody(payload), openAIKey);
    const parsed = JSON.parse(content) as ImageParseResponse;
    const entries = Array.isArray(parsed.entries)
      ? parsed.entries.map((draft) =>
          sanitizeDraft(draft, draft.title, payload.currencyCode)
        )
      : [];

    if (!entries.length) {
      return errorResponse("no_transactions_found", "No transactions found.", 422);
    }

    const response: ImageParseResponse = { entries };
    return jsonResponse(response);
  } catch (error) {
    console.error("parse-expense failed", error);
    if (error instanceof Error && error.message === "empty_model_response") {
      return errorResponse(
        "empty_model_response",
        "AI parsing is temporarily unavailable right now.",
        502
      );
    }

    return errorResponse(
      "ai_service_unavailable",
      "AI parsing is temporarily unavailable right now.",
      503
    );
  }
});
