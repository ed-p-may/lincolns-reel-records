# Map Improvements

**Date:** 2026-11-22
**Status:** Complete
**Author:** Antigravity (research + planning packet for Ed May)
**Source:** [GitHub Issue #12](https://github.com/ed-p-may/lincolns-reel-records/issues/12)

## Scope

Research findings and phased implementation plan for four Catch Map upgrades requested in Issue #12:

1. **Species filter** on `CatchMapView` (derived from pinned catches, matching the Logbook filter).
2. **Satellite / Hybrid map style toggle** using native MapKit `.hybrid` / `.imagery` styles.
3. **Massachusetts public boat and fishing access points** bundled offline from MassGIS / MA Office of Fishing and Boating Access (OFBA).
4. **Massachusetts inland lake depth maps (bathymetry)** streamed from the official MassGIS / MassWildlife tiled map service via an `MKMapView` + `MKTileOverlay` bridge.

None of these phases require Supabase schema changes, database migrations, RLS changes, or paid third-party APIs.

## Read order

1. [PRD.md](PRD.md) — research findings, product contract, open decisions, and acceptance criteria.
2. [STATUS.md](STATUS.md) — current state, phase inventory, and next step.
3. Phase plans under `plans/`:
   - [Phase 01 — Species filter and satellite map style](plans/phase-01-species-filter-and-satellite.md)
   - [Phase 02 — MA public boat and fishing access points](plans/phase-02-ma-public-access.md)
   - [Phase 03 — MA lake depth overlay (bathymetry)](plans/phase-03-lake-depth-overlay.md)

## Canonical docs affected when implemented

- `context/PRD.md` (§6.4 Map)
- `context/user-stories.md` (Epic D — Map)
- `context/decisions.md` (map style persistence, bundled OFBA dataset, `MKMapView` bridge for tile overlays)
