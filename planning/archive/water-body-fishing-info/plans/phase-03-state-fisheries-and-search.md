---
DATE: 2026-11-22
STATUS: Deferred
AUTHOR: Antigravity
ISSUE: https://github.com/ed-p-may/lincolns-reel-records/issues/14
---

# Phase 03 — State fisheries adapters (MassWildlife) and map search

**Status:** Deferred (optional fast-follow after Phase 01–02 field feedback)
**Depends on:** Phase 02 complete

## Goal

Layer authoritative state fisheries data (starting with Massachusetts / MassWildlife for Lincoln's
home waters) into the water-body sheet and add a lightweight search bar to `CatchMapView` so
anglers can look up a lake or river by name without panning across the map first.

## Scope

1. **MassWildlife / MassGIS ArcGIS REST adapter (Edge Function):**
   - When coordinates fall within Massachusetts, query MassGIS/MassWildlife public ArcGIS REST
     services for:
     - **Trout Stocking Report** (most recent stocking date & species: Rainbow, Brown, Brook).
     - **Coldwater Fisheries Resources (CFR)** badge for streams.
     - **Office of Fishing & Boating Access (OFBA)** ramp/shore-access details and direct link to
       the official MassWildlife pond bathymetry map PDF/page.
   - Design as a clean `StateFisheriesAdapter` interface so NY DEC or CT DEEP can be added later
     without touching the iOS client.

2. **Map search bar on `CatchMapView`:**
   - Optional collapsible search field powered by Apple `MKLocalSearch` (matching
     `ManualLocationPicker`'s existing pattern) allowing the angler to jump to any lake/river and
     open its `WaterBodyInfoSheet` directly.

## Exit criteria

- Massachusetts waters display official stocking status and pond-map links when available; non-MA
  waters skip the adapter cleanly.
- Searching for a water body by name centers the map and opens its info sheet.
- `make ci` passes.
