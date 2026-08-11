# Release Checklist — `0.1.0 (6)`

Do not upload or invite external testers from a dirty worktree. Never paste passwords, service-role keys,
signing material, device identifiers, or tester addresses into logs or this repository.

## 1. Freeze and preflight

- [x] Confirm scope is the merged Issue #1 photo gallery, Issue #2 same-day defaults, and Issue #3 photo
  metadata defaults on top of the verified build-5 baseline.
- [x] Confirm `MARKETING_VERSION = 0.1.0` and `CURRENT_PROJECT_VERSION = 6` in `project.yml`.
- [x] Regenerate the project and run `make ci` against the exact build-6 release-prep tree.
- [x] Confirm the privacy manifest is in the built app root.
- [ ] Generate and inspect the archive privacy report.
- [x] Confirm the feedback contact, beta description, reviewer sign-in information, and updated What to
  Test copy in App Store Connect.
- [ ] Add and verify the public privacy-policy URL in App Store Connect.
- [x] Scan tracked files and the built/archive bundle for privileged keys, private keys, dev endpoints,
  personal test data, and verbose sensitive logs.

## 2. Hosted beta migration

- [x] Confirm no Supabase migration, Function, client configuration, or privacy-manifest change exists
  between the uploaded build-5 baseline and build 6.
- [x] No hosted migration or Function deployment is required for this update.
- [x] Before device testing, verify App Store Connect build status and hosted project health without
  mutating beta data.

Rollback rule: additive schema changes stay in place unless a reviewed forward-fix migration says
otherwise. If isolation, deletion, or data integrity fails, stop testing, remove the build from tester
availability, preserve evidence/backup, and ship no ad hoc destructive SQL.

## 3. Signed release candidate

- [x] Verify the archive's Apple team, signing, bundle ID, and Beta configuration.
- [x] Archive the shared `LincolnReelRecords` scheme normally; do not disable signing for this gate.
- [x] Validate the signed archive and inspect its embedded privacy manifests before upload.
- [x] Upload `0.1.0 (6)` to App Store Connect; processing completed with no compliance error.
- [x] Add it to `Reel Records Internal`.
- [ ] Install build 6 over build 5 and smoke-test existing data plus Issues #1–3.
- [ ] Complete the build-6 physical/hosted acceptance rows before external submission.

## 4. External beta

- [ ] Put the reviewer credentials only in App Store Connect Test Information and verify them immediately.
- [x] Use the private `Reel Records Friends & Family` email-only group; keep public link disabled.
- [ ] Submit the accepted internal RC for external review with `tester-script.md` What to Test notes.
- [ ] After approval, add the build to the existing group and verify the named testers receive access.
- [ ] Monitor TestFlight feedback and triage release blockers without expanding v1 scope.

Stop-testing response: remove the affected build from group availability, notify invited testers through
the configured feedback/contact route, preserve pending local data, document the incident, and issue a
new incremented build after the fix passes this checklist.

## Build-6 release evidence — 2026-08-10

- App commit: `4819a10` (`Prepare TestFlight build 6 (#7)`); archive version `0.1.0 (6)`.
- `make ci`: 0 formatting/lint violations across 85 Swift files, 96 unit tests, 19 UI tests, and 99
  pgTAP assertions across 8 database files.
- Signed archive validated and uploaded successfully. App Store Connect processed build 6 as
  `Ready to Submit`; it is assigned only to `Reel Records Internal` pending the physical-device gate.
- Archive inspection confirmed bundle ID `com.bldgtyp.LincolnsReelRecords`, Team ID `JPJ3AJ5U8A`,
  minimum iOS 18, no non-exempt encryption, embedded privacy manifest, and no privileged-key or
  development-endpoint scan hits.
- Hosted Supabase project `ptoqkqisgyzypfpjvmvx` reported `ACTIVE_HEALTHY`; all eight migrations and
  the authenticated `delete-account` Function remain present. No hosted mutation was performed.
- App Store Connect Test Information is populated except for the public privacy-policy URL. External
  group assignment and submission remain intentionally held until the install/smoke gate passes.
