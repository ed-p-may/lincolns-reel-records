# Phase 03 — MA lake depth overlay (bathymetry)

**Date:** 2026-11-22
**Status:** Implemented on branch
**Depends on:** [Phase 01](phase-01-species-filter-and-satellite.md) and [Phase 02](phase-02-ma-public-access.md)
**Source:** [GitHub Issue #12](https://github.com/ed-p-may/lincolns-reel-records/issues/12)

## Goal

Overlay official Massachusetts inland lake depth contours and depth shading onto `CatchMapView` using the MassGIS / MassWildlife Inland Water Bathymetry Tile Service, without losing any existing Catch Map features.

## Data source & platform constraint (verified)

- **Tile Service:** `https://tiles.arcgis.com/tiles/hGdibHYSPO59RG1h/arcgis/rest/services/Inland_Bathymetry/MapServer/tile/{z}/{y}/{x}`
  - Public, unauthenticated, Web Mercator (`EPSG:3857`), 256×256 transparent PNG8 tiles.
  - Note ArcGIS coordinate order: `{z}/{y}/{x}` (level / row / column), not `{z}/{x}/{y}`.
  - Native scale range: `minScale: 80000` to `maxScale: 1000` (effectively zoom 12–19).
  - Returns HTTP 404 outside covered MA ponds.
- **iOS 18 MapKit constraint:** SwiftUI `Map` does not support `MKTileOverlay` on iOS 18. To render raster depth tiles over Apple's Standard, Hybrid, or Satellite basemaps, `CatchMapView` must host an `MKMapView` via `UIViewRepresentable` while keeping all SwiftUI HUD overlays (header, species chips, layers sheet, selected-catch card, access-site card) unchanged.

## Implementation sequence

1. **Custom `MKTileOverlay` (`MassGISBathymetryTileOverlay`):**
   - Subclass `MKTileOverlay` with `canReplaceMapContent = false`, `minimumZ = 11`, `maximumZ = 18`, `tileSize = CGSize(width: 256, height: 256)`.
   - Override `url(forTilePath:)` using `{z}/{y}/{x}`.
   - Override `loadTile(at:result:)` to:
     - Short-circuit with an empty transparent tile (no network call) if the tile's Web Mercator bounds do not intersect the Massachusetts bounding box (`lat 41.2...42.9`, `lon -73.55...-69.9`) or `path.z < 11`.
     - Fetch via a dedicated `URLSession` configured with a persistent `URLCache` (e.g., 25 MB disk cache) so recently viewed lakes stay cached during brief signal drops.
     - Treat HTTP 404 (and offline/network errors) silently as empty tiles without surfacing error alerts.
   - Render with `MKTileOverlayRenderer` at tuned alpha (e.g., `0.78` on Standard, `0.68` on Hybrid/Satellite) so contour labels remain readable over dark maps and satellite imagery.
2. **`MKMapView` `UIViewRepresentable` bridge (`CatchMKMapView`):**
   - Preserve full parity with the SwiftUI `Map` implementation:
     - `Standard` (dark muted), `Hybrid`, and `Satellite` via `MKStandardMapConfiguration` / `MKHybridMapConfiguration` / `MKImageryMapConfiguration` (`pointOfInterestFilter = .excludingAll`).
     - Catch pin annotations (`MKMarkerAnnotationView` tinted with `ReelTheme.accent` / `ReelTheme.accentHighlight`) and optional MA Public Access annotations (distinct muted style).
     - Two-way selection binding (`selectedCatchID` / `selectedAccessSiteID`), camera/focus updates (`focusCatchID` region zoom and `.automatic` fit-all framing), compass, and scale view.
     - Add/remove `MassGISBathymetryTileOverlay` cleanly when `showLakeDepths` toggles without resetting camera position or selection.
   - Keep `ManualLocationPicker` and `CatchDetailView` on lightweight SwiftUI `Map` (no tile overlay needed there).
3. **Layer toggle & attribution UX:**
   - Add `@AppStorage("reelrecords.map.showLakeDepths")` defaulting to `false`.
   - Expose `"MA Lake Depths"` in the map layers sheet with a concise caption: `"MassWildlife inland pond contours (MA only, requires connection; zoom in on a pond to view)."`
   - Include MassGIS / MassWildlife attribution in the layers sheet footer.
4. **Tests & physical-device verification:**
   - Unit tests for `MassGISBathymetryTileOverlay`: tile URL `{z}/{y}/{x}` formatting, Massachusetts bounding-box gating (Lake Buel tile passes; NYC/Atlantic tile short-circuits), and zoom-level gating.
   - UI tests verifying all existing Catch Map flows still pass on the `MKMapView` bridge (pin selection, opening Catch Detail, species filter, map style, access layer toggle, depth layer toggle).
   - Manual physical-device / simulator visual check on Lake Buel (`42.175, -73.279`) and Stockbridge Bowl (`42.345, -73.320`) in both Standard and Hybrid styles, plus airplane-mode check confirming silent fallback.
   - Run `make ci`.

## Touch points

- `ReelRecords/Location/MassGISBathymetryTileOverlay.swift` (new)
- `ReelRecords/Location/CatchMKMapView.swift` (new `UIViewRepresentable` bridge)
- `ReelRecords/Location/CatchMapView.swift` (swap SwiftUI `Map` body for `CatchMKMapView`, add depth toggle)
- `ReelRecordsTests/BathymetryTileOverlayTests.swift` (new)
- `ReelRecordsUITests/` (verify map parity + depth toggle)
- `context/PRD.md`, `context/user-stories.md`, `context/decisions.md`

## Exit criteria

- Enabling `MA Lake Depths` renders readable MassWildlife depth contours and shading over surveyed MA ponds on Standard, Hybrid, and Satellite styles.
- Panning outside MA or going offline produces zero error alerts and zero wasted out-of-state tile requests.
- All Catch Map behaviors from Phases 01–02 (focus navigation, species filter, catch selection, access-site cards) work identically on the `MKMapView` bridge.
- `make ci` passes cleanly.
