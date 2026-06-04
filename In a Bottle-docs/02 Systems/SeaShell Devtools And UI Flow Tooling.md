# SeaShell Devtools And UI Flow Tooling

## Purpose

This repo now carries the shared SeaShell devtools addon plus local survey tooling for exporting builds and rendering a visual UI flow atlas. Together, they make the Journey shell easier to inspect, validate, and ship.

## Components

- `addons/seashell_devtools/` vendors the shared SeaShell addon, including UI layers, feedback helpers, settings packs, and the editor dock/plugin.
- `project.godot` enables the addon plugin, registers the SeaShell autoloads, and points the project at the default devtools settings pack.
- `Scripts/Tools/SurveyBuildExportSupport.gd` resolves build folders, version labels, preset output paths, and Godot export commands.
- `Scripts/Tools/VerifyExportArtifacts.gd` gives the repo a reusable export-artifact verifier for manual or CI build gates.
- `Scripts/Tools/SurveyUiFlowCatalog.gd` defines the captured screen graph for Survey App, Journey, and shared question UI states.
- `Scripts/Tools/SurveyUiFlowMapScene.gd`, `SurveyUiFlowCanvas.gd`, and `SurveyUiFlowFixtures.gd` render the atlas, capture screenshots, and drive versioned build exports from the tooling scene.
- `Scenes/Tools/SurveyUiFlowMap.tscn` is the operator-facing tooling scene.
- `Resources/Survey/DefaultFeatureFlags.tres` and `Scripts/UI/SurveyFeatureFlags.gd` let the shells keep tooling or preview affordances wired while selectively hiding them in respondent-oriented defaults.
- `export_presets.cfg` now carries both the Web preset and a first-class `Windows Desktop` preset for the build tooling and CI flow.

## Data Or Control Flow

1. The project boots with SeaShell autoloads and the devtools plugin available from `project.godot`.
2. Tooling scenes pull their screen definitions from `SurveyUiFlowCatalog` and instantiate real survey shells or shared UI surfaces to capture those states.
3. Captured images are laid out into a scrollable atlas by `SurveyUiFlowCanvas`, while the manifest and exported node images are written to the configured output directory.
4. Build exports use `SurveyBuildExportSupport` to normalize the chosen builds folder, inspect existing version folders, pick the next `v###` slot, compute preset-specific target paths, and verify the artifacts that should exist after export.
5. The tooling scene blocks known-bad export combinations before they start. Right now the important guard is `Web + Mono Godot editor`, because the repo vendors SeaShell C# addon files and Godot 4 Mono will not produce a valid Web export from that setup.
6. The addon settings and feature flags let the project ship a simpler participant-facing Journey surface while keeping editor/debug tooling available when explicitly enabled.

## Operational Notes

- `localBuilds/` is generated output and should stay out of git history.
- The UI flow tooling is most useful when question prefabs and Journey states still match the catalog; add or rename nodes in the catalog when the screen map changes.
- Feature flags default preview controls off for respondent-facing flows, so the code can stay present without surfacing every dev affordance by default.
- Local Web exports should use a non-Mono Godot editor build. A Mono editor on Windows can report a successful export while producing no Web artifacts because the vendored SeaShell addon includes C# files.
- The SeaShell addon is shared across repos, so repo-local overrides should be deliberate and documented when the vendored copy changes.

## Related Notes

- [Playtest Feedback And Response Transfer](Playtest%20Feedback%20And%20Response%20Transfer.md)
- [Journey Boss Health Bar](../01%20Feature%20Guides/Journey%20Boss%20Health%20Bar.md)
- [Journey Submit Flow](../01%20Feature%20Guides/Journey%20Submit%20Flow.md)

## Change Log

- 2026-06-03 23:25 - Added Windows export preset parity, artifact verification, and the Mono-Web local export blocker note.
- 2026-05-30 02:53 - Documented the vendored SeaShell devtools addon, UI flow atlas tooling, versioned build export flow, and feature-flag role.
