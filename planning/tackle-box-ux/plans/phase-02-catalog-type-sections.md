---
DATE: 2026-11-23
STATUS: Scoped
AUTHOR: Antigravity
ISSUE: https://github.com/ed-p-may/lincolns-reel-records/issues/11
---

# Phase 02 — Type-grouped sections in Tackle Box catalog

**Date:** 2026-11-23
**Status:** Scoped
**Depends on:** Phase 01 (`TackleDiscovery.sectionsByType`)
**Source:** [GitHub Issue #11](https://github.com/ed-p-may/lincolns-reel-records/issues/11)

## Goal

Bring the same `TackleItemType` section grouping from `TacklePickerView` to `TackleBoxView` (`You → My Tackle Box`) so browsing and managing gear in the standalone catalog matches the gallery picker's visual structure.

## Implementation sequence

1. **Reuse `TackleDiscovery.sectionsByType` in `TackleBoxView`:**
   - Replace the flat `LazyVGrid` in `ReelRecords/Tackle/TackleBoxView.swift` with sectioned `LazyVGrid` rendering when `selectedType == nil` (showing each non-empty `TackleItemType` header with icon, label, and count).
   - When a specific `selectedType` chip is selected, keep the single-section grid (no redundant single section header, or a compact header).
   - Keep `Active` / `Archived` segmented control, search field (`tackle.search`), type filter chips (`tackle.type.*`), and tap-to-edit (`TackleItemEditor`) behavior unchanged.
2. **Share the section header component:**
   - Place a small reusable `TackleSectionHeader` view in `ReelRecords/Tackle/TackleItemViews.swift` used by both `TacklePickerView` and `TackleBoxView`.
3. **Tests & verification:**
   - Confirm `TackleBoxUITests.testTackleCatalogSearchTypeArchiveAndRestoreVisibility` passes without regression.
   - Add a UI test assertion confirming type section headers render in `TackleBoxView` when viewing `All`.
   - Run `make ci`.

## Touch points

- `ReelRecords/Tackle/TackleItemViews.swift` *(shared `TackleSectionHeader`)*
- `ReelRecords/Tackle/TackleBoxView.swift`
- `ReelRecordsUITests/TackleBoxUITests.swift`

## Exit criteria

- `TackleBoxView` groups active (and archived) tackle items into `TackleItemType` sections when `All` is selected.
- Existing search, type filter, archive/restore, and edit flows remain intact.
- `make ci` passes cleanly.
