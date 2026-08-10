# Phase 01 — Same-day Add Catch defaults

**Status:** Complete
**Depends on:** Completed Catch CRUD, Conditions, Location, and Tackle Box phases

## Goal

Prefill the four Issue #2 field groups from the latest owner-scoped catch on the same local day while
preserving fresh-location capture and weather suggestion precedence.

## Implementation sequence

1. Add a bounded owner/day repository query for the latest catch plus a value mapper that exposes only
   the allowed default fields.
2. Load those defaults once for new Add Catch forms before loading the selected Tackle Box item.
3. Represent carried sky as an explicit fallback so a weather suggestion may replace it and a manual
   edit may still lock the field.
4. Add unit coverage for same-day selection, day-boundary reset, allowed-field mapping, and weather
   precedence.
5. Add UI coverage proving the new form prefills the four field groups but does not reuse the saved pin.
6. Run `simplify`, `docs-pass`, and `make ci`.

## Touch points

- `ReelRecords/Catches/NewCatchDefaults.swift`
- `ReelRecords/Catches/AddCatchView.swift`
- `ReelRecords/Conditions/ConditionModels.swift`
- `ReelRecords/App/AppDependencies.swift`
- `ReelRecordsTests/NewCatchDefaultsTests.swift`
- `ReelRecordsTests/ConditionTests.swift`
- `ReelRecordsUITests/LastUsedDefaultsUITests.swift`
- `context/PRD.md`
- `context/user-stories.md`

## Verification

- Unit: same-day/latest selection, local-day boundary, carried values, omitted coordinate, empty result.
- Conditions unit: weather replaces carried sky; manual edit blocks replacement.
- UI: seeded same-day catch → new form carries spot/tackle/lure/sky/clarity and has no pin.
- Regression: Add Catch create/edit, manual conditions, Tackle Box selection, location, sync, and database.
- Gate: `make ci`.

## Verification evidence

- Focused unit: 20 resolver, repository, and conditions tests pass.
- Focused UI: same-day spot/tackle/lure/sky/clarity defaults pass with no reused coordinate.
- Formatting/lint: SwiftFormat and strict SwiftLint pass across 81 Swift files with zero violations.
- App tests: 89 unit tests and 18 UI tests pass on iPhone 17 Pro / iOS 26.5.
- Database tests: all 99 tests across 8 SQL files pass.

## Exit criteria

- All Issue #2 acceptance criteria are implemented and covered.
- Planning and canonical product docs reflect the behavior.
- No schema, migration, backend, or remote-storage behavior changes.
