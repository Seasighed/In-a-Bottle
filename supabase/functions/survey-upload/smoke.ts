type SmokeCase = {
  name: string;
  expectedStatus: number;
  body: string;
  contentType?: string;
};

const endpoint = requiredEnv("SURVEY_UPLOAD_ENDPOINT");
const schemaHash = requiredEnv("MAPLESTORY_PULSE_SCHEMA_HASH");
const writeOk = (Deno.env.get("SURVEY_UPLOAD_SMOKE_WRITE_OK") ?? "").toLowerCase() === "true";
const authHeader = Deno.env.get("SURVEY_UPLOAD_AUTH_HEADER") ?? "";
const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const smokeId = new Date().toISOString().replace(/[-:.TZ]/g, "").slice(0, 14);

if (!writeOk) {
  throw new Error("Set SURVEY_UPLOAD_SMOKE_WRITE_OK=true before running live smoke tests that create private intake rows.");
}

const accepted = bundle("maplestory_pulse", schemaHash, `smoke-${smokeId}-accepted`, false);
const scrubbed = bundle("maplestory_pulse", schemaHash, `smoke-${smokeId}-scrubbed`, true);

const cases: SmokeCase[] = [
  { name: "accepted allowlisted survey", expectedStatus: 201, body: JSON.stringify(accepted) },
  { name: "duplicate payload", expectedStatus: 409, body: JSON.stringify(accepted) },
  { name: "scrubbed identifying answers", expectedStatus: 201, body: JSON.stringify(scrubbed) },
  { name: "rejected custom survey", expectedStatus: 403, body: JSON.stringify(bundle("custom_survey", schemaHash, `smoke-${smokeId}-custom`, false)) },
  { name: "rejected wrong schema hash", expectedStatus: 403, body: JSON.stringify(bundle("maplestory_pulse", "wrong-schema-hash", `smoke-${smokeId}-wrong-schema`, false)) },
  { name: "malformed json", expectedStatus: 400, body: "{", contentType: "application/json" },
];

for (const testCase of cases) {
  const response = await fetch(endpoint, {
    method: "POST",
    headers: requestHeaders(testCase.contentType ?? "application/json"),
    body: testCase.body,
  });
  const responseText = await response.text();
  if (response.status !== testCase.expectedStatus) {
    throw new Error(`${testCase.name}: expected HTTP ${testCase.expectedStatus}, got ${response.status}\n${responseText}`);
  }
  console.log(`${testCase.name}: HTTP ${response.status}`);
  if (responseText.trim()) {
    console.log(responseText);
  }
}

function bundle(surveyId: string, surveySchemaHash: string, payloadHash: string, scrub: boolean): Record<string, unknown> {
  return {
    format: "survey_submission_bundle",
    version: 1,
    submitted_at: new Date().toISOString(),
    client_payload_hash: payloadHash,
    survey: {
      id: surveyId,
      template_version: 2,
      schema_hash: surveySchemaHash,
    },
    client: {
      install_id: `live-smoke-${smokeId}`,
      app_version: "smoke",
    },
    privacy: {
      scrub_identifying_info: scrub,
    },
    quality: {
      session_duration_seconds: 180,
      answered_question_count: 24,
      complete_answer_count: 24,
    },
    responses: [
      {
        section_id: "player_snapshot",
        responses: scrub ? [] : [
          {
            question_id: "community_handle",
            answer: "Smoke Tester",
            asks_identifying_info: true,
          },
        ],
      },
    ],
  };
}

function requestHeaders(contentType: string): Headers {
  const headers = new Headers();
  headers.set("content-type", contentType);
  if (authHeader.trim()) {
    const [name, value] = authHeader.split(":", 2);
    if (name && value) {
      headers.set(name.trim(), value.trim());
    }
  }
  if (anonKey.trim()) {
    headers.set("apikey", anonKey.trim());
    headers.set("authorization", `Bearer ${anonKey.trim()}`);
  }
  return headers;
}

function requiredEnv(key: string): string {
  const value = Deno.env.get(key)?.trim() ?? "";
  if (!value) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
  return value;
}
