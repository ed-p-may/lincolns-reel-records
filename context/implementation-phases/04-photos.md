# Phase 04 — Catch Photos

**Status:** Complete
**Depends on:** Phase 03 complete  
**Primary stories:** A2, B1, B5, E2, E5

## Goal

Deliver durable, ordered, multi-photo catches whose images are useful immediately offline and safely
upload, download, reorder, and delete across devices.

## User-visible outcome

- Add/Edit Catch can acquire multiple photos from camera or library.
- Selected photos persist locally before the Catch is saved or synchronized.
- The first photo is the hero on Log cards and Catch Detail.
- Photos can be reordered and removed; a no-photo catch still looks intentional.
- Catch Detail presents an accessible carousel/gallery.
- Pending/failed uploads do not block saving the Catch and can retry later.

## Backend slice

- Create `catch_photos`: UUID, parent Catch, Storage path, position, created timestamp, and sync fields
  needed for reorder/deletion.
- Define uniqueness/order constraints that support deterministic reordering.
- Add parent-owner RLS for photo rows.
- Create a private catch-photo Storage bucket and owner-scoped object policies.
- Fix the path convention so ownership and cleanup are auditable.
- Define orphan cleanup after replacement, removal, or Catch deletion.

## iOS/local slice

- Add local CatchPhoto metadata and an account-scoped local file store.
- Normalize/compress images once with documented size/quality limits; preserve usable metadata only.
- Queue metadata and binary uploads separately so retry is idempotent.
- Download/cache missing remote photos without making the Log network-dependent.
- Keep drafts and committed photo files distinct so cancellation removes only draft-owned files.
- Handle photo permission states, limited-library access, camera absence, and storage failure.

## Implementation sequence

1. Record image limits, path convention, privacy/metadata, and cleanup decisions.
2. Apply and test table, RLS, bucket, and Storage policies.
3. Implement local file lifecycle and SwiftData migration.
4. Implement upload/download/reorder/delete sync operations.
5. Add picker/camera UI, thumbnails, reorder/removal, and hero rendering.
6. Add Catch Detail gallery and placeholder regression checks.
7. Run offline, relaunch, storage-failure, and second-device recovery tests.
8. Deploy and verify the slice through TestFlight.

## Verification

- RLS/Storage: a second account cannot list, download, overwrite, or delete another owner's photos.
- Lifecycle: cancel draft, save, edit/reorder, remove, delete parent Catch, and retry failed upload.
- Device: camera and library paths, limited permission, airplane-mode save, low-storage error handling.
- Recovery: correct order and hero image appear on a fresh install after synchronization.
- Performance: thumbnails avoid decoding full-resolution images in scrolling cards.

## Acceptance gate

- Zero, one, and multiple-photo catches work through create/edit/detail/delete.
- Offline-selected photos survive relaunch and upload after reconnect.
- Reordering is stable across a second device.
- Storage policies pass cross-user isolation tests.
- No orphan created by tested flows remains without an identified cleanup path.

## Explicit non-goals

AI identification; photo editing/filters; public URLs; social galleries; profile or TackleItem photos;
share-image composition.

## Closeout record

- TestFlight build: no Phase 04 upload; signed build `0.1.0 (3)` remains the hosted Phase 01 build.
  Hosted deployment and final physical-device acceptance are consolidated in Phase 11.
- Database/Storage migrations: `20260719233000_phase_04_catch_photos.sql` creates versioned photo
  metadata, deterministic ordering, parent-owner RLS, the private `catch-photos` bucket, canonical
  owner/Catch paths, JPEG/size limits, and owner-scoped object policies. It passes locally; applying
  and auditing it in the hosted beta project is a Phase 11 gate.
- Automated checks: `make ci` passes with strict formatting/lint, 31 Swift tests, 4 iPhone 17 Pro /
  iOS 26.5 Simulator UI tests, and 39 local pgTAP assertions after a clean local database reset.
- Manual photo lifecycle evidence: the seeded two-photo hero and intentional no-photo fallback were
  visually inspected in the iPhone 17 Pro / iOS 26.5 Simulator. Automated coverage exercises
  normalization/EXIF stripping, draft cancel, retry-safe commit, reorder/removal, failed upload,
  tombstone/binary cleanup, and fresh local-store recovery from an in-memory remote. Physical camera,
  limited-library permission, airplane/reconnect, low-storage, hosted recovery/order, and orphan
  Storage audit remain explicit Phase 11 gates.
