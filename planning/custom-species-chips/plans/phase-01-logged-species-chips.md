# Phase 01 — Logged species as Add Catch chips

**Status:** Implemented on branch
**Depends on:** Completed Catch CRUD and Log discovery phases

## Goal

Show every species the owner has logged as an Add Catch chip after the seed list, and select it when
editing a catch that uses it.

## Implementation sequence

1. Add `CatchDiscovery.pickerSpecies(suggested:in:)`: the seed list, then `species(in:)` minus values
   that normalize to a seed species.
2. In `AddCatchView`, load the chip list once from `repository.list(ownerID:)` when the form opens,
   and move an edited catch's species from the custom field to its chip when an exact chip exists.
3. Unit coverage for seed order, case-insensitive merging and seed exclusion.
4. UI coverage: the logbook seed's custom species appears as an unselected chip on a new Log a Catch
   form and as the selected chip when its catch is edited. The test types nothing: typing with the
   software keyboard up left simulator predictive text that broke later Tracer Bullet typing.
5. `make ci`.

## Touch points

- `ReelRecords/Catches/CatchDiscovery.swift`
- `ReelRecords/Catches/AddCatchView.swift`, `ReelRecords/Catches/AddCatchFormSections.swift` (species section moved to `CatchSpeciesEditor`)
- `ReelRecordsTests/CatchDiscoveryTests.swift`
- `ReelRecordsUITests/CustomSpeciesUITests.swift`
- `context/PRD.md`, `context/user-stories.md`, `context/decisions.md`

## Verification evidence

- Focused unit: `CatchDiscoveryTests` 8 of 8 pass, including
  `testPickerSpeciesKeepsSeedOrderThenAddsLoggedCustomSpecies`.
- Focused UI: `CustomSpeciesUITests.testLoggedCustomSpeciesBecomesSelectableChip` passes, followed by
  the two Tracer Bullet typing tests, on iPhone 17 Pro / iOS 26.5.
- Gate: `make ci` on the PR head; counts are in the PR body.

## Exit criteria

- All Issue #13 acceptance criteria are implemented and covered.
- No schema, migration, backend or remote-storage behavior changes.
