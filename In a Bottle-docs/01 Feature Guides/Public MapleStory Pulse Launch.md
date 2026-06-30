# Public MapleStory Pulse Launch

The public participant build now centers on one polished bundled survey: `MapleStory Pulse`. It is the default Journey survey for the participant profile and is designed as the first public community release rather than a generic form-builder showcase.

## Public Default

`MapleStory Pulse` lives at `res://Dev/SurveyTemplates/maplestory_pulse.json`. The participant runtime profile launches this template by default, while the QA profile keeps using `personal_checkin_debug.json` for internal validation.

The survey is broad but intentionally bounded. Its sections cover player profile, progression and routines, bosses and challenge, economy and events, community and social play, value sentiment, and future priorities. It uses choice, ranked-choice, matrix, scale, and text questions where those question types produce useful aggregate review data.

The built-in template marks handle/email-style questions as identifying so scrubbed exports and upload bundles can remove those answers when the user chooses to scrub identifying information.

## Custom Surveys

Imported templates remain usable for local survey runs. The loader labels them as `Custom Survey`, and respondents can still save JSON, save CSV, and reload progress locally.

Custom Survey uploads are intentionally disabled for this release. Upload eligibility only allows built-in `res://` templates that match the release allowlist by survey id, template version, and schema hash.

The public participant web bundle must not include a QA entry page. QA remains available through the separate QA bundle and command-line build profile.

## Playful Behavior

The Journey boss-health answer damage system stays part of the public identity of the app. It should remain lively around answer commits, section completion, wrap-up, upload results, and empty states, but it must never block form completion or obscure privacy/export/upload state.

`enable_playful_copy` keeps public copy lively while allowing the QA profile to disable personality for serious verification passes.

Public copy should keep using copyright-safe community RPG language. Do not add copied names, art, icons, class names, item names, or direct franchise jokes to the app UI.

## Related Notes

- [Upload Allowlist And Supabase Intake](../02%20Systems/Upload%20Allowlist%20And%20Supabase%20Intake.md)
- [Public Uploads And Custom Surveys](../06%20User%20Notes/Public%20Uploads%20And%20Custom%20Surveys.md)
- [Journey Boss Health Bar](Journey%20Boss%20Health%20Bar.md)

## Change Log

- 2026-06-29 20:13 - Documented strict participant web packaging and QA-disableable playful copy.
- 2026-06-29 17:18 - Added the public MapleStory Pulse launch guide.
