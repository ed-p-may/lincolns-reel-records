# Photo Metadata Defaults

**Source:** [GitHub Issue #3](https://github.com/ed-p-may/lincolns-reel-records/issues/3)
**Status:** Complete
**Owner:** Reel Records iOS app

## Goal

Reduce manual entry when a new catch photo contains its capture date/time or GPS coordinate, without
overwriting an angler's explicit form choices or requiring metadata to save.

## Product contract

- Applies only while logging a new catch. Editing an existing catch never imports field defaults.
- The first imported metadata value for each field may replace that field's automatic form default.
  Later photos do not keep changing an already populated field.
- A photo capture timestamp replaces the initial `now` date/time only until the angler edits the Date
  Picker. A manual date/time always wins.
- A valid photo GPS coordinate fills the catch pin only while no pin has been captured, selected, or
  explicitly cleared by the angler. Photo metadata does not invent or reverse-geocode a named spot.
- Library imports use the selected asset's current representation when possible, then read metadata
  locally before the existing normalization pipeline removes it. Camera imports read the capture
  metadata returned by `UIImagePickerController`.
- Missing, malformed, privacy-stripped, or unavailable metadata is ignored. Existing manual controls
  remain the fallback and photo import/save behavior continues normally.
- Metadata stays transient form input. There is no schema, migration, backend, Storage, sync, or new
  persisted-setting change.

## Multiple-photo behavior

Metadata is resolved in import order and independently by field. For example, if the first photo has a
timestamp but no GPS coordinate, the next photo may still supply the pin; it cannot replace the accepted
timestamp. Removing or reordering a photo does not silently rewrite form values the angler can already
see and edit.

## Acceptance criteria

1. A new-catch photo with a valid capture timestamp updates the visible caught date/time.
2. A new-catch photo with valid GPS metadata updates the visible pin and triggers the existing weather
   suggestion path for that coordinate and caught time.
3. A manually edited date/time or manually captured/selected/cleared pin is not overwritten.
4. Partial, malformed, or absent metadata leaves each unavailable field on its existing fallback.
5. Existing-catch editing, multi-photo ordering, offline staging, sync, and photo normalization remain
   unchanged.

## Non-goals

- Reverse geocoding GPS into a named fishing spot.
- Persisting original EXIF/GPS metadata alongside normalized catch photos.
- Reading species, measurements, conditions, lure, notes, or other fields from an image.
- Requesting broad Photo Library access solely to inspect unselected assets.
