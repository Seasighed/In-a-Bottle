# Public Launch Worktree Curation

The worktree is intentionally not ready for one broad commit. It contains several overlapping work streams and generated artifacts.

## Suggested Commit Groups

1. Public launch survey and upload gate:
   - `maplestory_pulse.json`
   - upload allowlist
   - runtime participant/QA profile changes
   - upload eligibility and upload failure taxonomy
   - Supabase intake scaffold and smoke harness
   - public upload docs

2. Release packaging and QA gate:
   - `tools/playtest.ps1`
   - GitHub Pages/CI workflow changes
   - public participant web bundle hardening
   - release readiness dashboard and smoke script docs

3. Wrapped review/export work:
   - answer review pipeline
   - share profile store
   - wrapped card/overlay work
   - screenshot proof and measurement tooling
   - related wrapped docs

4. QA/reporting and visual-audit cleanup:
   - QA checklist/controller/catalog changes
   - visual audit runner/catalog changes
   - feedback overlay/controller warning cleanup
   - question view preview-node cleanup

5. SeaShell/devtools settings work:
   - `addons/seashell_devtools/settings/**`
   - `project.godot` entries related to those scripts
   - related system docs

6. TechTree/session docs:
   - generated `05 Dev Notes/2026-...auto...` notes
   - `.techtree/autopilot-*.jsonl`
   - only commit these if the project wants local session trails in repo history.

7. Generated proof/export artifacts:
   - `exports/**`
   - release folders under `build/playtest/**`
   - keep as local evidence unless a specific artifact is intentionally preserved.

## Notes

- New `.gd.uid` files for new tracked scripts should travel with their scripts.
- Do not stage all untracked files blindly; `exports/**` is very large and mostly generated.
- A commit pass should review each group with `git diff --cached --stat` before committing.
- In this session, Git branch and commit writes were blocked in the foreground checkout because the checkout resolves to `X:/Projects/In a Bottle/.git` and lock-file creation was denied.
- Curation was completed in the safety clone at `build/commit-workspace/In-a-Bottle-rc-commits` on branch `codex-release-candidate-proof-pass`; the bundle backup is `build/commit-workspace/codex-release-candidate-proof-pass.bundle`.
- Latest safety branch HEAD is `a42d69e03b5f143e39baf6244fb4c2e3f50700a1`, including follow-up fixes for fresh-clone Godot import and allowlisted upload visual proof.
- `tools/playtest.ps1` now belongs in the release packaging and QA gate group because it isolates Godot AppData for validation and audit while preserving normal AppData for export template lookup.
- `tools/playtest.ps1` now uses Godot `--import` during bootstrap so a clone without existing `.godot` metadata can pass validation.

## Change Log

- 2026-06-30 04:55 - Recorded the completed safety-clone branch, bundle backup, latest HEAD, and fresh-clone import fix.
- 2026-06-30 02:58 - Added the playtest wrapper AppData isolation fix to the release packaging commit group.
- 2026-06-30 02:04 - Added the current Git lock-file blocker to the commit curation note.
- 2026-06-29 20:13 - Added commit grouping guidance for the broad public-launch worktree.
