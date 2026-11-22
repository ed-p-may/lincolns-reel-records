# Phase 01 — Species filter and satellite map style

**Date:** 2026-11-22
**Status:** Implemented on branch
**Depends on:** Completed Map and Logbook discovery phases
**Source:** [GitHub Issue #12](https://github.com/ed-p-may/lincolns-reel-records/issues/12)

## Goal

Add species filtering to `CatchMapView` and a persisted `Standard` / `Hybrid` / `Satellite` map-style picker to `CatchMapView` and `ManualLocationPicker`, staying on native SwiftUI `Map` with zero backend or schema changes.

## Implementation sequence

1. **Map style model and persistence:**
   - Add a `CatchMapStyle` enum (`standard`, `hybrid`, `satellite`) in `ReelRecords/Location/LocationModels.swift` (or `CatchMapStyle.swift`) with a computed `mapStyle: MapStyle`, display title, SF Symbol icon, and `@AppStorage` key (`reelrecords.map.style`, defaulting to `.standard`).
   - `.standard` keeps `.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll)`.
   - `.hybrid` uses `.hybrid(elevation: .flat, pointsOfInterest: .excludingAll)`.
   - `.satellite` uses `.imagery(elevation: .flat)`.
2. **Species filtering logic:**
   - Add a pure helper on `CatchDiscovery` (e.g., `CatchDiscovery.pinnedCatches(_:species:)`) that filters `catches` to those with a non-nil `coordinate` and optional `CatchDiscovery.normalized` species match.
   - Derive available filter chips from `CatchDiscovery.species(in: pinnedCatches)`.
3. **Update `CatchMapView`:**
   - Add `@State private var selectedSpecies: String?` and `@AppStorage` for `CatchMapStyle`.
   - Render a horizontal `SelectionChip` bar (`All` + distinct pinned species) inside `mapHeader` when `availableSpecies.count > 1`, with accessibility identifiers (`map.species.All`, `map.species.<species>`).
   - Update `mapHeader` counts to distinguish filtered vs. total counts (`X OF Y CATCHES ACROSS Z SPOTS` when filtered).
   - Add a compact floating/toolbar map-style button (`map.style.button`) opening a dark menu/popover to pick `Standard`, `Hybrid`, or `Satellite`.
   - Keep selection and focus coherent:
     - On `selectedSpecies` change, if `selectedCatchID` is no longer in `filteredCatches`, set `selectedCatchID = filteredCatches.first?.id`.
     - In `focusRequestedCatch()`, if `focusCatchID` exists in `pinnedCatches` but is excluded by `selectedSpecies`, clear `selectedSpecies = nil` before focusing.
     - On `reload()`, if `selectedSpecies` is no longer present in `availableSpecies`, reset `selectedSpecies = nil`.
4. **Update `ManualLocationPicker`:**
   - Read/bind the same persisted `CatchMapStyle` and expose a compact style toggle button in the picker map chrome so anglers can drop pins accurately on satellite/hybrid imagery.
5. **Tests & verification:**
   - Unit tests in `ReelRecordsTests/CatchMapTests.swift` (or `CatchDiscoveryTests.swift`) covering species filtering on pinned catches, case/diacritic normalization, selection fallback, and focus-override behavior.
   - UI tests in `ReelRecordsUITests/` covering filtering pins by species chip, verifying updated `map.counts`, and toggling map style.
   - Run `make ci` (SwiftFormat, SwiftLint, unit tests, UI tests, DB tests).

## Touch points

- `ReelRecords/Location/LocationModels.swift` (or new `CatchMapStyle.swift`)
- `ReelRecords/Catches/CatchDiscovery.swift`
- `ReelRecords/Location/CatchMapView.swift`
- `ReelRecords/Location/ManualLocationPicker.swift`
- `ReelRecordsTests/` (new/updated unit tests)
- `ReelRecordsUITests/` (map filter & style UI tests)
- `context/PRD.md`, `context/user-stories.md`, `context/decisions.md`

## Exit criteria

- Species filter chips filter map pins and counts accurately and never block `focusCatchID` navigation.
- Standard / Hybrid / Satellite toggle works in both `CatchMapView` and `ManualLocationPicker` and persists across app restarts.
- No schema, backend, sync, or third-party dependency changes.
- `make ci` passes cleanly.
