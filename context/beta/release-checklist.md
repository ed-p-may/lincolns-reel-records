# Release Checklist — `0.1.0 (5)`

Do not upload or invite external testers from a dirty worktree. Never paste passwords, service-role keys,
signing material, device identifiers, or tester addresses into logs or this repository.

## 1. Freeze and preflight

- [ ] Confirm scope is Phases 01–10 with no release-blocking open defects.
- [x] Confirm `MARKETING_VERSION = 0.1.0` and `CURRENT_PROJECT_VERSION = 5` in `project.yml`.
- [ ] Regenerate the project and run `make ci` from a clean checkout.
- [x] Confirm the privacy manifest is in the built app root.
- [ ] Generate and inspect the archive privacy report.
- [ ] Confirm the public privacy-policy URL, feedback contact, beta description, and What to Test copy.
- [x] Scan tracked files and the built/archive bundle for privileged keys, private keys, dev endpoints,
  personal test data, and verbose sensitive logs.

## 2. Hosted beta migration

- [x] Verify the CLI/dashboard target is project ref `ptoqkqisgyzypfpjvmvx`; stop if it differs.
- [x] Capture the hosted migration ledger and a pre-change backup/recovery point.
- [x] Stop if hosted Phase 01 is recorded as `20260719191234` while Git records
  `20260719184719_create_phase_01_schema`. Schema-diff the hosted baseline against the Git migration,
  document equivalence/differences, and use a reviewed Supabase ledger-reconciliation procedure before
  any push. Never guess that the differently timestamped migrations are equivalent.
- [x] Review the local migration list in timestamp order; deploy migrations 02–10 once.
- [x] Deploy the authenticated `delete-account` Edge Function with its server-only environment.
- [x] Compare the hosted ledger to Git; run two-user table and Storage isolation probes.
- [x] Test password reset with a receivable beta account; do not use the non-receivable `.test` reviewer
  address for mail delivery evidence.
- [x] Exercise account deletion only with a disposable beta account; confirm Auth, rows, and objects are gone.

Rollback rule: additive schema changes stay in place unless a reviewed forward-fix migration says
otherwise. If isolation, deletion, or data integrity fails, stop testing, remove the build from tester
availability, preserve evidence/backup, and ship no ad hoc destructive SQL.

## 3. Signed release candidate

- [x] In Xcode, verify the Apple account/team, automatic signing, bundle ID, and Beta archive config.
- [x] Archive the shared `LincolnReelRecords` scheme normally; do not disable signing for this gate.
- [ ] Inspect validation/privacy reports and resolve every error before upload.
- [ ] Upload `0.1.0 (5)` to App Store Connect; record processing and compliance results.
- [ ] Add it to `Reel Records Internal` only; install over the tested build 4 and repeat a clean install if
  recovery changes affect account state.
- [ ] Complete every physical/hosted acceptance row before external submission.

## 4. External beta

- [ ] Put the reviewer credentials only in App Store Connect Test Information and verify them immediately.
- [ ] Use the private `Reel Records Friends & Family` email-only group; keep public link disabled.
- [ ] Submit the accepted internal RC for external review with `tester-script.md` What to Test notes.
- [ ] After approval, add the build to the existing group and verify the named testers receive access.
- [ ] Monitor TestFlight feedback and triage release blockers without expanding v1 scope.

Stop-testing response: remove the affected build from group availability, notify invited testers through
the configured feedback/contact route, preserve pending local data, document the incident, and issue a
new incremented build after the fix passes this checklist.
