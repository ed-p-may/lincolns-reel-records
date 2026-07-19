# Phase 03 — Logbook and Catch Detail

**Status:** Complete
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

- TestFlight build: no Phase 03 upload; signed build `0.1.0 (3)` remains the hosted Phase 01 build.
  Hosted deployment and final physical-device acceptance are consolidated in Phase 11.
- Backend/index review: no migration was required. Phase 01 already indexes owner/newest-first pulls,
  and Phase 02 adds owner/update and owner/tombstone indexes; discovery remains an offline local-cache
  derivation as planned.
- Automated checks: `make ci` passes with strict formatting/lint, 25 Swift tests, 3 iPhone 17 Pro
  Simulator UI tests, and 23 local pgTAP assertions after a clean local database reset.
- Discovery evidence: unit tests cover normalized search across every Phase 02 text field, distinct
  case-insensitive species, composable predicates, nil-last measurement ordering, deterministic ties,
  and a 1,000-record derivation averaging approximately 0.003 seconds. Simulator UI coverage combines
  search/species/sort, exercises no-results clearing, and confirms query/sort state survives Detail.
- Accessibility/Simulator evidence: the Log and Detail were visually inspected at standard and largest
  accessibility text sizes on iPhone 17 Pro / iOS 26.5. The largest-size UI test navigates a deliberately
  long species record and verifies its measurements, notes, and dismissal path without overlapping
  content. Final VoiceOver, physical airplane-mode, reconnect, and fresh-device recovery remain in
  Phase 11.
