# Public Upload Troubleshooting

Public uploads should fail clearly and preserve local export as the backup path.

## Failure Categories

- `network` or `request_failed`: the browser could not reach the endpoint. Save JSON locally and retry later.
- `not_allowlisted`: the server rejected the survey identity. Confirm `survey_id`, `template_version`, and `schema_hash` match the deployed allowlist.
- `duplicate_payload`: the same response already reached private intake.
- `rate_limited`: the install has reached the server-side daily upload limit.
- `malformed_json`, `unsupported_format`, `missing_identity`, `invalid_identity`, or `missing_payload_hash`: the upload bundle contract is wrong.
- `cors_not_allowed`: the hosted origin is missing from `SURVEY_UPLOAD_ALLOWED_ORIGINS`.
- `storage_not_configured`, `storage_error`, or `duplicate_check_failed`: Supabase configuration, table, or query setup is incomplete.

## Recovery Steps

1. Save a local JSON export before retrying.
2. Copy the upload response text from the app.
3. Check the Edge Function response `reason` and `endpoint_version`.
4. Check private `survey_upload_rejections` rows for repeated reason categories.
5. Confirm the latest `PrintSurveyIdentity.gd` schema hash is in `SURVEY_UPLOAD_ALLOWLIST_JSON`.
6. Confirm the public hosted origin is in `SURVEY_UPLOAD_ALLOWED_ORIGINS`.
7. Re-run `deno test supabase/functions/survey-upload/validation.test.ts`.
8. Re-run the live smoke script only after confirming it is acceptable to create private smoke rows.

## Change Log

- 2026-06-29 20:13 - Added upload failure taxonomy and recovery steps.
