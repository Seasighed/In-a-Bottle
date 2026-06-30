# Public Launch Roadmap Implementation

This implementation slice moves `In a Bottle` toward a web-first public release centered on one polished MapleStory community survey. It lands the client-side launch shape and a Supabase intake scaffold, but it does not complete live deployment, hosted-device QA, or the full release proof package.

## Landed

- Added `Dev/SurveyTemplates/maplestory_pulse.json` as the participant default survey.
- Added `Resources/Survey/UploadAllowlist.json` and `SurveyUploadEligibility` for release-owned upload gating.
- Updated participant runtime defaults so public builds open `MapleStory Pulse`, while QA keeps the broad debug template.
- Updated upload copy so raw answers are described as private intake data, with public sharing handled through curated aggregates and wrapped exports.
- Disabled upload for imported/custom templates while preserving local JSON/CSV save and load workflows.
- Added a Supabase Edge Function scaffold at `supabase/functions/survey-upload`.
- Added a private Supabase migration for `public.survey_responses`.
- Added Deno validation tests for allowlisted, rejected, malformed, and scrubbed upload payload behavior.
- Fixed `tools/playtest.ps1` native exit-code handling so wrapper commands work under strict execution contexts.
- Reduced noisy QA/headless warnings from preview fields, overlay sizing, date-picker setup, visual audit typed arrays, and headless screenshot capture.

## Verified In This Slice

- Godot check-only passed.
- `CiTestBootstrap.gd` passed with 52 passed, 0 failed.
- `tools/playtest.ps1 doctor` passed.
- `tools/playtest.ps1 test` passed.
- `deno test supabase/functions/survey-upload/validation.test.ts` passed with 5 passed, 0 failed.

Known remaining local noise: Godot still reports dummy renderer resource leak messages at headless process exit. Those are not currently app test failures, but they should stay visible in release notes until a renderer-level cleanup path is found.

## Remaining Before Public Launch

- Configure the real Supabase project.
- Apply the `survey_responses` migration.
- Deploy the `survey-upload` Edge Function.
- Set `SURVEY_UPLOAD_ALLOWLIST_JSON` with the exact deployed `MapleStory Pulse` schema hash.
- Configure the hosted participant build with the real upload endpoint and required headers.
- Promote or push the safety branch so the canonical repo has the reviewable baseline.
- Keep the final safety-clone release folder `build/playtest/20260630-044822` as the current local artifact proof until a hosted build supersedes it.
- Exercise the live endpoint for accepted `MapleStory Pulse`, rejected Custom Survey, duplicate payload, malformed payload, and scrubbed identifying answers.
- Complete desktop Chrome or Edge, hosted desktop web, mobile Safari or iOS emulation, and Android Chrome or Android emulation smoke coverage.
- Generate wrapped summary proof for 1, 5, and 100 fake respondents.

## Change Log

- 2026-06-30 04:55 - Added current safety-branch release proof status and removed visual-audit proof from the remaining local launch blockers.
- 2026-06-29 17:18 - Added the roadmap implementation handoff note.
