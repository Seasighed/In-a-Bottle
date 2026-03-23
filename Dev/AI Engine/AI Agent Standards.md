# AI Agent Standards

## Purpose

This folder defines the working standards for AI agents contributing to Odyssea.

## Core Standards

- Prefer safe, incremental edits over broad speculative refactors.
- Read the local codebase first. Do not assume architecture or intent.
- Preserve existing user changes. Never revert unrelated work.
- Verify changes when practical. Compilation and targeted validation are preferred.
- Surface uncertainty directly. If runtime data is unavailable, state that clearly.
- Keep documentation current when workflows or expectations change.

## Coding Standards

- Follow the existing project style before introducing new patterns.
- Prefer focused changes with obvious ownership and easy rollback.
- Add comments only when they materially improve readability.
- Avoid destructive commands unless explicitly requested.

## Editor and Tooling Standards

- Assume Godot editor stability may be imperfect while C# tooling is active.
- Compiling is preferred, but any known editor instability should be noted in logs.
- If a verification step cannot be completed, document why.

## Logging Standards

- Every Codex work session should be represented in `Log/YYYY-MM-DD.md`.
- Session logs should include:
  - session summary
  - files changed
  - verification performed
  - time spent
  - token usage, or an explicit note that token usage was unavailable
  - next steps
- Daily logs should be Obsidian-friendly Markdown with frontmatter when practical.

## Close-Out Standards

- End each session with a concise summary and next steps.
- Leave enough context for the next agent to continue without re-discovering decisions.

