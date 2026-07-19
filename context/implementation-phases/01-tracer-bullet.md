# Phase 01 — Tracer Bullet

**Status:** Complete
**Depends on:** Pre-scaffold confirmation gate in `../implementation-plan.md`  
**Primary stories:** A1, B1, E1, E2, E5

## Goal

Prove the complete delivery path with the smallest real feature: an invited user installs the app,
authenticates, saves a catch containing species and caught date/time while offline, sees it immediately,
and later synchronizes and recovers it from Supabase.

This phase validates architecture and deployment. It is not a disposable prototype.

## User-visible outcome

- Welcome, signup, and login reach a minimal authenticated app shell.
- The Log shows locally stored catches or a deliberate empty state.
- Add Catch captures only species and caught date/time.
- Saving succeeds without a network and returns to the Log with the catch at the top.
- A small, non-blocking state distinguishes pending, failed, and synchronized records.
- Sign out prevents the previous account's rows from appearing to the next account.

## Backend slice

- Establish version-controlled Supabase migrations and environment configuration.
- Create the minimum `profiles` table needed by signup: `id`, `username`, `created_at`.
- Create the minimum `catches` table: client UUID, `owner_id`, `species`, `caught_at`, audit timestamps,
  and only the remote change fields required for creation/pull. Deletion/tombstones begin in Phase 02.
- Enable RLS and least-privilege authenticated grants for both tables.
- Ensure inserts cannot assign a different owner and all reads/updates/deletes are owner-scoped.
- Add an automated two-user RLS test.
- Configure and verify the chosen signup/email-confirmation behavior.

## iOS/local slice

- Scaffold the SwiftUI app at minimum iOS 18 with unit and UI-test targets.
- Configure Debug and TestFlight beta environments without embedding privileged credentials.
- Add only the design tokens, fonts, buttons, inputs, and empty-state styling this path needs.
- Establish the auth/session service and authenticated/unauthenticated root state.
- Establish the root dependency graph, tab/navigation shell, and Add Catch presentation route.
- Add the minimal SwiftData Catch model and account-scoping behavior.
- Add a Catch repository whose create/list interface is local-first.
- Add the initial outbox/sync coordinator: enqueue local creation, retry, pull, and merge.
- Preserve an authenticated user's cached Log through offline relaunch.

## Implementation sequence

1. Confirm the pre-scaffold decisions—including minimum unsynced sign-out behavior—and record
   consequential choices in `decisions.md`.
2. Create the Xcode/App Store Connect/Supabase project identities and environment contract.
3. Apply and test the minimal backend schema and RLS.
4. Build the app shell and auth boundary.
5. Build local Catch creation and Log rendering with no remote dependency.
6. Add push/pull synchronization and visible failure/retry behavior.
7. Add automated tests, then exercise airplane-mode and relaunch behavior on a real phone.
8. Archive, upload, install through internal TestFlight, and repeat the acceptance script.

## Verification

- Unit: required species, default caught time, sort by `caught_at`, sync-state transitions.
- Repository: local save succeeds with an unavailable remote; retries are idempotent by UUID.
- Integration: signup/login/session restoration and two-user RLS isolation.
- UI: authenticated empty state → Add Catch → saved row.
- Device: airplane-mode save, force-quit/relaunch, reconnect, successful upload.
- Recovery: a fresh install or second device downloads the same catch after login.

## Acceptance gate

- An internal TestFlight build is installed on the named test phone.
- The offline-save/relaunch/reconnect path passes on the named TestFlight device.
- Fresh-install or second-device hosted recovery passes on a normally signed device or Simulator.
- A second user cannot read or mutate the first user's profile or catch.
- No network, auth-refresh, or sync error can discard a locally committed catch.
- The tested build number and verification evidence are recorded in this file before completion.

## Explicit non-goals

Weight/length; edit/delete; photos; GPS/map; conditions; search/filter/sort controls; dashboard; Tackle
Box; profile editing; production-ready generalized conflict resolution; visual completion of all five tabs.

## Closeout record

- TestFlight build: `0.1.0 (3)` is signed and uploaded. It is available to the internal group
  `Reel Records Internal`; `ed.p.may@gmail.com` installed the beta on the named test phone. The external
  group `Reel Records Friends & Family` contains Lincoln Fisher; build `3` is awaiting TestFlight App
  Review, so the external tester currently shows `No Builds Available`. Exact operational identifiers
  and account roles are recorded in `../environments-and-accounts.md`.
- Test phone / iOS: iPhone 16 Pro / iOS 18.6
- Supabase migration: `supabase/migrations/20260719184719_create_phase_01_schema.sql`; hosted migration
  ledger version `20260719191234` (`create_phase_01_schema`) on project `ptoqkqisgyzypfpjvmvx`.
  Hosted email confirmation is disabled; Security Advisor reports no findings.
- Automated checks: 9 unit tests and 1 UI test pass; 9 local pgTAP RLS assertions pass; equivalent hosted
  transactional two-user RLS assertions pass. `swiftformat --lint` and `swiftlint --strict` pass.
- Manual acceptance evidence:
  - Normally signed iPhone 17 Pro Simulator / iOS 26.5: real hosted signup entered the app immediately;
    local Catch creation rendered before network completion; retry uploaded it and displayed `Synced`.
  - Force-quit/relaunch restored the authenticated session and Catch. Removing and reinstalling the app
    erased SwiftData, then the retained session downloaded the Catch from Supabase.
  - Sign-out returned to Welcome. The temporary hosted test user was deleted afterward; cascades left
    `auth.users`, `public.profiles`, and `public.catches` at zero rows.
  - A clean install with no session now opens Welcome without an `Auth session missing` alert.
  - Physical TestFlight build `2`: `ed.p.may@gmail.com` remained signed in in airplane mode, saved a
    Northern Pike Catch locally, force-quit/relaunched, and saw both that pending Catch and the earlier
    synchronized Largemouth Bass. The app remained responsive, but automatic synchronization kept the
    upper-right activity indicator spinning while offline.
  - Physical TestFlight build `3`: the installed build was confirmed on the same iPhone 16 Pro. After
    reconnecting, Northern Pike uploaded exactly once; the Log contained exactly Northern Pike and
    Largemouth Bass and both displayed `Synced`.
  - With the phone connected over USB, Airplane Mode was enabled and Wi-Fi was disabled, the TestFlight app
    was force-quit and relaunched, and an Xcode wired screenshot confirmed that both cached Catches
    rendered while offline. The toolbar showed the explicit retry control rather than the continuous
    activity indicator from build `2`.
  - Fresh-install hosted recovery had already passed on the signed Simulator path above. The two-Catch
    physical uninstall was not repeated after this regression check; [Phase 11](11-beta-hardening.md)
    retains clean-install and second-device restore across the final included schema as a release gate.
