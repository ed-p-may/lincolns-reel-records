# Phase 08 — Tackle Box

**Status:** Complete
**Depends on:** Phase 07 complete  
**Primary stories:** A4 (gear subset), A7, F1, F2, F3, E5

## Goal

Deliver a private, offline-capable tackle catalog and connect it to Catch logging without removing the
free-text one-off path.

## User-visible outcome

- The You/Profile shell and Add Catch can open the pushed Tackle Box screen.
- Users can add/edit an item with name, type, size, color, brand, and optional photo.
- Catalog search and type chips filter the local collection.
- Archive hides an item from normal catalog/pickers without breaking historical catches.
- Add/Edit Catch can choose an active item, add one inline, clear it, or use `lureText` instead.
- Catch cards/detail show the linked item and can open its Tackle Box entry.

## Backend slice

- Create `tackle_items` with the complete PRD fields, client UUID, owner, audit/sync fields, archived
  state, and one private Storage path.
- Add nullable `tackle_item_id` to Catch with ownership-safe referential behavior.
- Define what happens if an invalid cross-owner ID is submitted; reject it at the database boundary.
- Add owner-only RLS and private Storage policies.
- Keep F4 per-item catch count deferred post-v1 unless it is explicitly reprioritized; never store it.

## iOS/local slice

- Add local TackleItem persistence, repository, outbox operations, photo-file lifecycle, and migrations.
- Implement typed item categories matching the fixed PRD list.
- Reuse proven Catch-photo pipeline concepts without forcing a child table for the single item photo.
- Build catalog, search/filter, add/edit sheet, archive behavior, and empty states from the mockup.
- Build selected-item and horizontal-picker states within the Catch draft.
- Extend Log search so B2 matches both linked TackleItem name and `lureText`.
- Preserve archived/deleted historical references and present unavailable items honestly.
- Ensure an inline-created item is locally committed before the Catch references it.

## Implementation sequence

1. Resolve linked-item archive/delete semantics; keep F4 catch counts out of scope unless reprioritized.
2. Apply and test schema, ownership constraints, RLS, and Storage policies.
3. Implement local models/repository/sync and migration tests.
4. Build catalog and Add/Edit/Archive flows.
5. Integrate the picker and inline creation into Add/Edit Catch.
6. Add linked-item rendering and navigation from Catch Detail.
7. Test offline multi-operation ordering and second-device recovery.
8. Deploy and verify the slice through TestFlight.

## Verification

- RLS: no cross-user catalog or photo access; no Catch can link to another owner's item.
- Sync: create item then Catch offline; edit/archive item; retry partial item-photo failure.
- UI: empty catalog, search/type combination, inline add, archived historical reference, and Log search
  across linked item names plus `lureText`.
- Migration: all existing `lureText` catches remain unchanged and editable.
- Device: full TackleItem CRUD and Catch selection work in airplane mode.

## Acceptance gate

- F1–F3 and A7 pass end to end without weakening the free-text fallback.
- Item and Catch operation ordering cannot create a broken remote reference.
- Archived items disappear from new-pick flows and remain visible in history.
- Item photos synchronize privately and recover on another device.
- Tackle Box remains a pushed screen, not a sixth tab.

## Explicit non-goals

Shared tackle catalogs; inventory/quantities; purchase links; F4 per-item catch counts/productivity
analytics; multiple photos per TackleItem.

## Closeout record

- TestFlight build: no Phase 08 build; signed build `0.1.0 (3)` remains the latest hosted beta.
  Hosted deployment, signed release, and final physical-device acceptance are consolidated in Phase 11.
- Schema/Storage migrations: `20260720010000_phase_08_tackle_box.sql` adds the owner-scoped catalog,
  ownership-safe Catch reference, and private `tackle-photos` bucket/policies. It passes locally; hosted
  application and isolation probes are deferred to Phase 11.
- Automated checks: `make ci` passes SwiftFormat and strict SwiftLint, 67 Swift unit tests, 11
  Simulator UI tests, and 78 local pgTAP database/RLS assertions.
- Offline linked-record evidence: deterministic tests cover item-before-Catch ordering, overlapping
  requests, in-flight edits, create-conflict recovery, binary/metadata/cleanup retries, second-device
  item-photo recovery, archive history, and free-text fallback. Simulator flows cover catalog
  search/type filters, inline creation, linked-name Log search, archive/restore, and archived Catch
  detail. Physical airplane-mode/reconnect, camera/library permissions, hosted recovery, and orphan
  audit remain consolidated in Phase 11.
