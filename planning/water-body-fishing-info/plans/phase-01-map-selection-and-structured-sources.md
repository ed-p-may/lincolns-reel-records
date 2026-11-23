---
DATE: 2026-11-23
STATUS: Implemented on branch
AUTHOR: Antigravity
ISSUE: https://github.com/ed-p-may/lincolns-reel-records/issues/14
---

# Phase 01 — Map selection, sheet UX, and free structured sources

**Status:** Implemented on branch (`feat/water-body-fishing-info`)
**Depends on:** Resolved 2026-11-22 decisions in `context/decisions.md`

## Goal

Enable tapping (or long-pressing) a body of water on the Catch Map to open a Google Maps-style peek
and detail sheet showing the angler's own local catches at that water plus free, keyless public
sources (OpenStreetMap water identity & boat ramps, Wikipedia overview & photo, iNaturalist local
fish species & CC photos, USGS live river flow, and one-tap Safari web report links) — entirely
client-side with an on-device cache, matching `OpenMeteoClient`.

## Implementation sequence

1. **Domain models & local history (`ReelRecords/Location/WaterBodyModels.swift`):**
   - Define `WaterBodySelection`, `WaterBodyInfo`, `WaterBodySpecies`, `WaterBodyPhoto` (with
     attribution/license), `WaterBodyAccessPoint`, `RiverGaugeReading`, `WaterBodyQuickLink`, and
     `LocalWaterHistory` (pure derivation over `[CatchItem]`: count, personal best, top lures,
     matching by normalized name or coordinate proximity within ~1 km).

2. **Client-side service & on-device cache (`ReelRecords/Location/WaterBodyInfoClient.swift`):**
   - Define `WaterBodyInfoProviding` protocol and inject it via `AppDependencies` (mirroring
     `WeatherSuggestionProviding` / `OpenMeteoClient`), with deterministic fixtures for unit tests
     and UI tests (`--ui-testing-water-info-fixture`).
   - Add a lightweight on-device JSON cache (under app `Caches` directory, keyed by canonical water
     ID, 14-day TTL for static water/species info, 15-min TTL for USGS live gauge, never synced).
   - Implement direct, polite `URLSession` fetchers (descriptive `User-Agent`, 4s per-source
     timeout, partial-success degradation):
     - **OSM Overpass:** `is_in` / `around:100` for `natural=water`, `waterway~"river|stream"`,
       `landuse=reservoir` with `name=*`, plus nearby `leisure=slipway` boat ramps. Reject
       non-water taps cleanly (`nil` / not found).
     - **Wikipedia REST:** `/api/rest_v1/page/summary/{title}` using OSM's `wikipedia` tag or
       disambiguated `<name>, <state>` lookup.
     - **iNaturalist:** `api.inaturalist.org/v1/observations?lat=...&lng=...&radius=3&taxon_id=47178`
       for top observed fish species and up to 6 CC-licensed photos with photographer attribution.
     - **USGS NWIS IV:** `waterservices.usgs.gov/nwis/iv/?bBox=...&parameterCd=00060,00065,00010`
       when water type is river/stream (or active gauge within 2 km).

3. **MapKit selection upgrade (`ReelRecords/Location/CatchMapView.swift`):**
   - Replace `selectedCatchID: UUID?` with `mapSelection: MapSelection<UUID>?` and wrap catch
     `Marker` tags in `MapSelection(catchItem.id)`.
   - Keep `selectedCatchCard` behavior unchanged when `mapSelection?.value` is set.
   - When `mapSelection?.mapFeature` has `.physicalFeature`, trigger water-body resolution and
     present `WaterBodyInfoSheet`.
   - Wrap `Map` in `MapReader` to support long-press coordinate inspection for small ponds not
     exposed as Apple `MapFeature`s; show a brief inline notice if no named water body is found.
   - Always render the interactive map even when `pinnedCatches.isEmpty` (with a compact header
     hint instead of blocking the entire tab with `ContentUnavailableView`).

4. **Google Maps-style sheet (`ReelRecords/Location/WaterBodyInfoSheet.swift`):**
   - Present with `.presentationDetents([.fraction(0.28), .medium, .large])` and
     `.presentationBackgroundInteraction(.enabled(upThrough: .medium))` so the map stays live
     behind the peek/medium card.
   - Render sections conditionally: Header + thumbnail, Your History Here (instant/local), Overview
     & Access (including USGS live flow card for rivers), Fish Species chips, Attributed Photos
     strip, Explore Further (`SFSafariViewController` links), and honest loading / sparse / offline
     states.

5. **Verification & physical-device check:**
   - Unit tests: `LocalWaterHistory` matching/stats, Overpass/Wikipedia/iNaturalist/USGS response
     decoding & partial-source handling, on-device cache hit/miss/TTL.
   - UI tests: catch-pin selection regression, fixture-backed water-body sheet peek → expand →
     dismiss, sparse-water state, zero-pinned-catch map browsing.
   - Physical iPhone test on real Berkshire waters (Stockbridge Bowl, Lake Mansfield, Housatonic
     River, Lake Buel, and a small local pond) to validate Apple `MapFeature` hit rate vs.
     long-press Overpass fallback.
   - Run `make ci`.

## Touch points

- `ReelRecords/Location/CatchMapView.swift`
- `ReelRecords/Location/WaterBodyModels.swift` (new)
- `ReelRecords/Location/WaterBodyInfoClient.swift` (new)
- `ReelRecords/Location/WaterBodyInfoSheet.swift` (new)
- `ReelRecords/App/AppDependencies.swift`
- `ReelRecordsTests/WaterBodyInfoTests.swift` (new)
- `ReelRecordsUITests/WaterBodyInfoUITests.swift` (new)
- `context/PRD.md`, `context/user-stories.md`

## Exit criteria

- Catch-pin selection and Catch Detail navigation have zero regressions.
- Tapping a labeled lake/river or long-pressing a small pond opens the Google Maps-style sheet
  with local catch history and free structured public sources.
- Sparse ponds and offline mode degrade cleanly without errors or fabricated content.
- Zero schema, migration, Edge Function, or sync changes.
- `make ci` passes and physical-device Berkshire water check is recorded in `STATUS.md`.
