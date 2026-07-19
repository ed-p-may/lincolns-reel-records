# Phase 05 — Location and Map

**Status:** Planned  
**Depends on:** Phase 04 complete  
**Primary stories:** A5, D1, D2, E5

## Goal

Carry a catch's real location from field capture or manual placement through offline persistence,
Supabase synchronization, MapKit browsing, and Catch Detail navigation.

## User-visible outcome

- Add Catch requests when-in-use location only when location capture is used.
- Current GPS coordinates can populate a draft without blocking the save.
- A named spot remains independently editable.
- Denied, unavailable, inaccurate, or later-entered catches can use a manual pin/search flow.
- Map shows the user's geocoded catches as selectable pins with a selected Catch card.
- Map header shows catches with coordinates and derived normalized spot counts.
- Catch Detail's mini-map opens Map focused on that Catch.
- Catches without coordinates remain valid and are represented honestly.

## Backend slice

- Add nullable double-precision latitude and longitude columns with valid-range constraints.
- Preserve `location` as the human name; coordinates do not create a stored Spot entity.
- Confirm location fields are covered by existing owner-only RLS and sync conflict behavior.
- Add indexes only if measured local/remote query behavior requires them.

## iOS/local slice

- Extend local/transport models and migrations for coordinates.
- Add a Core Location adapter with explicit authorization and accuracy states.
- Define acceptance/rejection behavior for stale or low-accuracy fixes.
- Design and build the unresolved manual pin-drop/map-search interface in the existing design language.
- Build MapKit pins, selection, map camera behavior, and the selected Catch card.
- Derive displayed spot counts by trimmed, case-insensitive exact location-name matching.
- Keep local Catch cards and coordinate data available offline; show an honest offline state if uncached
  Apple basemap imagery is unavailable rather than treating missing tiles as missing Catch data.

## Implementation sequence

1. Record location accuracy, permission timing, manual-search provider, and fallback decisions.
2. Create the manual-location design and acceptance states before implementation.
3. Apply remote/local schema migrations and mapping tests.
4. Implement GPS capture and non-blocking draft integration.
5. Implement manual pin/search fallback.
6. Build Map tab, pins, selection card, detail mini-map, and focused navigation.
7. Test permissions, no-signal behavior, spot normalization, and second-device recovery.
8. Deploy and verify the slice through TestFlight.

## Verification

- Unit: coordinate validation, accuracy/staleness decisions, spot-name normalization/counting.
- Permission: not determined, allowed, denied, restricted, and location services disabled.
- Device: real GPS capture outdoors, manual correction, airplane-mode save, relaunch, and sync.
- Map: zero pins, one pin, overlapping pins, missing coordinates, selected/focused navigation.
- Privacy: location usage descriptions are accurate and coordinates remain owner-private.

## Acceptance gate

- GPS capture never blocks a Catch save.
- Manual fallback works after denial and for a historical catch.
- Stored coordinates survive offline relaunch, synchronize, and recover on another device.
- Map pins and Catch Detail navigation reference the correct Catch.
- Derived spot counts follow the PRD normalization rule exactly.

## Explicit non-goals

First-class Spot records; proximity clustering; public/shared maps; background location; route tracking;
regulations or lake-boundary data.

## Closeout record

- TestFlight build: _TBD_
- Location decisions/design evidence: _TBD_
- Automated checks: _TBD_
- Real-device permission/GPS evidence: _TBD_
