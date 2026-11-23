---
DATE: 2026-11-23
STATUS: Complete
AUTHOR: Antigravity
ISSUE: https://github.com/ed-p-may/lincolns-reel-records/issues/14
---

# Water-Body Fishing Info — Status

**Source:** [GitHub Issue #14](https://github.com/ed-p-may/lincolns-reel-records/issues/14)
**Status:** Complete (Phase 01 merged to `main` on 2026-11-23; Phases 02–03 deferred)
**Current phase:** All active v1 scope merged to `main` ([PR #27](https://github.com/ed-p-may/lincolns-reel-records/pull/27), `a43cda3`)

## Phase inventory

| Phase | Plan | Status | PR |
|---|---|---|---|
| 01 | [Map selection, sheet UX, and free structured sources](plans/phase-01-map-selection-and-structured-sources.md) | Merged to main | [#27](https://github.com/ed-p-may/lincolns-reel-records/pull/27) |
| 02 | [Web-grounded fishing intel and shared Supabase cache](plans/phase-02-web-grounded-intel-and-cache.md) | Deferred | — |
| 03 | [State fisheries adapters (MassWildlife) and map search](plans/phase-03-state-fisheries-and-search.md) | Deferred | — |

## Verification evidence (2026-11-23)

- `make ci` passed on final PR #27 head (`2387169`, squash-merged as `a43cda3`):
  - `swiftformat --lint`: 0/110 files require formatting.
  - `swiftlint lint --strict`: 0 violations in 110 files.
  - `LincolnReelRecordsTests`: 140 tests, 0 failures (includes `WaterBodyInfoTests` and `WaterBodyInfoClientTests`).
  - `LincolnReelRecordsUITests`: 30 tests, 0 failures (includes `WaterBodyInfoUITests` 3/3 and `CatchMapUITests` 5/5).
  - `supabase test db --local`: 8/8 files, 99/99 tests PASS.
- PR #27 underwent two Codex (`gpt-6.2-sol`) review rounds (`8fab429` → `16b85a4` → `2387169`), with all 33 inline review threads answered and post-second-review commit `2387169` gated by full `make ci` before squash-merge.
- Residual physical-device check (deferred to TestFlight hardware smoke pass): real Berkshire waters tap hit-rate (Stockbridge Bowl, Lake Mansfield, Housatonic River, Lake Buel, and a small local pond) comparing Apple `MKMapFeatureAnnotation` taps vs. long-press Overpass fallback.
- Follow-up migration (before January 2027): migrate USGS live river gauge lookup from legacy `waterservices.usgs.gov/nwis/iv/` (scheduled for phased outages Jan 2027 and retirement Feb 22, 2027) to the replacement USGS Water Data API.

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
