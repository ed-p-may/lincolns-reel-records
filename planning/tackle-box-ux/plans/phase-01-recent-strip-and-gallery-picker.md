---
DATE: 2026-11-23
STATUS: Implemented on branch
AUTHOR: Antigravity
ISSUE: https://github.com/ed-p-may/lincolns-reel-records/issues/11
---

# Phase 01 — Recently-used strip and full-screen gallery picker

**Date:** 2026-11-23
**Status:** Implemented on branch
**Depends on:** Completed Phase 08 (Tackle Box) and Last-used Catch Defaults
**Source:** [GitHub Issue #11](https://github.com/ed-p-may/lincolns-reel-records/issues/11)

## Goal

Replace the full-catalog horizontal scroll in `CatchTackleSection` with a compact **Recently Used** strip (last 5 distinct selectable tackle items), and add a full-screen tile gallery picker (`TacklePickerView`) organized into **Recently Used** followed by `TackleItemType` sections — with zero schema, migration, or sync changes.

## Implementation sequence

1. **Pure discovery & grouping helpers (`TackleDiscovery`):**
   - Extract or extend `TackleDiscovery` (in `ReelRecords/Tackle/TackleRepository.swift` or a dedicated `ReelRecords/Tackle/TackleDiscovery.swift` to keep file lengths well under `.swiftlint.yml`'s 500-line warning):
     - `struct TackleTypeSection: Identifiable, Equatable, Sendable { let type: TackleItemType; let items: [TackleItem]; var id: TackleItemType { type } }`
     - `static func recentlyUsed(from items: [TackleItem], catches: [CatchItem], limit: Int = 5) -> [TackleItem]`:
       - Build a `[UUID: TackleItem]` map of `items.filter(\.isSelectable)`.
       - Sort visible catches (`deletedAt == nil`) by `caughtAt` descending, `createdAt` descending, `id.uuidString` ascending.
       - Iterate sorted catches, skip nil `tackleItemID`, skip already-seen IDs, append matching selectable `TackleItem`, stop at `limit`.
     - `static func inlineStripItems(from items: [TackleItem], recentItems: [TackleItem], limit: Int = 5) -> (items: [TackleItem], isRecent: Bool)`:
       - Returns `(Array(recentItems.prefix(limit)), true)` when `recentItems` is non-empty; otherwise `(Array(items.filter(\.isSelectable).prefix(limit)), false)`.
     - Update `TackleDiscovery.results(in:query:type:)` to match `query` case/diacritic/width-insensitively across `item.name`, `item.brand`, and `item.color` (so both `TacklePickerView` and `TackleBoxView` share the expanded search).
     - `static func sectionsByType(in items: [TackleItem], query: String = "", type: TackleItemType? = nil) -> [TackleTypeSection]`:
       - Filters selectable items via `results(in:query:type:)`, groups by `TackleItemType`, preserves `TackleItemType.allCases` order, omits empty groups, and keeps items within each section sorted by `alphabeticallyPrecedes`.
     - `static func availableTypes(in items: [TackleItem]) -> [TackleItemType]`:
       - Distinct types present in `items.filter(\.isSelectable)` in `TackleItemType.allCases` order.

2. **Selected visual state on `TackleItemCard` (`ReelRecords/Tackle/TackleItemViews.swift`):**
   - Add `var isSelected = false` to `TackleItemCard`.
   - When `isSelected` is `true`, highlight the card border with `ReelTheme.accent` (`lineWidth: 2`) and display a compact checkmark badge in the top-trailing corner (or beside the color swatch) matching `TackleItemRow`'s selection affordance.
   - Keep `accessibilityElement(children: .combine)` and add `.accessibilityAddTraits(isSelected ? .isSelected : [])`.

3. **Full-screen gallery picker (`ReelRecords/Tackle/TacklePickerView.swift`):**
   - Create `struct TacklePickerView: View`:
     - Inputs: `ownerID: UUID`, `items: [TackleItem]`, `recentItems: [TackleItem]`, `selectedItemID: UUID?`, `onSelect: (TackleItem) -> Void`, `onCreated: (TackleItem) -> Void`, `onCancel: () -> Void`.
     - Local `@State`: `query = ""`, `selectedType: TackleItemType?`, `isAddingItem = false`.
     - `NavigationStack` with `ReelTheme.background`, inline title `"Choose Lure / Bait"`, leading `Cancel` button (`tackle.picker.cancel`), trailing `+` button (`tackle.picker.add`).
     - Search bar (`tackle.picker.search`) and horizontal `SelectionChip` bar (`All` + `TackleDiscovery.availableTypes(in: selectableItems)`) using identifiers `tackle.picker.type.all` and `tackle.picker.type.<rawValue>`.
     - Content:
       - Compute `sections = TackleDiscovery.sectionsByType(in: selectableItems, query: query, type: selectedType)`.
       - Show `Recently Used` section at the top when `!recentItems.isEmpty && query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedType == nil`.
       - Render sections in a 2-column `LazyVGrid` (`spacing: 13`) using SwiftUI `Section` with styled headers (icon + title + count, `.accessibilityAddTraits(.isHeader)`).
       - Tapping any `TackleItemCard` calls `onSelect(item)`.
       - Empty states:
         - Catalog empty: prompt to add first tackle item (`tackle.picker.empty.add`).
         - Search/filter empty: `"No matching tackle"` with `"Clear Filters"` button.
     - Sheet for `+`: presents `TackleItemEditor(ownerID: ownerID)` and calls `onCreated(item)` on save.

4. **Update `CatchTackleSection` (`ReelRecords/Catches/CatchTackleSection.swift`):**
   - Add `let recentItems: [TackleItem]` and `let onBrowse: () -> Void` parameters (preserving `items`, `selectedItemID`, `lureText`, `onAdd`, `onManage`).
   - Header row: `LURE / BAIT` on the left; compact `Browse All` button on the right when `!selectableItems.isEmpty`.
   - Keep `selectedItem` (`TackleItemRow`, `add.tackle.selected`) unchanged.
   - Replace the full-catalog `ForEach(items.filter(\.isSelectable))` inside `itemPicker` with `TackleDiscovery.inlineStripItems(from: items, recentItems: recentItems)`:
     - Show `RECENTLY USED` sub-label when `strip.isRecent`, or `TACKLE BOX` when falling back on cold start with items.
     - Render `addButton` (`add.tackle.new`) + `ForEach(strip.items)`.
   - Add a prominent **Browse Tackle Box** row (`add.tackle.browse`) showing `square.grid.2x2.fill`, `"Browse Tackle Box"`, count badge (`"\(selectableItems.count) items"`), and chevron when `!selectableItems.isEmpty`.
   - Keep `manageButton` (`add.tackle.manage`) below so catalog management remains reachable.

5. **Wire `AddCatchView` (`ReelRecords/Catches/AddCatchView.swift`):**
   - Keep `AddCatchView.swift` under 500 lines (currently 497 lines — extract any helper if needed).
   - Store `@State private var recentCatchHistory: [CatchItem] = []` (populated once when loading catches for `loadSpeciesOptions()`, avoiding a duplicate SwiftData fetch) and `@State private var isBrowsingTackle = false`.
   - Compute `recentTackleItems = TackleDiscovery.recentlyUsed(from: tackleItems, catches: recentCatchHistory)` and pass it into `CatchTackleSection` and `TacklePickerView`.
   - Add `.fullScreenCover(isPresented: $isBrowsingTackle)` presenting `TacklePickerView`:
     - `onSelect`: sets `selectedTackleItemID = item.id`, `isBrowsingTackle = false`.
     - `onCreated`: calls `loadTackleItems()`, sets `selectedTackleItemID = item.id`, `isBrowsingTackle = false`.
     - `onCancel`: sets `isBrowsingTackle = false`.

6. **Tests & verification:**
   - Unit tests in `ReelRecordsTests/TackleTests.swift`:
     - `recentlyUsed` returns at most 5 distinct selectable items ordered by most recent `caughtAt` (with `createdAt` and `id` tie-breakers).
     - Duplicate catches with the same lure do not duplicate entries.
     - Archived or soft-deleted tackle items and deleted catches are excluded, promoting the next most recent selectable item.
     - `inlineStripItems` falls back to up to 5 alphabetical active items when `recentItems` is empty.
     - `sectionsByType` groups by `TackleItemType.allCases` order, omits empty types, sorts alphabetically within each type, and respects search/type filters.
   - UI tests in `ReelRecordsUITests/TackleBoxUITests.swift`:
     - Verify `CatchTackleSection` shows the recent strip and `add.tackle.browse`.
     - Open full-screen gallery picker, verify `Recently Used` and type section headers, tap a tile in a type section, and confirm `add.tackle.selected` updates and picker dismisses.
     - Verify existing `testInlineTackleCreationLinksNewCatchAndOpensFromDetail` and `LastUsedDefaultsUITests` still pass untouched.
   - Run `make ci` (including `xcodegen generate` via `make test` since `TacklePickerView.swift` is a new file).

## Touch points

- `ReelRecords/Tackle/TackleDiscovery.swift` *(new, or extend `TackleRepository.swift`)*
- `ReelRecords/Tackle/TackleItemViews.swift` *(add `isSelected` styling to `TackleItemCard`)*
- `ReelRecords/Tackle/TacklePickerView.swift` *(new full-screen gallery picker)*
- `ReelRecords/Catches/CatchTackleSection.swift` *(compact recent strip + `Browse Tackle Box` trigger)*
- `ReelRecords/Catches/AddCatchView.swift` *(share loaded catches for recency, present `TacklePickerView`)*
- `ReelRecordsTests/TackleTests.swift`
- `ReelRecordsUITests/TackleBoxUITests.swift`
- `context/PRD.md`, `context/user-stories.md`, `context/decisions.md` *(updated on completion via `docs-pass`)*

## Exit criteria

- Log a Catch shows at most 5 recently used selectable tackle items in the inline horizontal strip (never the full catalog).
- Full-screen gallery picker opens in one tap from Log a Catch, displays `Recently Used` first followed by non-empty `TackleItemType` sections, and selects-and-dismisses on tile tap.
- Inline `+ New lure` works from both Log a Catch and the gallery picker.
- No SwiftData schema, Supabase migration, or sync changes.
- `make ci` passes with zero warnings or errors.
