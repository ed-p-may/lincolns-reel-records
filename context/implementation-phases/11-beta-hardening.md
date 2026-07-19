# Phase 11 — Beta Hardening and Broader TestFlight Release

**Status:** Planned  
**Depends on:** Phases 01–07 plus every P1 phase selected at the release-scope gate  
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
- verify a fresh physical install recovers every hosted Catch and photo with stable order/hero choice,
  then audit the private bucket for orphan objects after replacement, photo removal, and Catch deletion;
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

- Release candidate/TestFlight build: _TBD_
- External tester group: `Reel Records Friends & Family` was created early during Phase 01. Build
  `0.1.0 (3)` is in TestFlight App Review, and Lincoln Fisher has been added by email; the tester has no
  build until Apple approves it. Exact tester addresses remain authoritative in App Store Connect.
- Acceptance matrix: _TBD_
- Security/privacy evidence: _TBD_
- Known limitations: _TBD_
- Beta start date and owner: _TBD_
