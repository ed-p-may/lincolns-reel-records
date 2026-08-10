# Phase 01 — Local metadata extraction and guarded form defaults

**Status:** Complete
**Depends on:** Completed Catch CRUD, Location, Conditions, and multi-photo phases

## Goal

Carry a selected or captured photo's available timestamp and GPS coordinate into a new Add Catch form
without changing explicit user input or any persisted photo/data contract.

## Implementation sequence

1. Add a small typed metadata model and ImageIO extractor for EXIF/TIFF capture dates and GPS values.
2. Preserve library asset encoding where possible and extract metadata before staging normalizes images;
   pass camera metadata through the same typed boundary.
3. Add a field-source draft that accepts only the first available automatic value and locks when the
   user edits date/time or changes/clears the pin.
4. Connect the editor callback to new Add Catch only; let the existing weather task react to the new
   coordinate/time state.
5. Add focused extractor and precedence tests plus a deterministic UI scenario covering visible date,
   pin, and manual override behavior.
6. Run `simplify`, `docs-pass`, and `make ci`, then archive and merge through a squash PR.

## Touch points

- `ReelRecords/Photos/PhotoCaptureMetadata.swift`
- `ReelRecords/Photos/CatchPhotoViews.swift`
- `ReelRecords/Photos/PhotoFileStore.swift`
- `ReelRecords/Catches/AddCatchView.swift`
- `ReelRecords/Catches/AddCatchFormSections.swift`
- `ReelRecords/App/AppDependencies.swift`
- `ReelRecordsTests/PhotoCaptureMetadataTests.swift`
- `ReelRecordsUITests/PhotoMetadataDefaultsUITests.swift`
- `context/PRD.md`
- `context/user-stories.md`

## Verification

- Unit: EXIF timestamp with offset, TIFF fallback, signed GPS, partial/malformed metadata.
- State unit: first available value, multi-photo field fallback, manual date/pin lockout.
- UI: new form accepts deterministic photo metadata, shows the captured date/pin, and preserves a
  subsequent manual edit.
- Regression: photo selection/camera staging, reorder/removal, Add/Edit Catch, weather, location, sync,
  and database policies.
- Gate: `make ci`.

## Exit criteria

- All Issue #3 acceptance criteria are implemented and covered.
- Planning and canonical product docs reflect the final behavior.
- No schema, migration, backend, remote-storage, or broad Photo Library access change.
