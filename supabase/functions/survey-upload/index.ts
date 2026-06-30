import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import {
  isOriginAllowed,
  parseAllowlist,
  parseAllowedOrigins,
  validateSubmissionPayload,
} from "./validation.ts";

const ENDPOINT_VERSION = "survey-upload-v1";
const DEFAULT_MAX_UPLOADS_PER_INSTALL_PER_DAY = 5;
type SurveySupabaseClient = SupabaseClient<any, "public", any>;

serve(async (request: Request) => {
  const allowedOrigins = parseAllowedOrigins(Deno.env.get("SURVEY_UPLOAD_ALLOWED_ORIGINS"));
  if (!isOriginAllowed(request.headers.get("origin"), allowedOrigins)) {
    return jsonResponse(request, 403, {
      accepted: false,
      response_id: null,
      survey_id: null,
      reason: "cors_not_allowed",
      endpoint_version: ENDPOINT_VERSION,
      message: "This origin is not allowed to upload survey responses.",
    }, allowedOrigins);
  }

  if (request.method === "OPTIONS") {
    return jsonResponse(request, 200, {
      accepted: false,
      reason: "preflight",
      endpoint_version: ENDPOINT_VERSION,
      message: "OK",
    }, allowedOrigins);
  }
  if (request.method !== "POST") {
    return jsonResponse(request, 405, {
      accepted: false,
      response_id: null,
      survey_id: null,
      reason: "method_not_allowed",
      endpoint_version: ENDPOINT_VERSION,
      message: "Use POST /survey-upload.",
    }, allowedOrigins);
  }
  const contentType = request.headers.get("content-type") ?? "";
  if (!contentType.toLowerCase().includes("application/json")) {
    return jsonResponse(request, 415, {
      accepted: false,
      response_id: null,
      survey_id: null,
      reason: "unsupported_media_type",
      endpoint_version: ENDPOINT_VERSION,
      message: "Only application/json uploads are accepted.",
    }, allowedOrigins);
  }

  let payload: unknown;
  try {
    payload = await request.json();
  } catch (_error) {
    return jsonResponse(request, 400, {
      accepted: false,
      response_id: null,
      survey_id: null,
      reason: "malformed_json",
      endpoint_version: ENDPOINT_VERSION,
      message: "Malformed JSON payload.",
    }, allowedOrigins);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const client = supabaseUrl && serviceRoleKey
    ? createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    })
    : null;

  const allowlist = parseAllowlist(Deno.env.get("SURVEY_UPLOAD_ALLOWLIST_JSON"));
  const validation = validateSubmissionPayload(payload, allowlist);
  if (!validation.ok) {
    await recordRejection(client, request, validation.reason, validation.message, validation);
    return jsonResponse(request, validation.status, {
      accepted: false,
      response_id: null,
      survey_id: validation.survey_id ?? null,
      reason: validation.reason,
      endpoint_version: ENDPOINT_VERSION,
      message: validation.message,
    }, allowedOrigins);
  }

  if (!client) {
    return jsonResponse(request, 500, {
      accepted: false,
      response_id: null,
      survey_id: validation.survey_id,
      reason: "storage_not_configured",
      endpoint_version: ENDPOINT_VERSION,
      message: "Survey upload storage is not configured.",
    }, allowedOrigins);
  }

  const duplicate = await client
    .from("survey_responses")
    .select("response_id")
    .eq("survey_id", validation.survey_id)
    .eq("template_version", validation.template_version)
    .eq("schema_hash", validation.schema_hash)
    .eq("payload_hash", validation.payload_hash)
    .maybeSingle();
  if (duplicate.error) {
    await recordRejection(client, request, "duplicate_check_failed", duplicate.error.message, validation);
    return jsonResponse(request, 500, {
      accepted: false,
      response_id: null,
      survey_id: validation.survey_id,
      reason: "duplicate_check_failed",
      endpoint_version: ENDPOINT_VERSION,
      message: `Duplicate check failed: ${duplicate.error.message}`,
    }, allowedOrigins);
  }
  if (duplicate.data?.response_id) {
    await recordRejection(client, request, "duplicate_payload", "This response payload has already been uploaded.", validation);
    return jsonResponse(request, 409, {
      accepted: false,
      response_id: duplicate.data.response_id,
      survey_id: validation.survey_id,
      reason: "duplicate_payload",
      endpoint_version: ENDPOINT_VERSION,
      message: "This response payload has already been uploaded.",
    }, allowedOrigins);
  }

  const rateLimit = await rateLimitForInstall(client, validation.client_install_id ?? "");
  if (!rateLimit.ok) {
    await recordRejection(client, request, "rate_limited", rateLimit.message, validation);
    return jsonResponse(request, 429, {
      accepted: false,
      response_id: null,
      survey_id: validation.survey_id,
      reason: "rate_limited",
      endpoint_version: ENDPOINT_VERSION,
      message: rateLimit.message,
    }, allowedOrigins);
  }

  const record = {
    survey_id: validation.survey_id,
    template_version: validation.template_version,
    schema_hash: validation.schema_hash,
    payload_hash: validation.payload_hash,
    client_install_id: validation.client_install_id ?? "",
    submitted_at: submittedAtFromPayload(payload),
    quality_metadata: recordValue(payload, "quality") ?? {},
    scrub_identifying_info: validation.scrub_identifying_info ?? false,
    volunteered_profile: recordValue(payload, "volunteered_profile"),
    raw_payload: payload,
  };

  const insert = await client
    .from("survey_responses")
    .insert(record)
    .select("response_id")
    .single();
  if (insert.error) {
    await recordRejection(client, request, "storage_error", insert.error.message, validation);
    return jsonResponse(request, 500, {
      accepted: false,
      response_id: null,
      survey_id: validation.survey_id,
      reason: "storage_error",
      endpoint_version: ENDPOINT_VERSION,
      message: `Upload storage failed: ${insert.error.message}`,
    }, allowedOrigins);
  }

  return jsonResponse(request, 201, {
    accepted: true,
    response_id: insert.data.response_id,
    survey_id: validation.survey_id,
    reason: "accepted",
    endpoint_version: ENDPOINT_VERSION,
    message: "Survey response accepted for private intake.",
  }, allowedOrigins);
});

function jsonResponse(
  request: Request,
  status: number,
  payload: Record<string, unknown>,
  allowedOrigins: string[],
): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeadersForRequest(request, allowedOrigins),
      "content-type": "application/json; charset=utf-8",
    },
  });
}

function corsHeadersForRequest(request: Request, allowedOrigins: string[]): Record<string, string> {
  const origin = request.headers.get("origin") ?? "";
  const headers: Record<string, string> = {
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
  if (!origin) {
    headers["Access-Control-Allow-Origin"] = "*";
  } else if (allowedOrigins.includes("*")) {
    headers["Access-Control-Allow-Origin"] = "*";
  } else if (isOriginAllowed(origin, allowedOrigins)) {
    headers["Access-Control-Allow-Origin"] = new URL(origin).origin;
  }
  return headers;
}

async function rateLimitForInstall(client: SurveySupabaseClient, installId: string): Promise<{ ok: boolean; message: string }> {
  const normalizedInstallId = installId.trim();
  if (!normalizedInstallId) {
    return { ok: true, message: "" };
  }
  const maxPerDay = numberFromEnv("SURVEY_UPLOAD_MAX_PER_INSTALL_PER_DAY", DEFAULT_MAX_UPLOADS_PER_INSTALL_PER_DAY);
  if (maxPerDay <= 0) {
    return { ok: true, message: "" };
  }
  const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const result = await client
    .from("survey_responses")
    .select("response_id", { count: "exact", head: true })
    .eq("client_install_id", normalizedInstallId)
    .gte("created_at", since);
  if (result.error) {
    return { ok: false, message: `Upload rate-limit check failed: ${result.error.message}` };
  }
  const currentCount = result.count ?? 0;
  if (currentCount >= maxPerDay) {
    return { ok: false, message: "This device has reached the daily upload limit. Save a local copy and try again later." };
  }
  return { ok: true, message: "" };
}

async function recordRejection(
  client: SurveySupabaseClient | null,
  request: Request,
  reason: string,
  message: string,
  validation: {
    survey_id?: string;
    template_version?: number;
    schema_hash?: string;
    payload_hash?: string;
    client_install_id?: string;
  },
): Promise<void> {
  if (!client) {
    return;
  }
  await client.from("survey_upload_rejections").insert({
    survey_id: validation.survey_id ?? null,
    template_version: validation.template_version ?? null,
    schema_hash: validation.schema_hash ?? null,
    payload_hash: validation.payload_hash ?? null,
    client_install_id: validation.client_install_id ?? "",
    reason,
    message,
    endpoint_version: ENDPOINT_VERSION,
    origin: request.headers.get("origin") ?? "",
  });
}

function numberFromEnv(key: string, fallback: number): number {
  const rawValue = Deno.env.get(key) ?? "";
  const parsed = Number(rawValue);
  return Number.isFinite(parsed) ? Math.trunc(parsed) : fallback;
}

function recordValue(payload: unknown, key: string): Record<string, unknown> | null {
  if (typeof payload !== "object" || payload === null || Array.isArray(payload)) {
    return null;
  }
  const value = (payload as Record<string, unknown>)[key];
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return null;
  }
  return value as Record<string, unknown>;
}

function submittedAtFromPayload(payload: unknown): string {
  if (typeof payload !== "object" || payload === null || Array.isArray(payload)) {
    return new Date().toISOString();
  }
  const submittedAt = (payload as Record<string, unknown>).submitted_at;
  return typeof submittedAt === "string" && submittedAt.trim() ? submittedAt : new Date().toISOString();
}
