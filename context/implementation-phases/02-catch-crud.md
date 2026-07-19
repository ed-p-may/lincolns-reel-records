# Phase 02 — Core Catch CRUD

**Status:** Complete
**Depends on:** Phase 01 complete  
**Primary stories:** A1, A3, A6, E2, E5

## Goal

Turn the tracer Catch into a useful text-and-measurement log entry that can be created, edited, and
deleted offline without weakening synchronization or data recovery.

## User-visible outcome

- Add Catch supports species, caught date/time, weight, length, named location, free-text lure,
  rod/reel, notes, and Released/Kept.
- Only species and caught date/time are required.
- Catch Detail exposes Edit and Delete.
- Edits appear immediately and synchronize later.
- Delete requires confirmation and disappears locally immediately while propagating to other devices.
- Numeric fields accept decimals and display imperial units consistently.

## Backend slice

- Add nullable Catch columns: `weight`, `length`, `location`, `lure_text`, `rod_reel`, and `notes`.
- Add `released` with the agreed Released default.
- Add constraints only where they prevent invalid data without blocking legitimate partial catches.
- Finalize durable remote deletion/tombstone behavior and retention.
- Finalize update conflict detection for offline edits; do not silently overwrite an unobserved remote edit.
- Extend owner-only RLS and API integration fixtures across create/update/delete.

## iOS/local slice

- Extend the SwiftData model and transport DTO mapping through a tested local migration.
- Add domain parsing/formatting for decimal pounds and inches; do not store formatted strings.
- Expand Add Catch without building fields owned by later phases.
- Use the same form in edit mode with a draft that commits atomically on Save.
- Add confirmed local-first deletion and queued remote deletion.
- Surface failed sync without blocking further local edits.
- Define safe sign-out behavior when pending edits/deletions exist.

## Implementation sequence

1. Record conflict, deletion retention, and unsynced-sign-out decisions.
2. Migrate and test the remote and local schemas.
3. Extend repository create/update/delete operations and sync mappings.
4. Add measurement and text fields to the form.
5. Add minimal Catch Detail entry points for Edit/Delete.
6. Test concurrent/pending operations, relaunch, and second-device propagation.
7. Deploy and verify the slice through TestFlight.

## Verification

- Unit: decimal parsing, one-decimal weight display, optional fields, Released default.
- Migration: existing Phase 01 catches remain readable and editable.
- Repository: repeated pushes are idempotent; failed edits/deletes remain retryable.
- Conflict: the selected policy is exercised with divergent edits from two clients.
- Device: create/edit/delete offline across relaunch, then reconnect and recover on another device.

## Acceptance gate

- A useful scalar catch can be created in under one minute.
- Every included field survives offline relaunch, synchronization, and fresh-device recovery.
- Edit and delete behave correctly from Catch Detail.
- Deletion is observable on another device and does not resurrect after sync.
- Phase 01's tracer regression remains green.

## Explicit non-goals

Photos; coordinates/map; weather/water conditions; structured TackleItem selection; bookmarks; rich
logbook search/filter/sort; final Catch Detail composition.

## Closeout record

- TestFlight build: no Phase 02 upload; signed build `0.1.0 (3)` remains the hosted Phase 01 build.
  Hosted migration, signed TestFlight, and physical-device acceptance are consolidated in Phase 11
  under the development-loop policy in `../implementation-plan.md`.
- Migrations: `20260719220500_phase_02_catch_crud.sql`; local Supabase reset applied the Phase 01 and
  Phase 02 migrations from zero, then 23 pgTAP checks passed (9 Phase 01 + 14 Phase 02).
- Automated checks: 19 Swift unit/integration tests cover scalar values, normalization, validation,
  on-disk relaunch, create/update/delete sync, idempotency, optional-field clearing, divergent edits,
  explicit keep-mine retry, tombstones, owner scoping, and pending-data sign-out. The iPhone 17 Pro
  Simulator UI test creates a measured Kept Catch, verifies Detail values, edits species, confirms
  deletion, and returns to the empty Log.
- Manual acceptance evidence: iPhone 17 Pro Simulator on iOS 26.5 streamed successfully into the
  in-app browser; the empty Log and full Add Catch form rendered correctly at device size. A disk-backed
  SwiftData test reopened a synced Catch, an offline edit, and an offline tombstone across separate
  containers. Final hosted second-device recovery and physical airplane-mode acceptance remain Phase 11
  gates and were not claimed here.
