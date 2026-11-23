---
DATE: 2026-11-23
STATUS: In progress
AUTHOR: Antigravity
ISSUE: https://github.com/ed-p-may/lincolns-reel-records/issues/11
---

# Tackle Box UX — Status

**Status:** In progress
**Next step:** Review and merge Phase 01 PR (`feat/tackle-box-ux-phase-01`), then implement Phase 02 (`plans/phase-02-catalog-type-sections.md`).
**Blockers:** None. All 4 product decisions resolved on 2026-11-23 (see [PRD.md](PRD.md#resolved-decisions-2026-11-23)).

## Phase inventory

| Phase | Plan | Scope | Status | Evidence |
|---|---|---|---|---|
| Phase 01 | [plans/phase-01-recent-strip-and-gallery-picker.md](plans/phase-01-recent-strip-and-gallery-picker.md) | Derived recently-used list (top 5), compact `CatchTackleSection` strip, shared `name`/`brand`/`color` search, and full-screen sectioned `TacklePickerView` | Implemented on branch | `make ci` pass: 0 lint violations (113 files), 145 unit tests, 31 UI tests, 99 DB tests |
| Phase 02 | [plans/phase-02-catalog-type-sections.md](plans/phase-02-catalog-type-sections.md) | Type-grouped sections in `TackleBoxView` when viewing "All" types | Scoped | — |

## Codebase notes verified during scoping (2026-11-23)

- `ReelRecords/Catches/CatchTackleSection.swift` currently renders `+ New lure` followed by **every** selectable `TackleItem` in a single horizontal `ScrollView`, plus a `Manage Tackle Box` button that opens `TackleBoxView` in edit-only mode.
- `ReelRecords/Catches/AddCatchView.swift` is 497 lines (3 lines under the `.swiftlint.yml` 500-line file-length warning) and already loads the owner's visible catches via `repository.list(ownerID: ownerID)` inside `loadSpeciesOptions()`. New picker UI and grouping helpers should live in dedicated files (`TacklePickerView.swift`, `TackleDiscovery` extension) so `AddCatchView.swift` stays under the lint limit.
- `ReelRecords/Tackle/TackleRepository.swift` defines `TackleDiscovery` with alphabetical sorting (`alphabeticallyPrecedes`) and search/type filtering (`results(in:query:type:)`).
- `ReelRecords/Tackle/TackleItemViews.swift` defines `TackleItemCard` (2-column tile card with photo, type badge, color swatch, name, and size/brand metadata) and `TackleItemRow` (selected-item banner). `TackleItemCard` does not yet have a selected visual state (`isSelected`).
- Existing UI tests rely on `add.tackle.new`, `add.tackle.selected`, `add.tackle.manage`, and `tackle.*` identifiers in `TackleBoxUITests` and `LastUsedDefaultsUITests`. All existing identifiers remain intact.

## Verification plan (when implemented)

- Unit tests in `ReelRecordsTests/TackleTests.swift` (recency derivation, tie-breaking, archived/deleted exclusion, 5-item cap, fallback behavior, type-section grouping and ordering, search filtering).
- UI tests in `ReelRecordsUITests/TackleBoxUITests.swift` (recently-used strip ordering, opening full-screen gallery picker, selecting an item from a type section, inline creation from gallery picker).
- Full local gate: `make ci` (SwiftFormat, SwiftLint strict, unit + UI tests, local Supabase DB tests).
