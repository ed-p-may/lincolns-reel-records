---
DATE: 2026-11-22
STATUS: Scoped
AUTHOR: Antigravity
ISSUE: https://github.com/ed-p-may/lincolns-reel-records/issues/14
---

# Water-Body Fishing Info — Status

**Source:** [GitHub Issue #14](https://github.com/ed-p-may/lincolns-reel-records/issues/14)
**Status:** Scoped
**Current phase:** Phase 01 — ready for implementation

## Phase inventory

| Phase | Plan | Status |
|---|---|---|
| 01 | [Map selection, sheet UX, and free structured sources](plans/phase-01-map-selection-and-structured-sources.md) | Scoped |
| 02 | [Web-grounded fishing intel and shared Supabase cache](plans/phase-02-web-grounded-intel-and-cache.md) | Deferred |
| 03 | [State fisheries adapters (MassWildlife) and map search](plans/phase-03-state-fisheries-and-search.md) | Deferred |

## Resolved decisions (2026-11-22)

1. **Strictly free v1:** Keep v1 on free structured APIs (OSM Overpass, Wikipedia, iNaturalist,
   USGS) + in-app Safari quick-search links; defer web-grounded LLM synthesis (Phase 02).
2. **Interactive empty map:** Always show the interactive map even with 0 pinned catches (compact
   header hint instead of full-screen empty state).
3. **Client-only in v1:** No Supabase migration or Edge Function; iOS calls free APIs directly with
   an on-device cache (same pattern as `OpenMeteoClient`).

Recorded in `context/decisions.md`.

## Next step

Implement [Phase 01](plans/phase-01-map-selection-and-structured-sources.md) when ready.
