---
DATE: 2026-11-23
STATUS: Complete
AUTHOR: Antigravity
ISSUE: https://github.com/ed-p-may/lincolns-reel-records/issues/14
---

# Water-Body Fishing Info

**Source:** [GitHub Issue #14](https://github.com/ed-p-may/lincolns-reel-records/issues/14)
**Status:** Complete (Phase 01 merged to `main` via [PR #27](https://github.com/ed-p-may/lincolns-reel-records/pull/27); Phases 02–03 deferred)
**Canonical context affected:** `context/PRD.md` (§6.4 Map), `context/user-stories.md` (Epic D), `context/decisions.md`

## Scope

When an angler taps a body of water (lake, pond, river, or stream) on the Catch Map, slide up a
Google Maps-style card showing publicly available fishing info — water overview, boat ramps,
verified local fish species and attributed photos, live river flow when available, and one-tap
in-app Safari links to public fishing reports/blogs — alongside the angler's own private catch
history at that water.

## Read order

1. [STATUS.md](STATUS.md) — current state, resolved decisions, and phase inventory.
2. [RESEARCH.md](RESEARCH.md) — technical and data-source research answering Issue #14's research task (MapKit water selection, public APIs, web-grounded synthesis, cost, and ruled-out paths).
3. [PRD.md](PRD.md) — product behavior contract, UX anatomy, privacy/offline boundaries, and acceptance criteria.
4. Phase plans:
   - [Phase 01 — Map selection, sheet UX, and free structured sources](plans/phase-01-map-selection-and-structured-sources.md) *(active v1 scope — client-only)*
   - [Phase 02 — Web-grounded fishing intel and shared Supabase cache](plans/phase-02-web-grounded-intel-and-cache.md) *(deferred)*
   - [Phase 03 — State fisheries adapters (MassWildlife) and map search](plans/phase-03-state-fisheries-and-search.md) *(deferred)*

## Resolved decisions (2026-11-22 — recorded in `context/decisions.md`)

1. **Strictly free v1:** Ship Phase 01 with free structured APIs + in-app Safari quick-search links; defer web-grounded LLM synthesis (Phase 02).
2. **Interactive empty map:** Always render the interactive MapKit map even with 0 pinned catches (with a compact header hint).
3. **Client-only in v1:** No Supabase migration or Edge Function; iOS calls free APIs directly with an on-device cache (same pattern as `OpenMeteoClient`).
