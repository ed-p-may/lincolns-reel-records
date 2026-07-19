# Phase 03 — Logbook and Catch Detail

**Status:** Planned  
**Depends on:** Phase 02 complete  
**Primary stories:** B1/B5 foundation, B2, B3, B4

## Goal

Make the local Catch collection genuinely useful to revisit: a polished Log, combinable discovery
controls, and a complete detail presentation for all data delivered so far.

## User-visible outcome

- Log cards show the available measurements, species, spot name, date, lure text, and Released/Kept.
- No-photo records use the intentional design-system placeholder.
- Search matches species, location, lure text, and notes as the user types.
- Species chips derive from the user's distinct stored values.
- Sort choices are Recent, Heaviest, and Longest and combine with search/species filtering.
- Tapping a card opens Catch Detail; dismissing returns to the previous Log position and controls.

## Backend slice

- No new stored entity is expected.
- Confirm queries and indexes needed for initial pull ordering and practical dataset size.
- Do not move search/filter/sort to the server: offline browsing operates on the local cache.

## iOS/local slice

- Implement pure, testable search/filter/sort derivations over locally stored catches.
- Specify deterministic behavior for nil weight/length and equal sort values.
- Build reusable Catch card, badges, chips, search field, sort control, and placeholder image.
- Build Catch Detail for every Phase 02 field with Edit/Delete entry points intact.
- Preserve selected filters, search query, sort, and scroll/navigation context while opening Detail.
- Add empty states for no catches and no matching results.

## Implementation sequence

1. Fix discovery semantics and tie-break rules in tests.
2. Build the local query/derivation layer.
3. Build Log cards and empty/result states.
4. Add search, species/Saved-ready filter composition, and sort controls.
5. Build Catch Detail and return-context behavior.
6. Verify representative large-enough fixtures, accessibility, and device performance.
7. Deploy and verify the slice through TestFlight.

## Verification

- Unit: normalization, combined predicates, species derivation, nil-aware sorting, tie-breaks.
- UI: empty Log, no results, long notes/species/location, keyboard behavior, preserved context.
- Accessibility: Dynamic Type, VoiceOver labels/order, adequate tap targets and contrast.
- Device: browsing/search/sort remain fully functional in airplane mode.

## Acceptance gate

- B2–B4 pass completely. B1/B5 pass for every field delivered through Phase 02; their photo,
  conditions/gear, and mini-map criteria close in Phases 04, 06/08, and 05 respectively.
- Search, species filter, and sort combine without inconsistent results.
- Catch Detail shows all data delivered through Phase 02 and retains Edit/Delete.
- Log interaction stays smooth with a representative seeded collection.
- Earlier offline/sync behavior remains unchanged.

## Explicit non-goals

Photo acquisition/carousel; MapKit; conditions; dashboard stats; Saved filter behavior until Phase 10;
TackleItem cards; share image.

## Closeout record

- TestFlight build: _TBD_
- Automated checks: _TBD_
- Accessibility/device evidence: _TBD_
