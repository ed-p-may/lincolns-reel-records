# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**Reel Records** — a personal-use iOS app for logging, tracking, and remembering fishing catches.
The intended feel is a **premium fishing journal** crossed with a **modern social tracking app**
(clean, tactile, image-forward; personal record-keeping, not a public social network).

Status: **pre-code / setup phase.** No application source exists yet. The wireframe/mockup is being
produced in Claude Design and has not yet been shared. Do not scaffold screens, models, or a database
until the design and the PRD (`context/PRD.md`) are reviewed together.

## Working agreement (read before writing any code)

- **No coding until the design is provided and the PRD is agreed.** This directory is deliberately
  empty of source. Setup-only tasks (docs, config, project scaffolding) are fine; feature code is not.
- **The database is an open decision.** Nothing is chosen yet (candidates to discuss: SwiftData,
  Core Data, GRDB/SQLite, Realm, a sync backend like CloudKit/Supabase/Firebase). Do not assume or
  hard-code a persistence layer. Record the decision in `context/decisions.md` once made.
- Decisions of consequence (persistence, architecture pattern, min iOS version, third-party deps)
  get logged in `context/decisions.md` before they land in code.

## `context/` — source of truth for intent

Requirements, design language, and rationale live here and precede implementation. Read the relevant
doc before building the corresponding feature; keep these docs current as decisions change.

- `context/PRD.md` — product requirements: what the app does and why.
- `context/user-stories.md` — user stories / acceptance criteria driving each feature.
- `context/design-guidelines.md` — visual + interaction language (the "premium journal" feel), derived
  from the Claude Design wireframe once shared.
- `context/decisions.md` — running log of architecture/tech decisions (ADR-style), including the
  pending database choice.

## Conventions (to apply once code begins)

- **Language/UI:** Swift + SwiftUI, targeting current iOS. Confirm the minimum deployment target as a
  logged decision before relying on newer APIs.
- **Personal use:** single-user, on-device first. Treat any cloud sync / social feature as an explicit,
  separately-decided addition — not a default.
- Follow the goal-driven, surgical-change workflow: state a short plan for multi-step work, touch only
  what the task requires, and match established patterns once they exist.
