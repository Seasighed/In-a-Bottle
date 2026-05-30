# Journey Health Bar

## What This Is

Journey mode shows survey progress as a boss health bar. The bar is a smooth rounded rectangle with one layer for each survey section.

## How To Use It

Answer the current question and move forward to commit the hit. The HP label shows total boss health remaining. The smaller detail line shows how much the current question is worth for total HP and for its section layer.

## What Changed

The health bar now uses stacked full-width section layers instead of chunky side-by-side segments. Completing a section removes that layer from the visible bar. Going back to edit a completed answer heals that question's hit until it is completed and committed again.

The bar stays anchored while taking repeated damage, and a fully depleted layer no longer leaves a tiny filled remainder behind.

## Known Limits

Only complete answers deal real boss damage. Partial answers still show up as visual glancing hits during the final recap.

## Change Log

- 2026-05-09 04:13 - Added the anchored hit feedback and fully depleted layer behavior.
- 2026-05-09 03:50 - Added user-facing notes for the layered Journey health bar.
