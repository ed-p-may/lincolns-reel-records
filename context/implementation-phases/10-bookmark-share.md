# Phase 10 — Bookmark and Per-Catch Share

**Status:** Planned  
**Depends on:** Phase 04 complete  
**Primary stories:** B6

## Goal

Complete the private favorite workflow and generate a deliberate, branded catch image that users can
send through the native iOS share sheet without creating any social or inter-user feature.

## User-visible outcome

- Bookmark toggles from Catch Detail and persists immediately offline.
- Log provides a Saved filter that composes with search, species, and sort.
- Share renders the selected Catch as a polished image containing the agreed photo/placeholder,
  species, measurements, spot, and caught date.
- The native share sheet sends or saves the generated image.
- Missing photo, measurement, or location produces a valid composition rather than empty labels.

## Backend slice

- Add `bookmarked` to Catch with a false default if not already introduced.
- Cover it with existing owner-only update and synchronization behavior.
- No share artifact is uploaded or persisted remotely by default.

## iOS/local slice

- Extend the Catch model/mapping and local migration for bookmark state.
- Add Saved as a composable Log predicate using Phase 03's derivation pipeline.
- Design the unresolved share-image composition in the established visual language before building it.
- Implement a deterministic SwiftUI/image renderer at intentional pixel dimensions and scale.
- Exclude private data not listed in the approved composition.
- Create temporary share files with cleanup after the activity completes or expires.
- Handle very large photos and no-photo catches without excessive memory use.

## Implementation sequence

1. Approve the share-image layout, dimensions, metadata, and temporary-file policy.
2. Apply bookmark migrations and mapping tests.
3. Implement bookmark toggle and Saved filter composition.
4. Build fixture-driven share rendering for complete and sparse catches.
5. Integrate the native share sheet and temporary-file cleanup.
6. Test memory, accessibility, cancellation, and representative destinations.
7. Deploy and verify the slice through TestFlight.

## Verification

- Unit: bookmark sync transitions and Saved/search/species/sort combinations.
- Snapshot/image: complete Catch, no photo, missing measurements, long species/location, multiple photos.
- Privacy: only explicitly approved fields appear in the output image; no hidden EXIF requirement.
- Device: Messages/Mail/Save Image or available representative destinations; cancel share cleanly.
- Recovery: bookmark state survives relaunch, offline mutation, and second-device synchronization.

## Acceptance gate

- Bookmark and Saved filtering satisfy B6 without inconsistent combined filters.
- Shared output is a composed image, not a link or app-internal social post.
- Sparse catches produce intentional images.
- Temporary share artifacts have a tested cleanup path.
- Earlier Catch, photo, and Log behavior remains intact.

## Explicit non-goals

Public posts; feeds; other-user access; server-hosted share links; full-logbook PDF/CSV export; automatic
watermarks beyond the approved composition.

## Closeout record

- TestFlight build: _TBD_
- Share design reference: _TBD_
- Automated/image checks: _TBD_
- Real-device share evidence: _TBD_
