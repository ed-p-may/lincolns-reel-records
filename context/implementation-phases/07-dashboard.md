# Phase 07 — Dashboard and Derived Insight

**Status:** Complete
**Depends on:** Phase 06 complete  
**Primary stories:** C1, C2, C3

## Goal

Turn the locally available Catch collection into a useful Home screen without adding stored summary
tables or making dashboard availability depend on the network.

## User-visible outcome

- Home greets the signed-in user with the current date and a prominent Log a Catch action.
- It shows total catches and the defined weekly trend.
- Stat tiles show biggest catch, top species, favorite spot, and distinct species this year.
- Recent catches open Catch Detail.
- Favorite spots show count/best fish and open Map in an appropriate focused state.
- Empty and partially populated logbooks produce intentional, non-misleading states.

## Backend slice

- No new tables or stored aggregates.
- Confirm initial/paginated synchronization provides the local dataset needed by v1-scale derivations.
- Do not add remote analytics or Realtime solely for the dashboard without measured need.

## iOS/local slice

- Implement all statistics as pure derivations over locally visible, non-deleted catches.
- Define calendar/time-zone semantics for “this week,” “this year,” and greeting periods.
- Define deterministic ties and missing-measurement behavior for biggest/top/favorite results.
- Build dashboard hero, stat tiles, recent carousel, and favorite-spots list from design tokens.
- Wire Add Catch, Catch Detail, and Map navigation through the existing router.
- Recompute efficiently when local Catch data changes; avoid a parallel cached statistics store.

## Implementation sequence

1. Record date boundaries, tie-breaks, and empty-state semantics.
2. Build fixture-driven pure derivations and tests.
3. Build Home states from empty through representative populated datasets.
4. Wire navigation to Add Catch, Catch Detail, and focused Map.
5. Measure recomputation/rendering with a representative upper-bound beta dataset.
6. Verify offline behavior and deploy through TestFlight.

## Verification

- Unit: totals, weekly trend, max, mode/ties, distinct counts, normalized spots, best-by-spot.
- Calendar: year/week boundaries, device time-zone changes, future or back-entered catches.
- UI: empty, one Catch, missing weights/locations/photos, long species/location names.
- Navigation: every dashboard entry returns to the expected context.
- Device: all statistics render correctly in airplane mode.

## Acceptance gate

- C1–C3 criteria pass using only the local cache.
- Every number is reproducible from stored catches and no summary value is persisted separately.
- Missing data is represented without invented zeros or misleading rankings.
- Dashboard actions reach the correct Add, Detail, and Map destinations.
- Performance is acceptable with the agreed representative dataset.

## Explicit non-goals

Charts beyond the specified tiles/breakdowns; prediction; streaks/gamification; server-side analytics;
notifications; Profile species-breakdown UI.

## Closeout record

- TestFlight build: no Phase 07 build; signed build `0.1.0 (3)` remains the latest hosted beta.
  Signed deployment and final physical-device acceptance are consolidated in Phase 11.
- Derivation decision references: [`../decisions.md`](../decisions.md), "Dashboard derivation and
  calendar contract" (2026-07-19).
- Automated/performance checks: `make ci` passes 56 Swift unit tests, 9 Simulator UI tests, and 59
  local pgTAP database/RLS tests with clean SwiftFormat and strict SwiftLint. Deriving a representative
  1,000-Catch dataset takes approximately 27 ms on the development Mac.
- Manual device evidence: the empty and populated Home states were inspected in iPhone 16 Pro
  Simulator, including Add, Detail, Log, and focused Map navigation. Physical airplane-mode,
  time-zone/date-boundary, reconnect, and fresh-install recovery checks are consolidated in Phase 11.
