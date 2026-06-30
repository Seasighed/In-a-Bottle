import {
  identityKey,
  isOriginAllowed,
  parseAllowlist,
  parseAllowedOrigins,
  validateSubmissionPayload,
} from "./validation.ts";

const allowlistJson = JSON.stringify({
  surveys: [
    {
      survey_id: "maplestory_pulse",
      template_version: 2,
      schema_hash: "abc123",
    },
  ],
});

Deno.test("accepts an allowlisted survey identity", () => {
  const allowlist = parseAllowlist(allowlistJson);
  const result = validateSubmissionPayload(bundle("maplestory_pulse", 2, "abc123"), allowlist);
  assert(result.ok, "allowlisted survey should pass validation");
  assert(result.identity_key === identityKey("maplestory_pulse", 2, "abc123"), "identity key should include id, version, and schema hash");
});

Deno.test("rejects unknown survey ids", () => {
  const result = validateSubmissionPayload(bundle("custom_survey", 2, "abc123"), parseAllowlist(allowlistJson));
  assert(!result.ok && result.status === 403, "unknown survey should be rejected");
  assert(result.reason === "not_allowlisted", "unknown survey should carry the not-allowlisted reason");
});

Deno.test("rejects wrong schema hashes", () => {
  const result = validateSubmissionPayload(bundle("maplestory_pulse", 2, "wrong"), parseAllowlist(allowlistJson));
  assert(!result.ok && result.status === 403, "wrong schema hash should be rejected");
});

Deno.test("rejects malformed payloads", () => {
  const result = validateSubmissionPayload({ format: "not_it" }, parseAllowlist(allowlistJson));
  assert(!result.ok && result.status === 400, "malformed payload should fail with a 400-class result");
  assert(result.reason === "unsupported_format", "wrong upload formats should carry a specific reason");
});

Deno.test("rejects missing payload hashes", () => {
  const payload = bundle("maplestory_pulse", 2, "abc123");
  delete payload.client_payload_hash;
  const result = validateSubmissionPayload(payload, parseAllowlist(allowlistJson));
  assert(!result.ok && result.reason === "missing_payload_hash", "payload hash should be mandatory");
});

Deno.test("preserves scrub state for storage", () => {
  const result = validateSubmissionPayload(bundle("maplestory_pulse", 2, "abc123", true), parseAllowlist(allowlistJson));
  assert(result.ok, "allowlisted scrubbed survey should pass");
  assert(result.scrub_identifying_info === true, "scrub flag should be preserved");
});

Deno.test("matches configured origins exactly", () => {
  const allowed = parseAllowedOrigins("https://example.com, https://survey.example.com/path");
  assert(isOriginAllowed("https://example.com", allowed), "listed origins should be allowed");
  assert(isOriginAllowed("https://survey.example.com/ignored", allowed), "origin normalization should ignore paths");
  assert(!isOriginAllowed("https://evil.example.com", allowed), "unlisted origins should be blocked");
  assert(isOriginAllowed("", allowed), "server-to-server requests without an Origin should be allowed");
});

function bundle(surveyId: string, version: number, schemaHash: string, scrub = false): Record<string, unknown> {
  return {
    format: "survey_submission_bundle",
    version: 1,
    submitted_at: "2026-06-29T20:00:00Z",
    client_payload_hash: `payload-hash-${surveyId}-${schemaHash}`,
    survey: {
      id: surveyId,
      template_version: version,
      schema_hash: schemaHash,
    },
    client: {
      install_id: "ci-install",
    },
    privacy: {
      scrub_identifying_info: scrub,
    },
    quality: {
      session_duration_seconds: 120,
    },
    responses: [],
  };
}

function assert(condition: boolean, message: string): void {
  if (!condition) {
    throw new Error(message);
  }
}
