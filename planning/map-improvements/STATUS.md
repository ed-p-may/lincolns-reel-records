# Map Improvements status

**Date:** 2026-11-22
**Source:** [GitHub Issue #12](https://github.com/ed-p-may/lincolns-reel-records/issues/12)
**Status:** In progress
**Current phase:** Phase 01 implemented on branch `feature/map-improvements-01`

## Phase inventory

| Phase | Plan | Status |
|---|---|---|
| 01 | [Species filter and satellite map style](plans/phase-01-species-filter-and-satellite.md) | Implemented on branch |
| 02 | [MA public boat and fishing access points](plans/phase-02-ma-public-access.md) | Scoped |
| 03 | [MA lake depth overlay (bathymetry)](plans/phase-03-lake-depth-overlay.md) | Scoped |

## Current state

Research completed on 2026-11-22 against live MassGIS ArcGIS REST services and the current iOS 18 MapKit codebase (`CatchMapView.swift`, `ManualLocationPicker.swift`, `CatchDiscovery.swift`).

Verified facts:
- Native MapKit supports `.standard`, `.hybrid`, and `.imagery` out of the box.
- MassGIS OFBA FeatureServer (`3c6cd66d299347c9aac128c57157334c`) is public and unauthenticated with 282 MA sites (suitable for bundling as an offline JSON asset).
- MassGIS / MassWildlife Inland Water Bathymetry Tile Service (`tiles.arcgis.com/tiles/hGdibHYSPO59RG1h/.../Inland_Bathymetry/MapServer/tile/{z}/{y}/{x}`) is public, unauthenticated, returns transparent 256×256 PNG8 tiles with depth shading and contour labels in feet, and covers 16+ Berkshire lakes around Sheffield/Stockbridge/Pittsfield.
- SwiftUI `Map` on iOS 18 does not support `MKTileOverlay`; Phase 03 isolates the `MKMapView` `UIViewRepresentable` bridge so Phases 01–02 stay pure SwiftUI.

## Next step

All four scoping decisions in [PRD.md](PRD.md) are resolved (`Standard`/`Hybrid`/`Satellite` in layers sheet, Catch Detail mini-map stays muted `.standard`, live map canvas on 0 catches starting in Phase 02, and sequential `01 → 02 → 03` delivery). Ready to branch from `main` and implement Phase 01 once authorized.
