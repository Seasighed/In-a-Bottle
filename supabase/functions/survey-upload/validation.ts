export type UploadAllowlistEntry = {
  survey_id: string;
  template_version: number;
  schema_hash: string;
  label?: string;
};

export type UploadRejectionReason =
  | "malformed_json"
  | "unsupported_format"
  | "missing_identity"
  | "invalid_identity"
  | "missing_payload_hash"
  | "not_allowlisted";

export type UploadValidationResult = {
  ok: boolean;
  status: number;
  reason: UploadRejectionReason | "allowlisted";
  message: string;
  survey_id?: string;
  template_version?: number;
  schema_hash?: string;
  identity_key?: string;
  payload_hash?: string;
  client_install_id?: string;
  scrub_identifying_info?: boolean;
};

export function identityKey(
  surveyId: string,
  templateVersion: number,
  schemaHash: string,
): string {
  return `${surveyId.trim()}::v${Math.max(0, templateVersion)}::${schemaHash.trim()}`;
}

export function parseAllowedOrigins(rawValue: string | undefined | null): string[] {
  const rawText = (rawValue ?? "").trim();
  if (!rawText) {
    return [];
  }
  return rawText
    .split(",")
    .map((value) => normalizeOrigin(value))
    .filter((value) => value.length > 0);
}

export function isOriginAllowed(origin: string | undefined | null, allowedOrigins: string[]): boolean {
  const normalizedOrigin = normalizeOrigin(origin ?? "");
  if (!normalizedOrigin) {
    return true;
  }
  if (allowedOrigins.includes("*")) {
    return true;
  }
  return allowedOrigins.includes(normalizedOrigin);
}

export function parseAllowlist(rawValue: string | undefined | null): UploadAllowlistEntry[] {
  const rawText = (rawValue ?? "").trim();
  if (!rawText) {
    return [];
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(rawText);
  } catch (_error) {
    return [];
  }
  const rawEntries = Array.isArray(parsed)
    ? parsed
    : isRecord(parsed)
    ? (Array.isArray(parsed.surveys) ? parsed.surveys : Array.isArray(parsed.entries) ? parsed.entries : [])
    : [];
  const entries: UploadAllowlistEntry[] = [];
  for (const rawEntry of rawEntries) {
    if (!isRecord(rawEntry)) {
      continue;
    }
    const surveyId = stringValue(rawEntry.survey_id ?? rawEntry.id);
    const templateVersion = numberValue(rawEntry.template_version ?? rawEntry.version);
    const schemaHash = stringValue(rawEntry.schema_hash);
    if (!surveyId || templateVersion <= 0 || !schemaHash) {
      continue;
    }
    entries.push({
      survey_id: surveyId,
      template_version: templateVersion,
      schema_hash: schemaHash,
      label: stringValue(rawEntry.label),
    });
  }
  return entries;
}

export function validateSubmissionPayload(
  payload: unknown,
  allowlist: UploadAllowlistEntry[],
): UploadValidationResult {
  if (!isRecord(payload)) {
    return rejected(400, "malformed_json", "Malformed JSON payload.");
  }
  if (payload.format !== "survey_submission_bundle") {
    return rejected(400, "unsupported_format", "Unsupported upload format.");
  }
  const survey = isRecord(payload.survey) ? payload.survey : undefined;
  if (!survey) {
    return rejected(400, "missing_identity", "Missing survey identity.");
  }
  const surveyId = stringValue(survey.id);
  const templateVersion = numberValue(survey.template_version);
  const schemaHash = stringValue(survey.schema_hash);
  if (!surveyId || templateVersion <= 0 || !schemaHash) {
    return rejected(400, "invalid_identity", "Survey id, template version, and schema hash are required.");
  }
  const payloadHash = stringValue(payload.client_payload_hash ?? payload.payload_hash);
  if (!payloadHash || payloadHash.length < 16) {
    return rejected(400, "missing_payload_hash", "Payload hash is required.");
  }
  const currentIdentity = identityKey(surveyId, templateVersion, schemaHash);
  const allowlisted = allowlist.some((entry) =>
    identityKey(entry.survey_id, entry.template_version, entry.schema_hash) === currentIdentity
  );
  if (!allowlisted) {
    return {
      ok: false,
      status: 403,
      reason: "not_allowlisted",
      message: "Survey identity is not allowlisted for public upload.",
      survey_id: surveyId,
      template_version: templateVersion,
      schema_hash: schemaHash,
      identity_key: currentIdentity,
      payload_hash: payloadHash,
    };
  }
  const client = isRecord(payload.client) ? payload.client : {};
  const privacy = isRecord(payload.privacy) ? payload.privacy : {};
  return {
    ok: true,
    status: 202,
    reason: "allowlisted",
    message: "Survey payload is allowlisted.",
    survey_id: surveyId,
    template_version: templateVersion,
    schema_hash: schemaHash,
    identity_key: currentIdentity,
    payload_hash: payloadHash,
    client_install_id: stringValue(client.install_id),
    scrub_identifying_info: Boolean(privacy.scrub_identifying_info),
  };
}

function rejected(status: number, reason: UploadRejectionReason, message: string): UploadValidationResult {
  return {
    ok: false,
    status,
    reason,
    message,
  };
}

function normalizeOrigin(value: string): string {
  const trimmed = value.trim();
  if (!trimmed || trimmed === "*") {
    return trimmed;
  }
  try {
    const url = new URL(trimmed);
    return url.origin;
  } catch (_error) {
    return trimmed.replace(/\/+$/, "");
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function stringValue(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function numberValue(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === "string" && value.trim()) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? Math.trunc(parsed) : 0;
  }
  return 0;
}
