# Photo Gallery

**Source:** [GitHub Issue #1](https://github.com/ed-p-may/lincolns-reel-records/issues/1)
**Status:** Complete
**Owner:** Reel Records iOS app

## Goal

Make catch photos independently browsable and let an angler inspect any photo without the Catch Detail
layout competing for screen space.

## User-visible contract

- The Log exposes a dedicated **Photos** destination without adding a sixth bottom tab.
- Photos from every visible catch appear in a dense, square, three-column grid ordered newest catch
  first and in each catch's saved photo order.
- A catch with multiple photos contributes every photo, not only its hero.
- Tapping a grid tile opens a dark full-screen, swipeable viewer at that photo.
- Tapping any photo in Catch Detail opens the same viewer at that photo.
- The viewer identifies the catch, date, and current position, and has an explicit close control.
- The grid has intentional empty and load-error states.

## Data and privacy contract

- Read only the signed-in owner's locally visible `CatchItem` and non-deleted `CatchPhotoItem` records.
- Continue using `SwiftDataCatchRepository` and `SwiftDataCatchPhotoRepository`; do not add schema,
  remote calls, public URLs, or a parallel cache.
- Use the existing downsampled local-image pipeline for grid thumbnails and viewer images.

## Acceptance criteria

1. The populated UI-test fixture shows both ordered photos in the Photos grid.
2. A grid tile opens the full-screen viewer at the selected photo; paging and dismissal remain usable.
3. A Catch Detail hero photo opens the same viewer and preserves that catch's full photo order.
4. The feature works from local data while offline and does not change photo sync or editing behavior.
5. Existing Log discovery, Catch Detail carousel, editing, sharing, and deletion tests remain green.

## Non-goals

- Photo editing, deletion, selection, search, albums, dates-as-sections, or sharing from the grid.
- A new bottom tab, backend migration, Storage-policy change, or cross-user gallery.
- Pinch-to-zoom or a complete clone of Apple Photos.
