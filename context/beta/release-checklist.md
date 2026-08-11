# Release Checklist — `0.1.0 (6)`

Do not upload or invite external testers from a dirty worktree. Never paste passwords, service-role keys,
signing material, device identifiers, or tester addresses into logs or this repository.

## 1. Freeze and preflight

- [x] Confirm scope is the merged Issue #1 photo gallery, Issue #2 same-day defaults, and Issue #3 photo
  metadata defaults on top of the verified build-5 baseline.
- [x] Confirm `MARKETING_VERSION = 0.1.0` and `CURRENT_PROJECT_VERSION = 6` in `project.yml`.
- [x] Regenerate the project and run `make ci` against the exact build-6 release-prep tree.
- [ ] Confirm the privacy manifest is in the built app root.
- [ ] Generate and inspect the archive privacy report.
- [ ] Confirm the public privacy-policy URL, feedback contact, beta description, and updated What to Test copy.
- [ ] Scan tracked files and the built/archive bundle for privileged keys, private keys, dev endpoints,
  personal test data, and verbose sensitive logs.

## 2. Hosted beta migration

- [x] Confirm no Supabase migration, Function, client configuration, or privacy-manifest change exists
  between the uploaded build-5 baseline and build 6.
- [x] No hosted migration or Function deployment is required for this update.
- [ ] Before device testing, verify App Store Connect build status and hosted project health without
  mutating beta data.

Rollback rule: additive schema changes stay in place unless a reviewed forward-fix migration says
otherwise. If isolation, deletion, or data integrity fails, stop testing, remove the build from tester
availability, preserve evidence/backup, and ship no ad hoc destructive SQL.

## 3. Signed release candidate

- [ ] In Xcode, verify the Apple account/team, automatic signing, bundle ID, and Beta archive config.
- [ ] Archive the shared `LincolnReelRecords` scheme normally; do not disable signing for this gate.
- [ ] Inspect validation/privacy reports and resolve every error before upload.
- [ ] Upload `0.1.0 (6)` to App Store Connect; record processing and compliance results.
- [ ] Add it to `Reel Records Internal`; install over build 5 and smoke-test existing data plus Issues #1–3.
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
