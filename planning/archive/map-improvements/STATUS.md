# Map Improvements status

**Date:** 2026-11-22
**Source:** [GitHub Issue #12](https://github.com/ed-p-may/lincolns-reel-records/issues/12)
**Status:** Complete
**Current phase:** All phases merged to `main` (2026-11-22)

## Phase inventory

| Phase | Plan | Status | PR |
|---|---|---|---|
| 01 | [Species filter and satellite map style](plans/phase-01-species-filter-and-satellite.md) | Merged to main | [#23](https://github.com/ed-p-may/lincolns-reel-records/pull/23) |
| 02 | [MA public boat and fishing access points](plans/phase-02-ma-public-access.md) | Merged to main | [#24](https://github.com/ed-p-may/lincolns-reel-records/pull/24) |
| 03 | [MA lake depth overlay (bathymetry)](plans/phase-03-lake-depth-overlay.md) | Merged to main | [#25](https://github.com/ed-p-may/lincolns-reel-records/pull/25) |

## Verification evidence

- `make ci` (SwiftFormat, SwiftLint strict across 98 files, full unit test suite including `CatchMapTests`, `PublicAccessCatalogTests`, `BathymetryTileOverlayTests`, full 27-test UI suite including `CatchMapUITests`, and 8/8 Supabase DB test files / 99 tests) passed on every merged PR head (`2e9bd15`, `2b60c7f`, `7e1ad7f`).
- Each PR underwent two Codex (`gpt-6.2-sol`) review rounds; post-second-review follow-up commits (`569952c` on PR #23, `58d480b` on PR #24, `9fa7940` on PR #25) were each gated by full `make ci` before squash-merge.
- Residual physical-device check (deferred to TestFlight smoke pass): visual legibility of MassWildlife contours over Lake Buel (`42.175, -73.279`) and Stockbridge Bowl (`42.345, -73.320`) across Standard/Hybrid/Satellite and airplane-mode tile caching on hardware.

## Current state

Research completed on 2026-11-22 against live MassGIS ArcGIS REST services and the current iOS 18 MapKit codebase (`CatchMapView.swift`, `ManualLocationPicker.swift`, `CatchDiscovery.swift`).

Verified facts:
- Native MapKit supports `.standard`, `.hybrid`, and `.imagery` out of the box.
- MassGIS OFBA FeatureServer (`3c6cd66d299347c9aac128c57157334c`) is public and unauthenticated with 282 MA sites (suitable for bundling as an offline JSON asset).
- MassGIS / MassWildlife Inland Water Bathymetry Tile Service (`tiles.arcgis.com/tiles/hGdibHYSPO59RG1h/.../Inland_Bathymetry/MapServer/tile/{z}/{y}/{x}`) is public, unauthenticated, returns transparent 256×256 PNG8 tiles with depth shading and contour labels in feet, and covers 16+ Berkshire lakes around Sheffield/Stockbridge/Pittsfield.
- SwiftUI `Map` on iOS 18 does not support `MKTileOverlay`; Phase 03 isolates the `MKMapView` `UIViewRepresentable` bridge so Phases 01–02 stay pure SwiftUI.

## Next step

All four scoping decisions in [PRD.md](PRD.md) are resolved (`Standard`/`Hybrid`/`Satellite` in layers sheet, Catch Detail mini-map stays muted `.standard`, live map canvas on 0 catches starting in Phase 02, and sequential `01 → 02 → 03` delivery). Ready to branch from `main` and implement Phase 01 once authorized.
