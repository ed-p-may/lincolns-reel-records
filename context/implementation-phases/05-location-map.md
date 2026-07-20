# Phase 05 — Location and Map

**Status:** Complete
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
7. Test deterministic permission mapping, no-signal/manual behavior, spot normalization, persistence,
   sync transport, and focused Map navigation locally and in Simulator.
8. Defer hosted migration, signed TestFlight, physical GPS/permission, offline/reconnect, and
   fresh-device recovery to the consolidated Phase 11 gate.

## Location interaction design

- Add/Edit Catch keeps **Named spot** as a normal text field. A separate location card shows one of:
  no coordinates, requesting permission/fix, accepted coordinates with accuracy, or a concise
  denied/unavailable/inaccurate error. Save is never disabled by this card.
- **Use Current Location** is the only action that requests permission. **Choose on Map** opens the
  manual sheet in every permission state; **Clear Pin** removes only coordinates.
- The manual sheet has an optional Apple place-search field/result list and a map. Selecting a result
  centers and drops the draft pin; tapping the map moves it. **Use This Pin** commits the pair to the
  Catch draft, while Cancel leaves the prior pair unchanged. Search/offline errors stay inline.
- The Map tab shows the local catch/derived-spot count, an honest no-coordinate empty state, MapKit
  annotations, and one bottom selected-Catch card. Opening from Catch Detail selects that Catch and
  centers its coordinate; a Catch without coordinates shows “Location not pinned” instead of a fake map.
- Accessibility labels state species, named spot, and coordinate availability; every control retains a
  44-point target and the selected pin does not rely on color alone.

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

- TestFlight build: no Phase 05 build. Signed `0.1.0 (3)` remains the latest hosted beta; the coordinate
  migration and a final signed build are deferred to Phase 11.
- Location decisions/design evidence: `context/decisions.md`, “Foreground location capture and manual
  MapKit fallback contract,” plus the interaction states above.
- Automated checks: `make ci` passes with 35 Swift unit/integration tests, 6 Simulator UI tests, and
  49 local pgTAP assertions. This includes coordinate/policy, repository/sync/relaunch, manual
  tap-to-pin, and Detail → the specific selected Catch pin coverage.
- Simulator evidence: two real-coordinate seeded catches render as two pins/two normalized spots;
  manual placement commits a valid coordinate pair without requesting GPS; a Rainbow Trout Detail
  mini-map opens Map with Rainbow Trout selected and reopens the correct Detail.
- Real-device permission/GPS evidence: deferred to Phase 11, including outdoor accuracy, every system
  permission state, denial recovery, manual correction, airplane-mode save/relaunch, and reconnect.
