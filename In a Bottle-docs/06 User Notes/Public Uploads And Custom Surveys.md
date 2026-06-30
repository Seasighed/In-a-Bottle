# Public Uploads And Custom Surveys

The public participant build starts with `MapleStory Pulse`.

## Uploads

Uploads are available only for bundled surveys that the release owner explicitly allowlists. For v1, that means the built-in `MapleStory Pulse` template when the public build is configured with an upload endpoint.

Before uploading, users should review the upload screen and the scrub-identifying-answers option. Optional profile fields are uploaded only when the user explicitly opts in.

Accepted uploads go to private raw storage. Public sharing should come from manually reviewed summaries or wrapped image exports.

## Custom Surveys

Imported templates are labeled `Custom Survey`. They can be answered locally, saved as JSON, saved as CSV, and loaded later.

Custom Survey uploads are disabled in this release. This is intentional: local import/export stays flexible, while remote collection stays limited to surveys the release owner can validate and review safely.

## Public Summary Recipe

1. Export private response rows from Supabase into local answer JSON bundles.
2. Review the answers through the QA/imported-answer review workflow.
3. Keep scrub identifying answers on unless there is an explicit reason not to.
4. Generate wrapped summary images for public sharing.
5. Review all free-text samples manually before posting.
6. Share wrapped images or curated aggregate notes, not raw database rows.

## Privacy Review Checklist

- Identifying questions are scrubbed or intentionally omitted.
- Optional volunteered profile fields were included only when users opted in.
- Free-text answers do not name or shame individual players.
- Small respondent groups are not sliced so narrowly that a person becomes identifiable.
- Public copy says summaries are curated and raw responses remain private.

## Troubleshooting

If upload is unavailable, save a local JSON export before closing the app. If an upload fails or is rejected, the app should show a copyable message and the local export remains the backup.

Common failure messages now distinguish network trouble, duplicate uploads, server allowlist rejection, rate limits, malformed payloads, CORS/origin problems, and server storage setup issues.

## Change Log

- 2026-06-29 20:13 - Added the public summary recipe and privacy review checklist.
- 2026-06-29 20:13 - Added upload failure category guidance.
- 2026-06-29 17:18 - Added public upload and Custom Survey operator guidance.
