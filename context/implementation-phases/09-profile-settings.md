# Phase 09 — Profile and Settings

**Status:** Planned  
**Depends on:** Phase 08 complete
**Primary stories:** C4, E3, E6

## Goal

Give each angler a personal, private profile backed by the same local-first guarantees, then complete
the intentionally limited v1 settings surface.

## User-visible outcome

- You shows avatar, display name/username fallback, home water, angler-since, and derived Catch stats.
- Signature species and species breakdown derive from the local Catch collection.
- Edit Profile changes display name, home water, avatar, and angler-since.
- Profile edits and avatar changes work offline and synchronize later.
- Units clearly shows fixed `lb · in` behavior.
- Full-logbook export is disabled and labeled Coming Soon.
- Tackle Box remains reachable from Profile.
- Sign out safely handles pending local work and reveals no prior account data afterward.

## Backend slice

- Add `display_name`, `home_water`, `avatar_storage_path`, `angler_since`, and `updated_at` to profiles.
- Add sensible year validation without rejecting omitted values.
- Create a private avatar Storage path/policy and replacement cleanup behavior.
- Extend profile RLS for owner-only read/update.
- Prevent client changes to server-managed identity fields.

## iOS/local slice

- Extend the account-scoped local profile model, repository, outbox, and mappings.
- Build the unresolved Edit Profile design in the established design language before implementation.
- Reuse the proven single-photo file/upload lifecycle for avatar replacement/removal.
- Derive all profile stats locally using Phase 07 functions rather than a second implementation.
- Implement documented fallbacks for missing display name/avatar/home water/year.
- Apply the previously decided pending-data sign-out behavior.
- Show Notifications as disabled/Coming Soon; do not request permission or imply working behavior.
- If the release-scope gate requires account deletion or password reset UI, specify and implement it in
  this phase (or an explicitly scheduled auth follow-up) before Phase 11 hardening.

## Implementation sequence

1. Confirm Edit Profile design, username mutability, validation, avatar cleanup, and any required
   account deletion/password-reset behavior.
2. Apply and test profile/Storage migrations and policies.
3. Extend local profile persistence and synchronization.
4. Build Profile presentation and reused derived statistics.
5. Build Edit Profile and avatar lifecycle.
6. Complete limited settings and sign-out behavior.
7. Test offline edits, account switching, and fresh-device recovery.
8. Deploy and verify the slice through TestFlight.

## Verification

- RLS/Storage: profiles and avatars remain owner-private.
- Unit: name fallback, year validation, signature species/ties, breakdown ordering.
- Sync: offline profile edit/avatar replacement, retry, removal, and second-device recovery.
- Account isolation: sign out/in as another user without displaying prior cached profile or catches.
- UI: all optional fields empty, long names/home water, missing avatar, Dynamic Type.

## Acceptance gate

- C4/E6 behavior works offline and recovers on another device.
- Profile stats exactly match the same Catch derivations used elsewhere.
- Avatar replacement/removal leaves no unhandled orphan path.
- Settings do not imply working metric, notifications, or full export features.
- Sign out preserves data safety and account privacy under the agreed policy.

## Explicit non-goals

Public profiles; inter-user visibility; roles/admin UI; metric conversion; full-logbook export; working
notifications without a separately approved scope.

## Closeout record

- TestFlight build: _TBD_
- Profile/Storage migrations: _TBD_
- Automated checks: _TBD_
- Account-isolation evidence: _TBD_
