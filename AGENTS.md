# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Lincoln Fisher
15 year old, Massachusetts fisherman (Ed May's nephew). Lives in Sheffield, MA. 

## What this is

**Reel Records** — an iOS app for a small invite-only circle of anglers to log, track, and remember
fishing catches; each keeps a **private logbook**. The feel is a **premium fishing journal** crossed
with a **modern tracking app** (clean, tactile, image-forward). Multi-user backend, but **not** a public
social network — no feed, following, or sharing between users.

Status: **Phases 01–09 complete; Phase 10 — Bookmark and Per-Catch Share is next.** Phase 09 adds the
private local-first profile, avatar lifecycle, Catch-derived statistics, honest v1 settings, safe sign-out,
and in-app account deletion. Signed TestFlight build `0.1.0 (3)` remains the latest hosted beta build;
hosted migrations/Edge Functions plus physical camera, GPS/permissions, live weather, offline/reconnect,
and signed recovery remain consolidated in Phase 11. Current plan:
`context/implementation-phases/10-bookmark-share.md`.

## Working agreement (read before writing any code)

- **Confirm the build plan before scaffolding.** The stack is decided (below); agree the first
  implementation slice with Ed before generating an Xcode project or backend schema.
- Decisions of consequence (architecture pattern, sync strategy, third-party deps) get logged in
  `context/decisions.md` before they land in code.

## `context/` — source of truth for intent

Requirements, design language, and rationale live here and precede implementation. Read the relevant
doc before building the corresponding feature; keep these docs current as decisions change.

- `context/PRD.md` — product requirements: what the app does and why.
- `context/user-stories.md` — user stories / acceptance criteria driving each feature.
- `context/design-system.md` — design tokens + component specs (colors, type, motion), extracted from
  the Codex Design prototype.
- `context/decisions.md` — running log of architecture/tech decisions (ADR-style); the 9 PRD questions
  are resolved, with a short remaining "Open decisions" list for implementation-time details.
- `context/environments-and-accounts.md` — operational source of truth for Apple, TestFlight, Supabase,
  build-environment mapping, and login-account roles; never add passwords or privileged keys.
- `mockups/` — static HTML mockups in the app design language (e.g. `tacklebox.html`).

## Decided architecture (see `context/decisions.md`, 2026-07-19)

The 9 open PRD questions are resolved. Key stack decisions:

- **Platform:** Swift + SwiftUI. Build on iOS 26; **minimum deployment target iOS 18** (keeps SwiftData
  + modern APIs).
- **Backend:** **Supabase** (Postgres + Auth + Storage + RLS + Edge Functions). Reuses Ed's account.
- **Accounts:** real email/password login via Supabase Auth; **self-signup → straight in** (no in-app
  approval; access is gated by the TestFlight invite list). **No payments, no card data.**
- **Distribution:** **TestFlight**, invited **by email** (Ed's existing Apple Developer account), not the
  public App Store and not a public link — the invite list is the access gate.
- **Users:** small circle of friends & family — not just Lincoln, but **not** a public social network.
- **Offline-first:** SwiftData is the UI source of truth. An explicit versioned outbox synchronizes to
  Supabase; conflicts preserve local work for explicit retry, and deletes use retained tombstones.
- **Map:** MapKit + real GPS capture (manual fallback). **Photos:** multiple per catch (Supabase
  Storage). **Conditions:** Open-Meteo auto-fill + structured pickers, manual offline. **Units:**
  imperial only (v1).
- **Tackle Box:** a per-user catalog of lures/bait (`TackleItem`); the catch lure field is a picker
  from it (free-text fallback). New pushed screen (tab bar is full). Mockup: `mockups/tacklebox.html`.

## Conventions (to apply once code begins)

- **Language/UI:** Swift + SwiftUI. Encode design tokens once (see `design-system.md`), prefer SF
  Symbols, dark-only.
- Follow the goal-driven, surgical-change workflow: state a short plan for multi-step work, touch only
  what the task requires, and match established patterns once they exist.
