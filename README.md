# In a Bottle

A GDScript-only survey shell for building custom questionnaires with section-based navigation, reusable UI hooks, and export-ready response data.

Disclaimer: this app was vibe coded with Codex.

## What is included

- Sectioned survey flow with smooth fades between sections.
- A persistent survey map that shows sections and nested questions in an indented list.
- A global overlay menu opened by `Escape` or the `Menu` button.
- JSON and CSV export for desktop builds, with browser downloads in web builds.
- Scene-prefab UI shells so layout changes made in the editor cascade across the app.
- A GitHub Pages workflow that exports the project as a static web build.

## Main files

- `Scenes/Main.tscn`: app entry scene and main survey shell prefab.
- `Scenes/UI/SectionOutlinePanel.tscn`: prefab for the section/question navigator.
- `Scenes/UI/OverlayMenu.tscn`: prefab for the global overlay menu.
- `Scripts/UI/SurveyApp.gd`: survey controller, export flow, and platform-specific browser fallbacks.
- `Scripts/Survey/SurveyTemplateLoader.gd`: template validation and loading.
- `.github/workflows/deploy-pages.yml`: GitHub Pages build and deploy workflow.
- `export_presets.cfg`: Godot Web export preset used locally and in CI.

## Local development

Edit the survey templates in `Dev/SurveyTemplates/` or point `SurveyApp.gd` at a different template path.

Built-in question types include:

- `SurveyQuestion.TYPE_SHORT_TEXT`
- `SurveyQuestion.TYPE_LONG_TEXT`
- `SurveyQuestion.TYPE_SINGLE_CHOICE`
- `SurveyQuestion.TYPE_MULTI_CHOICE`
- `SurveyQuestion.TYPE_BOOLEAN`
- `SurveyQuestion.TYPE_SCALE`
- `SurveyQuestion.TYPE_MATRIX`
- `SurveyQuestion.TYPE_RANKED_CHOICE`

If you need to export a web build locally, use a standard Godot 4.6 editor build. Godot 4 web export is not available from the .NET/Mono editor build, even for a GDScript-only project.

## GitHub Pages deployment

1. Push this repository to GitHub.
2. In the repository settings, open `Pages` and set the source to `GitHub Actions`.
3. Push to `main` or `master`, or run the `Deploy Web Build` workflow manually.
4. GitHub Actions will download the official Godot 4.6 stable Linux editor and export templates, export the `Web` preset, and publish `build/web` to GitHub Pages.

## GitHub Pages caveats

- 🌐 The browser build keeps onboarding and preferences enabled; it does not run in dev override mode by default.
- 🧵 The Web export preset is intentionally single-threaded (`variant/thread_support=false`), which avoids the cross-origin isolation header requirements that threaded Godot Web exports need.
- 📥 Save-style exports use browser downloads instead of desktop file dialogs.
- 📂 Loading a local progress JSON file is disabled in the browser build.
- 🗂️ Importing template files or opening the template folder is disabled in the browser build; use the bundled templates instead.
- 🖼️ PNG clipboard copy remains desktop-only. In the browser build, use the PNG download action.
- 🚨 If you later enable threaded Web export, Godot requires `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`, or the PWA/service-worker workaround.
- 🔌 Server upload requires a configured HTTPS endpoint with CORS enabled for your GitHub Pages origin.

## Custom visuals

For a custom question card:

1. Create a new scene whose root script extends `SurveyQuestionView`.
2. Implement `_apply_question()` and call `emit_answer(value)` when the answer changes.
3. Assign that scene to `custom_view_scene` on a `SurveyQuestion` in a survey template.

For a custom section hero/header:

1. Create a new scene whose root script extends `SurveySectionHeaderView`.
2. Implement `_apply_section()`.
3. Assign that scene to `custom_header_scene` on a `SurveySection` in a survey template.
