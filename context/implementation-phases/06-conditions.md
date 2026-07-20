# Phase 06 — Weather and Water Conditions

**Status:** Ready
**Depends on:** Phase 05 complete  
**Primary stories:** A4 (conditions subset), B1, B5, E5

## Goal

Add consistent weather and water observations that remain fully editable offline and receive optional,
non-blocking Open-Meteo suggestions when coordinates, time, and connectivity are available.

## User-visible outcome

- Add/Edit Catch supports air temperature, sky condition, water temperature, and water clarity.
- Air temperature and sky condition may be suggested from Open-Meteo using coordinates and caught time.
- Suggested values are distinguishable and always overridable.
- Manual entry works without coordinates or connectivity.
- Failed, slow, or unavailable weather lookup never blocks saving.
- Catch cards/detail display the appropriate condition values and SF Symbol weather icon.

## Backend slice

- Add nullable `air_temp_f`, `sky_condition`, `water_temp_f`, and `water_clarity` Catch columns.
- Add closed-value constraints matching the PRD enums.
- Store observations only; do not persist redundant icon names or raw API responses.
- Cover the new fields with existing owner-only update and sync behavior.

## iOS/local slice

- Add typed domain values for sky condition and water clarity with forward-compatible decoding behavior.
- Add decimal parsing/formatting for Fahrenheit values.
- Implement an injected Open-Meteo client with timeout, cancellation, and deterministic DTO mapping.
- Finalize and test WMO weather-code → `skyCondition` mapping.
- Make enrichment explicit draft behavior: user edits win over a late response.
- Avoid repeated requests when coordinate/time inputs have not materially changed.
- Add structured pickers and accessible weather/water presentation.

## Implementation sequence

1. Record the WMO mapping, request timing, timeout/cache, and user-override rules.
2. Apply and test remote/local schema migrations.
3. Build typed values, API adapter, and mapping tests with fixtures.
4. Integrate non-blocking suggestions into the Catch draft.
5. Build manual controls and Catch card/detail presentation.
6. Exercise offline, timeout, API error, late-response, and edited-value scenarios.
7. Deploy and verify the slice through TestFlight.

## Verification

- Unit: enum round trips, WMO mapping, numeric formatting, suggestion/override precedence.
- API: fixture-based responses; no test suite depends on live Open-Meteo availability.
- Device: online suggestion with GPS/time, manual offline entry, reconnect without unwanted overwrite.
- Regression: Catch save latency and reliability are unchanged when the weather service fails.

## Acceptance gate

- All four condition fields are optional and work manually offline.
- Valid online inputs can produce editable suggestions.
- A user-edited field is never replaced by a late API response.
- Stored values recover correctly on another device and render the expected icon.
- API failure cannot prevent saving or corrupt an existing Catch.

## Explicit non-goals

Forecasts; water-temperature APIs; precipitation totals; historical condition analytics; background
refresh; storing raw provider payloads; A4's structured Tackle Box gear path (Phase 08).

## Closeout record

- TestFlight build: _TBD_
- Schema/WMO decision references: _TBD_
- Automated checks: _TBD_
- Online/offline device evidence: _TBD_
