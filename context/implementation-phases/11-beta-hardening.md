# Phase 11 — Beta Hardening and Broader TestFlight Release

**Status:** Verification — hosted baseline and primary physical gates pass; final RC/release gates remain
**Depends on:** Phases 01–10
**Primary stories:** Cross-cutting validation of all v1 stories

## Goal

Turn the internally proven vertical slices into a coherent, supportable external beta for the invited
friends-and-family group without adding new product scope.

## Release outcome

- A clean install, upgrade, offline session, account switch, and second-device restore are dependable.
- Sync failures are diagnosable and recoverable without losing user-authored data.
- Permissions and privacy behavior accurately describe photos, camera, and location use.
- Accessibility and performance are acceptable across supported devices and iOS 18+.
- External TestFlight metadata, review information, tester group, and feedback process are ready.
- Invited testers receive a bounded test script and known-limitations note.

## Hardening scope

### Data and synchronization

- Exercise multi-device edit/delete/photo conflicts and verify the documented resolution behavior.
- Test interrupted uploads, token expiry, long offline intervals, duplicate delivery, clock/time-zone
  changes, schema upgrades, and low-storage conditions.
- Verify no sign-out/account-switch path loses pending data or exposes another account's cache.
- Add an in-app/manual diagnostic surface only if testers cannot otherwise identify failed sync work.
- Validate backup/recovery from the hosted beta project and rehearse a migration rollback/recovery path.

### Security and privacy

- Re-run cross-user database and Storage policy tests for every table/bucket.
- Confirm no privileged key, development endpoint, personal test data, or verbose sensitive logging is
  present in the archive.
- Complete privacy manifests/disclosures and permission-purpose strings.
- Verify the previously approved account/data deletion and password-reset paths; if either is required
  but absent, return the work to its owning pre-hardening phase rather than adding scope here.
- Review the implications of storing minors' photos and precise locations; keep all data private by default.

### Product quality

- Run every P0/P1 acceptance criterion included in v1 against a clean beta account.
- Complete VoiceOver, Dynamic Type, contrast, Reduce Motion, keyboard, and touch-target review.
- Test supported device sizes and iOS versions, including the iOS 18 deployment floor.
- Profile launch, Log scrolling, image memory, Map behavior, and sync energy/network use.
- Remove dead placeholders that imply unavailable functionality; retain explicitly approved Coming Soon rows.

### Distribution and operations

- Finalize app icon, launch presentation, beta description, feedback email, and What to Test notes.
- Produce a short tester script covering signup, offline Catch, photos, map, sync, and feedback capture.
- Establish build numbering, migration ownership, issue triage, and a repeatable TestFlight upload checklist.
- First validate the release candidate internally, then submit/add it to the email-invite-only external group.
- Record known limitations and a rollback/stop-testing response.

### Consolidated hosted and physical-device gate

Phases 02–10 may close from local migrations, deterministic repository/sync tests, and Simulator
evidence during the phone-free implementation loop. Before this phase closes:

- apply every deferred Phase 02–10 migration to the hosted beta project, including private Storage
  buckets/policies, then rerun cross-user RLS and object-isolation probes against hosted services;
- produce one normally signed release-candidate TestFlight build containing the final included schema
  and exercise upgrade from `0.1.0 (3)` as well as a clean install;
- on physical iPhone hardware, exercise camera capture, full- and limited-library access, permission
  denial/recovery, airplane-mode photo save and relaunch, reconnect/upload, and a low-storage failure;
- on physical iPhone hardware, exercise explicit foreground GPS capture outdoors, all location
  permission states and Settings recovery, accuracy/timeout behavior, manual correction after denial,
  airplane-mode coordinate save/relaunch, and reconnect synchronization;
- on physical iPhone hardware, exercise a live Open-Meteo suggestion from GPS/time, provider
  timeout/error handling, manual condition entry and clearing in airplane mode, reconnect without
  overwriting manual edits, and exact hosted recovery of all four values plus the expected weather icon;
- on physical iPhone hardware, verify Dashboard totals, calendar-derived week/year values, rankings,
  recent catches, and favorite spots from the offline local cache across airplane mode, relaunch,
  time-zone/date-boundary changes, reconnect, and hosted fresh-install recovery;
- on physical iPhone hardware, exercise Tackle Box add/edit/archive/restore, optional camera and
  library photos, inline item creation followed immediately by Catch save, free-text fallback, linked
  Log search, and archived Catch history in airplane mode; then reconnect and verify item-before-Catch
  ordering plus fresh-install recovery of item metadata/photos without cross-account or orphan objects;
- deploy the Phase 09 profile migration and authenticated `delete-account` Edge Function, configure and
  verify the password-reset email/deep-link route, then probe profile/avatar isolation plus complete
  account deletion across Auth, all three private Storage buckets, and account-local cached data;
- on physical iPhone hardware, exercise Profile edits and avatar choose/camera/remove in airplane mode,
  relaunch with pending work, reconnect/conflict retry, account switching, and fresh-install recovery of
  display name, home water, angler-since, avatar, and Catch-derived statistics;
- deploy the Phase 10 bookmark migration, verify offline save/unsave plus hosted second-device recovery,
  and on physical iPhone hardware send/save representative complete and sparse catch images through
  Messages, Mail, and Save Image (or equivalent available destinations), including cancellation,
  temporary-file cleanup, long text, multiple photos, and image-memory behavior;
- verify a fresh physical install recovers every hosted Catch and photo with stable order/hero choice,
  including exact coordinate pairs and map focus, then audit the private bucket for orphan objects after
  replacement, photo removal, and Catch deletion;
- repeat the physical offline/reconnect and fresh-device recovery gates for the final included feature
  set rather than treating earlier Simulator or in-memory recovery evidence as hosted acceptance.

## Implementation sequence

1. Freeze feature scope and assemble the acceptance/known-risk matrix.
2. Run automated suites plus security/configuration checks from a clean environment.
3. Execute destructive, offline, multi-device, upgrade, and recovery scenarios.
4. Complete accessibility, privacy, performance, and supported-device passes.
5. Fix only release-blocking defects; route enhancements to post-v1 planning.
6. Produce release/tester documentation and an internal release candidate.
7. Pass internal acceptance, submit for external TestFlight review, and invite the named group by email.
8. Monitor the first beta cohort and record issues without silently expanding scope.

## Acceptance gate

- All included v1 acceptance criteria have traceable pass/fail evidence.
- No known path can silently discard a locally committed Catch or photo, or a TackleItem/profile edit
  when those P1 features are included.
- RLS and Storage isolation pass for two users across all entities.
- Clean install, supported upgrade, offline use, and second-device restore pass on real hardware.
- External TestFlight build is approved/available to the email-invite-only tester group.
- Known limitations, feedback route, and operational owner are documented.

## Explicit non-goals

New features; public App Store release; public TestFlight link; social functionality; metric units;
notifications; full-logbook export; first-class Spots; post-v1 analytics.

## Closeout record

- Phone-free checkpoint: privacy manifest and disclosures inventoried; Beta bundle/version/purpose
  strings and privileged-secret scan pass; iPhone 17e and iPhone 17 Pro Max Simulator coverage passes;
  Dashboard, Log, and Profile pass the automated XCUI accessibility audit after large-text, contrast,
  decorative-label, and touch-target fixes; icon/launch resources and placeholders are audited. Final
  `make ci` passes with 0 formatting/lint violations across 75 Swift files, 82 unit tests, 15 UI tests,
  and 99 pgTAP assertions across 8 database files.
- Hosted beta on 2026-07-20: reconciled the Phase 01 migration-ledger timestamp only after schema
  equivalence was proved; captured a permission-restricted logical backup; applied all eight Git
  migrations; deployed the authenticated `delete-account` Function; and passed two-user table, private
  Storage, deletion, and orphan-object probes. The production Auth allowlist now contains
  `lincolnsreelrecords://reset-password`.
- Physical iPhone on iOS 18.6: build `0.1.0 (4)` upgraded over TestFlight build `0.1.0 (3)` without data
  loss and passed camera/GPS/live-weather, denial/recovery, offline photo/Catch/Tackle/Profile/bookmark
  reconnect, account-switch/deletion, clean-install hosted restore, Save Image, and share-cancellation
  checks. Low-storage, time-zone boundary, full manual accessibility, performance/energy, and every
  requested share destination still need evidence.
- Release candidate/TestFlight build: password-reset request, PKCE callback, and new-password UI were
  added after the build-4 device pass, so `project.yml` now reserves `0.1.0 (5)`. Build 5 archived with
  valid development signing on 2026-07-20; its bundle contains the app and dependency privacy manifests,
  the expected password-recovery URL scheme, and no privileged-key scan hits. It installed over build 4
  on the physical iPhone, and Ed confirmed the real recovery email/deep link/new-password flow succeeds.
  Existing Catches, Profile, and Tackle Box data remained intact after the build-5 upgrade and password
  reset. Xcode validation passed; the generated archive privacy report matched the six-category privacy
  inventory with no tracking; App Store Connect processed the upload; and Ed installed the Apple-hosted
  internal TestFlight build 5 and confirmed Home, Log/photos, Profile, Tackle Box, and Map data remained
  intact.
- Build-5 automated gate: `make ci` passes with 0 formatting/lint violations across 75 Swift files,
  85 unit tests, 16 UI tests, and 99 pgTAP assertions across all 8 local migrations.
- External tester group: `Reel Records Friends & Family` was created early during Phase 01 and contains
  Lincoln Fisher by email. Superseded build `0.1.0 (3)` was removed from review and detached from the
  external group. Verified build `0.1.0 (5)` is assigned to the internal and external groups and is
  `Waiting for Review` as live-verified in App Store Connect on 2026-07-20. The external tester has no
  build until Apple approves it. Exact tester addresses remain authoritative in App Store Connect.
- Acceptance matrix: [`../beta/acceptance-matrix.md`](../beta/acceptance-matrix.md)
- Security/privacy evidence: [`../beta/privacy-inventory.md`](../beta/privacy-inventory.md)
- Known limitations: [`../beta/known-limitations.md`](../beta/known-limitations.md)
- Beta start date and owner: _TBD_
