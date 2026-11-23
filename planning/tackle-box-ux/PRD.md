---
DATE: 2026-11-23
STATUS: Scoped
AUTHOR: Antigravity
ISSUE: https://github.com/ed-p-may/lincolns-reel-records/issues/11
---

# Tackle Box UX — PRD

**Source:** [GitHub Issue #11](https://github.com/ed-p-may/lincolns-reel-records/issues/11)
**Owner:** Reel Records iOS app (`ReelRecords/Catches/`, `ReelRecords/Tackle/`)
**Canonical docs affected:** `context/PRD.md` (§6.5, §6.8), `context/user-stories.md` (A7, Epic F), `context/decisions.md`

## Problem

When logging a catch, selecting a lure or bait from the Tackle Box is too slow once an angler has more than a handful of saved items:

1. `CatchTackleSection` renders the entire active Tackle Box in a single horizontal strip of small cards, forcing long sideways scrolling in alphabetical order even when the angler keeps rotating through the same few lures.
2. Tapping **Manage Tackle Box** opens `TackleBoxView`, which is an edit-only catalog — tapping a card opens `TackleItemEditor` instead of selecting the lure for the catch — and its grid is a flat alphabetical list rather than organized by lure type.

## Goals

1. **Fast inline selection on Log a Catch:** Show a **Recently Used** horizontal strip (the last 5 distinct selectable tackle items used across the angler's catches) under **Lure / Bait**, instead of dumping the entire Tackle Box into the horizontal scroll.
2. **Fast visual browsing across the whole box:** Provide a clear one-tap path from **Lure / Bait** to a **full-screen gallery (tile) picker** where tapping a tile selects it for the catch and returns immediately.
3. **Organized by lure type:** In the full-screen gallery picker, show **Recently Used** first, followed by sections grouped by `TackleItemType` so anglers can scan visually by category (`Soft Plastic`, `Crankbait`, `Spinnerbait`, `Jig`, `Topwater`, `Spoon`, `Fly`, `Live Bait`, `Other`).
4. **Zero backend or schema impact:** Derive recency and sections purely from existing local SwiftData records (`CatchItem` + `TackleItem`), preserving offline-first behavior, owner isolation, and sync.

## Non-goals

- Persisting a new `lastUsedAt` column on `tackle_items` or adding a Supabase migration.
- Adding custom user-defined lure categories beyond the existing 9 `TackleItemType` cases.
- Multi-select (a catch still links to at most one `tackleItemID`, plus optional free-text `lureText`).
- Changing catch-card or catch-detail tackle display, or changing how `Last-used Catch Defaults` pre-selects a same-day lure.

---

## Behavior contract

### 1. Deriving "Recently Used" tackle items

- **Source:** The signed-in owner's visible (non-deleted) `CatchItem` records and active selectable `TackleItem` records (`isSelectable == true`, i.e., `!archived && deletedAt == nil`).
- **Ordering:** Sort visible catches by:
  1. `caughtAt` descending
  2. `createdAt` descending (tie-breaker for identical timestamps)
  3. `id.uuidString` ascending (final deterministic tie-breaker)
- **Deduplication & filtering:**
  - Walk the sorted catches and take each non-nil `tackleItemID` the first time it appears.
  - Skip any `tackleItemID` that is missing, deleted, or archived in the owner's current tackle catalog.
  - Cap the result at **5 items** (`limit = 5`).
- **Consistency with edits and deletes:** Because recency is derived on load (and refreshed whenever tackle items change), archiving or deleting a tackle item immediately removes it from **Recently Used**, and logging or deleting a catch immediately updates the list on the next Log a Catch open.

### 2. Log a Catch — `CatchTackleSection` UX

Under the **LURE / BAIT** section in `AddCatchView`:

1. **Header row:**
   - Leading label: `LURE / BAIT` (existing style).
   - Trailing action (when selectable catalog items exist): compact accent link/button `Browse All` (or `All (N)`) that opens the full-screen gallery picker (`add.tackle.browse`).
2. **Selected item banner (unchanged):**
   - If `selectedItemID != nil`, render `TackleItemRow(item: selectedItem, isSelected: true)` (`add.tackle.selected`). Tapping clears `selectedItemID`.
   - Historical/archived items on an edited catch still render here with their `ARCHIVED` / `UNAVAILABLE` badge.
3. **Inline horizontal strip:**
   - **When `recentItems` is non-empty (1–5 items):**
     - Sub-label: `RECENTLY USED` (small metadata caption).
     - Horizontal `ScrollView`: `+ New lure` (`add.tackle.new`) + the 1–5 `recentItems` cards (in recency order, most recent first).
     - If the catalog has additional selectable items beyond the strip (or always when catalog is non-empty), include a trailing `Browse all` tile or rely on the dedicated full-width **Browse Tackle Box** button directly below.
   - **When `recentItems` is empty and active catalog is non-empty (cold start — angler added lures but has not logged a catch with them yet):**
     - Sub-label: `TACKLE BOX` (avoids a misleading "Recently Used" label).
     - Horizontal `ScrollView`: `+ New lure` (`add.tackle.new`) + up to the first 5 selectable items alphabetically.
   - **When active catalog is completely empty:**
     - Horizontal `ScrollView`: `+ New lure` (`add.tackle.new`) only, with a short hint ("Add your first lure or bait to reuse it here.").
4. **Full-screen gallery action + manage action:**
   - Primary row button (when active catalog is non-empty): **Browse Tackle Box** (`add.tackle.browse`) showing grid icon (`square.grid.2x2.fill`), item count (e.g., `18 items`), and chevron → opens the full-screen `TacklePickerView`.
   - Secondary row or toolbar access: **Manage Tackle Box** (`add.tackle.manage`) remains available (either as a compact secondary button below or via the existing row) so anglers can edit/archive gear without breaking existing flows.
5. **Free-text fallback (unchanged):**
   - `TextField("One-off lure or bait (optional)", text: $lureText)` (`add.lure`) + helper caption.

### 3. Full-screen Tackle Gallery Picker (`TacklePickerView`)

Presented via `.fullScreenCover` from `AddCatchView`:

- **Chrome:**
  - `NavigationStack` with dark `ReelTheme.background`, inline title `"Choose Lure / Bait"`.
  - Leading toolbar button: `"Cancel"` (`tackle.picker.cancel`) dismisses without changing `selectedItemID`.
  - Trailing toolbar button: `+` (`tackle.picker.add`) opens `TackleItemEditor(ownerID:)` in a sheet; saving a new item reloads the catalog, selects the new item, and dismisses the gallery picker directly back to Log a Catch.
- **Search & quick type filter:**
  - Search field (`tackle.picker.search`) matching against item `name`, `brand`, and `color` (case/diacritic/width-insensitive via `CatchDiscovery.normalized`, shared across both `TacklePickerView` and `TackleBoxView` in `TackleDiscovery.results`).
  - Horizontal `SelectionChip` bar (`All` + only the `TackleItemType`s present in the angler's active catalog, in `TackleItemType.allCases` order) so anglers with large boxes can jump to one category in a single tap.
- **Gallery layout (2-column tile grid):**
  - Uses a 2-column `LazyVGrid` (`spacing: 13`, matching `TackleBoxView`) rendering `TackleItemCard(item:isSelected:)`.
  - `TackleItemCard` gains an optional `isSelected: Bool = false` parameter: when `true`, renders a 2pt `ReelTheme.accent` border and a compact checkmark badge so the currently selected lure stands out immediately.
  - **Section order when `query` is empty and `selectedType == nil`:**
    1. **`Recently Used`** (only when `recentItems` is non-empty): header with `clock.arrow.circlepath` icon, `"Recently Used"` title, and count (`up to 5`). Tiles in recency order.
    2. **One section per non-empty `TackleItemType`** in `TackleItemType.allCases` order (`Soft Plastic`, `Crankbait`, `Spinnerbait`, `Jig`, `Topwater`, `Spoon`, `Fly`, `Live Bait`, `Other`): header with `type.systemImage`, `type.label`, and count (e.g. `Soft Plastic · 6`). Tiles within each section sorted alphabetically (`TackleDiscovery.alphabeticallyPrecedes`).
  - **Section order when searching or filtering by a single type:**
    - Hide the duplicate `Recently Used` section while a search query or specific type filter is active, and show only the matching type sections (or an empty state `"No matching tackle"` with a button to clear filters or add a new item).
  - **Duplicate policy (Recently Used vs. Type sections):**
    - Items in `Recently Used` **also remain** in their canonical `TackleItemType` section below, so browsing by category is always complete and predictable.
- **Selection behavior:**
  - Tapping any tile sets `selectedTackleItemID = item.id` and dismisses `TacklePickerView` back to `AddCatchView`.
  - Only selectable (`!archived && deletedAt == nil`) items appear in the gallery picker.

### 4. Interactions with existing features

- **Same-day catch defaults (Issue #2):** `loadNewCatchDefaults()` still pre-selects the latest same-day catch's `tackleItemID`, which appears in the selected banner (`add.tackle.selected`) and as the first item in `Recently Used`.
- **Inline `+ New lure` on Log a Catch:** Creates the item, reloads tackle items, and selects it immediately in `add.tackle.selected`.
- **Editing an existing catch:** Preserves the catch's existing `tackleItemID` in `add.tackle.selected` even if it is archived or outside the top 5 recently used.
- **Accessibility:** Every section header uses `.accessibilityAddTraits(.isHeader)`. Tiles keep combined labels (`name`, `type`, metadata, and `"Selected"` trait when active) and stable accessibility identifiers (`tackle.picker.recent.<id>`, `tackle.picker.item.<id>`, `tackle.picker.section.<type.rawValue>`).

---

## Resolved decisions (2026-11-23)

1. **Cold-start strip (0 catches with tackle):** Show up to 5 active catalog items alphabetically labeled `TACKLE BOX`, so new anglers get one-tap picking before their first logged catch.
2. **Recently Used items in Type sections:** Keep them in their canonical `TackleItemType` section below as well (shortcut at top + complete categories below).
3. **Phase 02 (`TackleBoxView` catalog parity):** Included — group `TackleBoxView` (`You → My Tackle Box`) by `TackleItemType` when `All` is selected.
4. **Search scope:** Match `name`, `brand`, and `color` in both `TacklePickerView` and `TackleBoxView` via shared `TackleDiscovery.results`.

---

## Acceptance criteria

1. **Recently Used accuracy:** After logging catches with 7 distinct active tackle items, opening **Log a Catch** displays only the 5 most recently used items (most recent first) in the inline horizontal strip — not all 7+.
2. **Deduplication & archival safety:** Logging multiple catches with the same lure does not duplicate it in **Recently Used**; archiving or deleting a recently used lure removes it from **Recently Used** and promotes the next most recent selectable lure.
3. **Full-screen gallery picker:** Tapping **Browse Tackle Box** from **Log a Catch** opens a full-screen tile gallery showing **Recently Used** first, followed by sections for each non-empty `TackleItemType` in canonical order, with items sorted alphabetically within each type.
4. **Single-tap selection:** Tapping a tile in the gallery picker selects that tackle item on **Log a Catch** (`add.tackle.selected`) and dismisses the gallery.
5. **Inline creation from gallery:** Tapping `+` in the gallery picker creates a new tackle item, selects it on **Log a Catch**, and dismisses the gallery.
6. **Search & type filter:** Searching or tapping a type chip in the gallery picker filters tiles accurately and shows a clear empty state when nothing matches.
7. **Offline & isolation parity:** Works completely offline, remains strictly scoped to `ownerID`, preserves free-text `lureText` and same-day catch defaults, and passes `make ci` cleanly.
