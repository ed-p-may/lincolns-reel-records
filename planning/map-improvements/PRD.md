# Map Improvements

**Date:** 2026-11-22
**Status:** Scoped
**Author:** Antigravity
**Source:** [GitHub Issue #12](https://github.com/ed-p-may/lincolns-reel-records/issues/12)
**Owner:** Reel Records iOS app

## Goal

Make the Catch Map more useful for planning trips and reading water around western Massachusetts (and anywhere else an angler logs catches) by adding species filtering, satellite imagery, public boat/shore access markers, and inland lake depth contours.

## Research findings (verified 2026-11-22)

### 1. Lake depth maps (bathymetry)

- **Commercial bathymetry** (Navionics/Garmin, C-MAP, Lakemaster) is proprietary and not licensed for free embedding in a small TestFlight app.
- **National open data** (NOAA NCEI, OpenSeaMap, Open Waters) covers coastal waters and major navigable waterways, but has little to no coverage of small New England inland ponds.
- **Massachusetts official open data (verified live):** MassGIS and MassWildlife publish **MassWildlife Inland Water Bathymetry** (`DFWBATHY_ARC`), derived from GPS + depth-sounder transects at 1:10,000 scale for public-access ponds across Massachusetts.
  - **Pre-styled Tile Service (recommended):**
    `https://tiles.arcgis.com/tiles/hGdibHYSPO59RG1h/arcgis/rest/services/Inland_Bathymetry/MapServer/tile/{z}/{y}/{x}`
    - Public, unauthenticated, Web Mercator (`EPSG:3857`), 256×256 transparent PNG8 tiles, LODs 0–23 (`minScale: 80000`, `maxScale: 1000`, visible roughly z12–z19).
    - Includes both blue depth shading and depth contour labels in feet.
    - Verified live HTTP 200 over Lake Buel (`tile/14/6071/4856`, 6,536 bytes, valid PNG).
    - Verified Berkshire County coverage (16 lakes in the southern/central Berkshire bounding box, including Lake Buel, Lake Garfield, Stockbridge Bowl, Laurel Lake, Onota Lake, Pontoosuc Lake, Goose Pond, Richmond Pond, Mansfield Pond, and Spectacle Ponds).
    - Returns HTTP 404 outside covered tiles; clients should gate requests to the MA bounding box and zoom 11–18 and treat 404 silently as empty.
  - **Vector Feature Service (evaluated, not recommended for v1):**
    `https://arcgisserver.digital.mass.gov/arcgisserver/rest/services/AGOL/MassWildlife_Inland_Bathymetry/FeatureServer/0` (27,989 contour polylines statewide). SwiftUI `MapPolyline` has no built-in along-line text labels or shaded depth ramp, making vector rendering heavier and less readable than the pre-styled tiles.
- **iOS 18 MapKit constraint:** SwiftUI's native `Map` view does **not** support `MKTileOverlay` on iOS 18. Rendering raster bathymetry tiles over Apple Maps requires wrapping `MKMapView` in `UIViewRepresentable` with an `MKTileOverlay` + `MKTileOverlayRenderer`. Isolating this to Phase 03 lets Phases 01 and 02 ship on pure SwiftUI `Map`.

### 2. Satellite view option

- Native MapKit (iOS 18+) supports `.standard`, `.hybrid` (satellite imagery with road and water-body labels), and `.imagery` (pure satellite) with zero API keys, zero cost, and no third-party dependencies.
- Currently all three map surfaces (`CatchMapView`, `ManualLocationPicker`, `CatchDetailView`) hardcode `.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll)`.
- Supporting satellite/hybrid in `ManualLocationPicker` as well as `CatchMapView` directly improves manual pin placement on coves, points, and shorelines.

### 3. MA boat access and public-access locations

- **Verified official dataset:** MassGIS / MA Office of Fishing and Boating Access (`MA_Office_of_Fishing_and_Boating_Access_Sites`, ArcGIS Online item `3c6cd66d299347c9aac128c57157334c`).
  - **Endpoint:** `https://services.arcgis.com/2gdL2gxYNFY2TOUb/arcgis/rest/services/MA_Office_of_Fishing_and_Boating_Access_Sites/FeatureServer/0`
  - **Access:** Public, unauthenticated, supports GeoJSON/JSON query output.
  - **Scale:** **282** official sites statewide (concrete ramps, gravel/fisherman access, cartop/kayak launches, canoe river access, barrier-free fishing piers, and shore fishing areas). Verified Berkshire examples include Lake Buel, Lake Garfield, Shaw Pond, Onota Lake, and Pontoosuc Lake.
  - **Attributes:** `OFBA_ID`, `FACNAME`, `TOWN`, `FACILITY_T` (`A` General Access, `B` Fisherman Access, `C` Cartop, `D` Canoe, `E` Sport Fishing Pier, `F` Shore Fishing; comma-separated when multi-type), `RAMPTYPE`, `PARKING`, `NOLANES`, `FEE`, `RESTRICTED`, `BARRIER_FR`, `COMMENTS`, `MAINTRESP`, `POINT_X`, `POINT_Y`.
- **Recommended storage:** Bundle a normalized JSON snapshot (~45–60 KB) in the iOS app bundle, refreshed on demand via a repo script. This keeps the layer 100% offline-ready, instant to render, and immune to runtime ArcGIS downtime.
- **Extensibility:** Include `state` and `source` fields in the bundled JSON model so neighboring states (NY DEC, CT DEEP) can be added later without changing UI code.

### 4. Map species filter

- Fully local and offline-first; no schema, sync, or backend changes.
- Reuses `CatchDiscovery.species(in:)` and `CatchDiscovery.normalized(_:)` (the exact same case-, diacritic-, and width-insensitive matching used in `LogbookView` and `AddCatchView`) and the existing `SelectionChip` component.

## Proposed product contract

### Map controls & chrome
- Keep the map canvas unobstructed: top inset holds the count summary and species filter chips (when > 1 species is pinned); a compact floating map-layers button (top-right, below the nav bar) opens a clean dark popover/sheet for **Map Style** (`Standard`, `Hybrid`, `Satellite`) and **Layers** (`MA Boat & Fishing Access`, `MA Lake Depths`).
- Persisted device-local preferences (`@AppStorage`): selected map style and layer toggles survive app restarts without touching Supabase.

### Species filter (Phase 01)
- Filter chips derive from `CatchDiscovery.species(in: pinnedCatches)` with a leading `"All"` chip.
- Shown only when `pinnedCatches` contains at least 2 distinct species.
- Header updates to show filtered vs. total counts (e.g., `4 OF 12 CATCHES ACROSS 2 SPOTS`).
- Changing the filter updates the visible pins; if the currently selected catch is excluded, selection moves to `filteredCatches.first?.id` (or `nil`).
- Navigating to the map via `focusCatchID` (from Catch Detail or Favorite Spots) clears an incompatible species filter so the target pin is always shown.
- If edits or deletions remove the active species from `pinnedCatches`, the filter resets to `"All"`.

### Satellite / Hybrid view (Phase 01)
- Three map styles: `Standard` (current muted dark map, default), `Hybrid` (satellite + labels), and `Satellite` (pure imagery).
- Persisted in `@AppStorage` and shared by `CatchMapView` and `ManualLocationPicker`.
- Offline note remains honest: catch pins and bundled access sites work offline; Apple map/satellite tiles may require a connection.

### MA public access layer (Phase 02)
- Toggleable layer (`MA Boat & Fishing Access`), **off by default** so private catch pins remain primary.
- Renders bundled OFBA sites with a visually distinct, lower-emphasis marker (e.g., slate/teal boat/anchor glyph) that does not compete with catch pins.
- Tapping an access site selects it (mutually exclusive with a selected catch pin) and shows a compact bottom card with facility name, town, access type badges, ramp surface, parking, notes/restrictions, and an "Open in Apple Maps" directions button.
- Does not alter catch counts or spot counts. Starting in Phase 02, `CatchMapView` always renders the live map canvas with a compact `"No catches pinned yet"` header when `pinnedCatches.isEmpty`, so an angler with 0 pinned catches can still browse MA boat ramps and lake depths.

### MA lake depth overlay (Phase 03)
- Toggleable layer (`MA Lake Depths`), **off by default**, labeled clearly as Massachusetts-only and online-backed (with local tile caching).
- Overlays the MassGIS `Inland_Bathymetry` raster tiles on top of Standard, Hybrid, or Satellite basemaps via an `MKMapView` `UIViewRepresentable` wrapper.
- Requests are bounded to Massachusetts coordinates and zoom levels 11–18; HTTP 404 tiles fail silently without error banners.
- Works alongside catch pins, species filter, and MA public access pins.

## Resolved decisions (2026-11-22)

1. **Map style choices:** 3 choices (`Standard`, `Hybrid` satellite + labels, `Satellite` pure imagery) in a map layers popover/sheet, persisted via `@AppStorage`.
2. **`CatchDetailView` mini-map style:** Keep the "Where it happened" mini-map muted `.standard`; apply the persisted map style to `CatchMapView` and `ManualLocationPicker` only.
3. **Zero-catch map behavior:** Keep the full-screen `ContentUnavailableView("No catches pinned yet")` empty state in Phase 01; starting in Phase 02, show the live map canvas with a compact `"No catches pinned yet"` header so anglers can browse MA public access points and lake depths even with 0 pinned catches.
4. **Phase 03 (`MKMapView` bridge) sequencing:** Proceed straight through Phases `01 → 02 → 03` in sequence (one PR/stage per phase).

## Acceptance criteria

1. **Species filter:** Selecting a species chip shows only matching pinned catches (case/diacritic-insensitive), updates the header counts, preserves focus navigation from Catch Detail/Favorite Spots, and resets cleanly if the species is removed.
2. **Satellite view:** Switching between Standard, Hybrid, and Satellite updates `CatchMapView` immediately, persists across restarts, and is available in `ManualLocationPicker`.
3. **MA public access:** Enabling the layer plots the bundled 282 MA OFBA sites offline without network calls; tapping a site displays its ramp/parking/notes card and Apple Maps directions link; disabling hides all access markers.
4. **MA lake depths:** Enabling the depth layer overlays MassWildlife bathymetry contours over MA ponds (verified on Berkshire lakes such as Lake Buel / Stockbridge Bowl) on Standard and Hybrid/Satellite styles, with zero error alerts when panning outside MA or offline.
5. **Non-regression:** Owner isolation, tombstone hiding, offline catch logging, sync, and `make ci` (SwiftFormat, SwiftLint, unit tests, UI tests, DB tests) remain green.

## Non-goals

- Commercial paid bathymetry SDKs (Navionics, C-MAP, Mapbox paid tiers).
- Nationwide or multi-state bathymetry/boat-ramp aggregation in this packet (schema stays extensible for NY/CT later).
- Custom offline tile-pack downloader UI (standard `URLCache` caching only in Phase 03).
- User-submitted or shared public access points (app remains strictly private per-user logbooks).
- Supabase schema, migration, or Edge Function changes.
