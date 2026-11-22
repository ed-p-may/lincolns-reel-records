# Phase 02 — MA public boat and fishing access points

**Date:** 2026-11-22
**Status:** Implemented on branch
**Depends on:** [Phase 01](phase-01-species-filter-and-satellite.md) (map layers menu/sheet)
**Source:** [GitHub Issue #12](https://github.com/ed-p-may/lincolns-reel-records/issues/12)

## Goal

Plot official Massachusetts public boat ramps, cartop/canoe launches, fishing piers, and shore fishing access points as an optional, offline-first map layer sourced from MassGIS / MA Office of Fishing and Boating Access (OFBA).

## Data source (verified)

- **Service:** MassGIS `MA_Office_of_Fishing_and_Boating_Access_Sites` (ArcGIS Online Item `3c6cd66d299347c9aac128c57157334c`)
- **Endpoint:** `https://services.arcgis.com/2gdL2gxYNFY2TOUb/arcgis/rest/services/MA_Office_of_Fishing_and_Boating_Access_Sites/FeatureServer/0/query?where=1%3D1&outFields=*&outSR=4326&f=json`
- **Count:** 282 sites statewide (unauthenticated public government data).
- **Facility type codes (`FACILITY_T`, may be comma-separated like `A,E`):**
  - `A`: General Access (concrete ramp + trailer parking)
  - `B`: Fisherman Access (smaller ramp + trailer parking)
  - `C`: Cartop Access (small boats, kayaks, canoes)
  - `D`: Canoe Access (river access)
  - `E`: Sport Fishing Pier (barrier-free)
  - `F`: Shore Fishing Area

## Implementation sequence

1. **Reproducible data snapshot script & bundled JSON:**
   - Add a standalone script (e.g., `scripts/fetch_ma_access_sites.py` using stdlib `urllib`/`json`) that queries the MassGIS FeatureServer, filters out `PENDING == "Yes"` or missing coordinates, normalizes fields, sorts deterministically by `ofbaId`, and writes `ReelRecords/Resources/ma-public-access.json` (~45–60 KB).
   - Include a lightweight top-level metadata envelope (`source`, `state: "MA"`, `fetchedAt`, `sites: [...]`) so additional states (NY, CT) can be added later using the same loader.
2. **Swift model & offline repository:**
   - Add `PublicAccessSite` (`Codable`, `Identifiable`, `Hashable`, `Sendable`) with: `id`, `name`, `town`, `state`, `facilityTypes` (mapped enum), `rampType`, `parking`, `lanes`, `fee`, `restricted`, `barrierFree`, `comments`, `maintainer`, `latitude`, `longitude`.
   - Add `PublicAccessCatalog` that decodes `ma-public-access.json` once from `Bundle.main` and supports fast bounding-box / coordinate lookup.
3. **Map layer toggle & rendering in `CatchMapView`:**
   - Add `@AppStorage("reelrecords.map.showPublicAccess")` defaulting to `false`.
   - Expose `"MA Boat & Fishing Access"` toggle in the map layers sheet (alongside map style).
   - Render access markers with a distinct, lower-visual-weight style (e.g., muted teal/slate `Annotation` with a small boat/anchor icon) so private catch pins remain visually dominant.
   - Make catch selection and access-site selection mutually exclusive (`selectedCatchID` vs. `selectedAccessSiteID`).
   - Show a compact bottom card (`PublicAccessSiteCard`) when an access site is tapped: name, town, facility type pills, ramp surface, parking, comments/restrictions, and an **"Open in Apple Maps"** directions button (`MKMapItem.openInMaps()`).
   - **Zero-catch live canvas:** Replace the full-screen `ContentUnavailableView("No catches pinned yet")` gate with the live map canvas + a compact `"No catches pinned yet"` top header (preserving the `map.empty` accessibility signal or updating UI tests accordingly), centered on Massachusetts/user region when `pinnedCatches.isEmpty`, so an angler with 0 pinned catches can still browse MA access sites and (in Phase 03) lake depths.
4. **Tests & verification:**
   - Unit tests verifying JSON bundle decoding (all 282 sites parse with valid coordinates), facility-type code parsing (`"A,E"` → `[.generalAccess, .fishingPier]`), and mutually exclusive selection state.
   - UI test toggling the MA Public Access layer on/off and confirming catch counts stay unchanged.
   - Run `make ci`.

## Touch points

- `scripts/fetch_ma_access_sites.py` (new, reproducible snapshot generator)
- `ReelRecords/Resources/ma-public-access.json` (new, bundled offline dataset)
- `ReelRecords/Location/PublicAccessSite.swift` (new model + catalog loader)
- `ReelRecords/Location/PublicAccessSiteCard.swift` (new bottom detail card)
- `ReelRecords/Location/CatchMapView.swift`
- `ReelRecordsTests/PublicAccessCatalogTests.swift`
- `ReelRecordsUITests/`
- `context/PRD.md`, `context/user-stories.md`, `context/decisions.md`

## Exit criteria

- All bundled MA OFBA sites decode cleanly offline with zero network calls at runtime.
- Toggle defaults off, persists across restarts, and plots/hides access pins cleanly without affecting catch or spot counts.
- Tapping a site displays ramp/parking/notes details and launches Apple Maps directions.
- `make ci` passes cleanly.
