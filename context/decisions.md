# Reel Records — Decision Log (ADR-style)

Running record of consequential technical/product decisions. Add a dated entry when a decision is
made; keep the "Open" list current. Newest entries at the top.

## Open decisions

- None currently blocking implementation.

## Decisions made

## 2026-07-20 — Password-recovery callback and auth-state ordering
- **Context:** Supabase password recovery uses a PKCE verifier created when the reset email is requested,
  then returns through an app URL while cold-start session restoration may still be in flight. Treating
  those as unrelated tasks can let a stale restore overwrite the recovered session or duplicate a
  callback.
- **Decision:** Request recovery with the exact `lincolnsreelrecords://reset-password` redirect and
  handle that URL once at `RootView`. The auth service accepts only that scheme/host, suppresses duplicate
  callback delivery, and increments an auth revision before exchanging the PKCE code; any older startup
  restore must discard its result. Successful exchange authenticates the returned owner before presenting
  a non-dismissible new-password form. The production Supabase allowlist contains the same exact URL.
- **Consequences:** Recovery must be requested and completed in the same app installation so the PKCE
  verifier is available. Future auth callbacks must preserve the root-handling and stale-result invariant
  rather than adding navigation-local URL handlers.

## 2026-07-19 — Catch share-image and temporary-artifact contract
- **Context:** Phase 10 turns a private Catch into a deliberate image for the system share sheet. The
  layout, privacy boundary, output dimensions, primary-photo choice, and artifact lifetime were still
  open, and source images may contain private metadata or be large enough to affect interaction.
- **Decision:** Render a portrait 1080 × 1350 (4:5) JPEG in the established dark/green design language.
  Use the first ordered Catch photo, or a branded fish placeholder when no local photo exists. Include
  only Reel Records branding, species, optional weight and length, named spot, and caught date. Never
  include account identity, coordinates, notes, tackle, conditions, or source-photo metadata. Downsample
  the chosen photo through the shared 1,400 px cached decoder; keep SwiftUI `ImageRenderer` work on the
  main actor and move decode, JPEG encoding, stale-file pruning, and disk writes off-main.
- **Decision:** Share a generated file from `tmp/ReelRecords/Share`; remove it when the activity
  completes or is cancelled and prune any interrupted-session artifact older than 24 hours. Do not
  persist or upload share images.
- **Consequences:** Complete and sparse outputs are deterministic and fixture-testable, source EXIF is
  not inherited, and sharing creates no new backend/social surface. Phase 11 owns physical destination,
  image-memory, hosted bookmark recovery, and signed-build evidence.

## 2026-07-19 — Profile identity, offline sync, and account-management contract
- **Context:** Phase 09 adds editable app-owned profile data while Supabase Auth and the signup-created
  `profiles` row remain the identity boundary. The profile also owns a replaceable private avatar and
  the app currently supports account creation, which makes account deletion a release requirement.
- **Decision:**
  - `username`, email, profile UUID, and signup time are immutable in Edit Profile. The screen owns only
    optional display name, home water, avatar, and angler-since year; presentation falls back to
    `username`, a person placeholder, and omission of empty metadata.
  - Angler-since accepts an omitted value or a whole year from 1900 through the device's current
    calendar year. The database enforces 1900 through its own current year; the client performs the
    same validation before a local save.
  - The signup-created profile is cached account-locally in SwiftData and uses a single versioned
    outbox operation. Offline edits are authoritative local drafts; optimistic conflicts require an
    explicit keep-mine retry, matching Catch/Tackle behavior. Profile sync precedes derived UI reloads.
  - The avatar uses one canonical private Storage object at `owner-id/avatar-id.jpg`. Replacement
    uploads the new immutable path, updates profile metadata, then removes the obsolete object; retry
    state and local bytes survive interruption. Removal follows the same metadata-then-cleanup order.
  - Profile statistics remain pure derivations from the owner-scoped local Catch collection. The
    Profile screen reuses `DashboardDerivation` for total and personal best, and its shared normalized
    species ranking for signature species, distinct count, and breakdown ordering.
  - Sign-out remains blocked by any queued Catch, CatchPhoto, TackleItem, or Profile operation. All
    presentation and fetches stay owner-scoped, so another authenticated account never sees prior
    cached data.
  - Because the app creates accounts, Settings includes an in-app, explicit account-deletion flow.
    Deletion requires connectivity, removes private Storage objects and the Supabase Auth user through
    an authenticated server-owned Edge Function, then purges that owner's local rows/files and cached
    session. Password-reset link/deep-link handling was deferred to and implemented during the hosted
    auth hardening gate in Phase 11.
- **Consequences:** Username changes require a future identity migration. Phase 11 owns hosted deletion
  and reset-email completion evidence, signed-device confirmation, and fresh-device profile/avatar
  recovery; Phase 09 can fully verify the local/simulated contract and database policies without a
  physical phone.

## 2026-07-19 — Tackle Box history, ownership, and sync ordering contract
- **Context:** Phase 08 adds an offline-created object that a Catch can reference, plus one private
  photo. Archive/delete behavior and cross-object delivery order must be fixed before the schema and
  outboxes can be safe.
- **Decision:**
  - **Archive is the only user-facing retirement action in v1.** Archived items disappear from new
    Catch pickers and the normal catalog, remain available from an Archived catalog filter, and may be
    restored. Existing catches continue to resolve the item's name/type/photo. No destructive item
    deletion UI ships in Phase 08.
  - A remote tombstone is retained locally and stays resolvable for history, but is unavailable for a
    new selection. Editing a Catch that already references an archived/tombstoned item may preserve or
    clear/replace it; it never silently converts the reference to `lureText`.
  - `catches (tackle_item_id, owner_id)` has an ownership-safe composite foreign key to
    `tackle_items (id, owner_id)`. Cross-owner references are rejected at the database boundary and a
    referenced item cannot be hard-deleted. `lureText` remains independently optional and always
    editable; selecting an item does not erase it, so an intentional one-off description is preserved.
  - Tackle mutations synchronize before Catch mutations. A Catch referencing an item whose create is
    still queued or failed waits locally; after the item row is accepted, the Catch may sync. Inline add
    commits the TackleItem locally before assigning its UUID to the Catch draft.
  - A sync request arriving during an active pass is coalesced into a guaranteed follow-up pass. A
    remote TackleItem response replaces local values only when it still matches the mutation's local
    `updatedAt` snapshot; otherwise it advances the queued operation's base version and preserves the
    newer local values/photo stage for that follow-up pass.
  - Once create metadata exists remotely, any retained photo-cleanup operation becomes an update so a
    linked Catch is no longer blocked. Likewise, a create conflict against an existing remote UUID is
    confirmed and retried as a versioned update rather than looping on another insert.
  - The single item photo uses a canonical private Storage path
    `owner-id/item-id/photo-id.jpg`. Replacement uploads a new immutable path, switches row metadata,
    then removes obsolete objects; failures retain local bytes and retry state. Photo binaries are not
    child rows and catch-count/productivity remains derived and out of Phase 08.
- **Consequences:** Historical catches never lose their structured lure label because gear is retired;
  offline item-plus-Catch creation cannot violate the hosted foreign key; Phase 11 owns final hosted,
  physical airplane/reconnect, replacement-orphan, and fresh-device recovery evidence.

## 2026-07-19 — Dashboard derivation and calendar contract
- **Context:** Phase 07 must produce stable, honest summaries from the local Catch cache across missing
  measurements, spelling/case variants, ties, back-entered records, future dates, and time-zone changes.
- **Decision:**
  - Derive every dashboard value at render/load time from the account-scoped, non-deleted local Catch
    collection. Persist no summary rows or parallel statistics cache.
  - Use the device's current `Calendar` and time zone. "This week" and "this year" use `caughtAt`, not
    `createdAt`, and include dates from the containing calendar interval through `now`; a future-dated
    Catch remains visible in totals/recent/rankings but does not enter a period count until that time.
  - Normalize species and named spots by trimming and case-insensitive exact comparison. Rank modes by
    count, then most-recent `caughtAt`, then display label. Biggest/best ignores missing weights and
    uses recent/created/UUID order for equal values; a spot with no weights falls back to longest, and
    a completely unmeasured set displays an explicit unmeasured state rather than zero.
  - Recent catches use descending `caughtAt`, then `createdAt`, then UUID. Favorite spots use the same
    deterministic mode order; Map focus uses the most-recent coordinate-bearing Catch at that named
    spot, while a spot without coordinates still opens Map's honest no-pin state.
- **Consequences:** Fixture tests inject `now` and `Calendar`, including week/year boundaries and a
  second time zone. Dashboard recomputation remains a small pure pass over the beta-scale local set;
  the representative 1,000-Catch performance check remains in the focused suite.

## 2026-07-19 — Weather suggestion request, mapping, and draft precedence contract
- **Context:** Phase 06 must enrich an offline-first Catch draft without turning hourly model data,
  network latency, or a late response into authoritative user data. Open-Meteo exposes hourly
  `temperature_2m`, WMO `weather_code`, and `is_day` values in Fahrenheit and Unix time.
- **Decision:**
  - Request one UTC three-day window around `caughtAt`, then choose the closest complete hourly sample
    within 90 minutes. Use the Forecast API for catches from the prior five days through its 16-day
    horizon and the Historical Weather API for older catches; dates beyond the forecast horizon receive
    no suggestion. Both use `temperature_unit=fahrenheit`, `timeformat=unixtime`, and GMT.
  - Debounce automatic requests by 400 ms. A request key rounds coordinates to four decimals and time
    to the nearest hour; one form session caches completed keys and cancels an obsolete in-flight key.
    Requests time out after five seconds and failures remain an inline, non-blocking state.
  - Map WMO 0–1 to `sunny` by day and `clear_night` at night; 2 to `partly_cloudy`; 3 and snow codes
    71–77/85–86 to `overcast`; 45/48 to `fog`; drizzle, freezing precipitation, rain, showers, and
    thunderstorms to `rain`. Unknown future codes produce no sky suggestion rather than a false label.
  - Air temperature and sky condition track provenance in the draft only. A response may fill an empty,
    untouched field; any manual selection, entry, or clear permanently wins for that form session.
    Persist only the resulting values, never provenance, request keys, WMO codes, or raw responses.
- **Consequences:** Fixtures test request/decoding/mapping without live availability. Water temperature
  and clarity remain fully manual. The physical online/offline and real-provider pass is consolidated in
  Phase 11 with the final signed build.

## 2026-07-19 — Foreground location capture and manual MapKit fallback contract
- **Context:** Phase 05 needs useful coordinates without making Catch save depend on permission,
  satellite availability, Apple search, or a network connection. The named spot must stay human-owned
  rather than being silently replaced by reverse geocoding.
- **Decision:**
  - Request when-in-use permission only after the angler taps **Use Current Location**. Do not request
    at launch or when merely opening Add Catch or Map.
  - Accept a foreground fix only when its horizontal accuracy is positive and at most 100 meters and
    its timestamp is no more than two minutes old. Keep listening briefly for a better fix, but expose
    failure/manual fallback after 12 seconds; Catch save remains enabled throughout.
  - Coordinates are an optional pair: both latitude and longitude are present and range-valid, or both
    are `nil`. Editing can replace or clear the pair independently of the named `location` string.
  - Manual selection is a sheet with Apple `MKLocalSearch` results when available and direct map
    tap-to-drop/correct behavior that does not require search. Search failure is an honest inline state,
    never a reason to hide an already selected pin or prevent save.
  - Map and mini-map read only account-scoped local SwiftData. Missing Apple basemap tiles may be an
    offline presentation limitation, but cached Catch coordinates/pins and selected Catch data remain
    available.
- **Consequences:** No background-location capability is added. Core Location and MapKit are wrapped
  behind testable acceptance/domain seams; physical permission, outdoor GPS, and offline basemap
  behavior are repeated in Phase 11.

## 2026-07-19 — Catch-photo file, privacy, ordering, and cleanup contract
- **Context:** Phase 04 must keep photos usable offline while coordinating local files, private Storage
  objects, ordered metadata, cancellation, and retry without making Catch save depend on the network.
- **Decision:**
  - Normalize each selected image once to an orientation-corrected JPEG, maximum 2,048 pixels on its
    longest edge at 0.82 quality. Re-rendering intentionally strips embedded EXIF/GPS metadata; Catch
    coordinates are an explicit Phase 05 field rather than hidden photo metadata.
  - The private Storage bucket is `catch-photos`. Every object path is
    `<owner UUID>/<catch UUID>/<photo UUID>.jpg`; RLS checks both the authenticated owner segment and
    ownership of the parent Catch.
  - Draft files live separately from committed account/Catch files. Cancelling removes only that
    sheet's draft directory; saving atomically moves its files into the committed tree before queuing
    remote work. The local file is the UI source until a remote-only photo is downloaded and cached.
  - A `catch_photos` row carries position, version, update timestamp, and a deletion tombstone. New
    photos upload the idempotent binary before publishing metadata. Reorders update the complete local
    order and queue versioned metadata mutations. Deletes publish a tombstone before removing the
    object, so a failed cleanup remains retryable and cannot expose a broken live row.
  - Catch deletion queues every child-photo deletion first. Phase 11 owns a hosted orphan audit and
    repair rehearsal for abnormal client loss between Storage and metadata operations.
- **Consequences:** Catch save/edit remains offline-first; failed binary or metadata work is visible and
  retryable. Thumbnails must downsample at decode time rather than decoding the 2,048-pixel hero image
  in each scrolling card.

## 2026-07-19 — Catch conflicts, tombstones, and pending-data sign-out
- **Context:** Phase 02 adds offline edits and deletes. Creation-only upserts would silently overwrite
  divergent edits or allow a deleted Catch to reappear on another device.
- **Decision:**
  - Each remote Catch has a monotonically increasing `version`. Updates and tombstones apply only when
    the submitted base version matches the stored version.
  - A version conflict preserves the local draft, records the newly observed server version, and stops
    automatic retries for that operation. The visible Retry Sync action is the explicit “keep mine”
    choice; it retries against the observed version. Another intervening change produces another
    conflict rather than a silent overwrite.
  - Delete is a `deleted_at` tombstone, not an immediate hard delete. Tombstones are retained for at
    least 90 days; a hard-pruning job and recovery rehearsal belong to Phase 11.
  - Sign-out remains blocked while any Catch create, edit, delete, failed mutation, or unresolved
    conflict is queued. The user may retry without losing local work.
- **Consequences:** Pulls include tombstones and the local Log hides them. Mutation delivery is
  idempotent by Catch UUID, version, and payload. The sync boundary can later extend the same operation
  contract to photos, Tackle Items, and profiles without bypassing local-first persistence.

## 2026-07-19 — Phase 01 identity, environment, session, and device contract
- **Context:** The tracer bullet cannot be scaffolded until its Apple identity, Supabase environment,
  beta auth behavior, minimum offline session rules, and first physical-device test target are fixed.
- **Decision:**
  - App display name: **Lincoln's Reel Records**. Bundle identifier:
    **`com.bldgtyp.LincolnsReelRecords`**.
  - Signing and App Store Connect ownership use Edwin May's existing individual Apple Developer team,
    Team ID **`JPJ3AJ5U8A`**. The internal TestFlight tester is **`ed.p.may@gmail.com`**.
  - Create a new hosted Supabase beta project in the `bldgtyp` organization: project
    **`lincolns-reel-records`**, reference **`ptoqkqisgyzypfpjvmvx`**, in **`us-east-1`**. Debug and
    TestFlight use separate Xcode configurations; during Phase 01 both inherit this hosted project's
    public host/key from `Config/Base.xcconfig` while local Supabase remains optional. No service-role or
    secret key is stored in the app. Operational identifiers and account roles are maintained in
    `environments-and-accounts.md`.
  - Disable Supabase signup email confirmation for the email-invite-only beta so signup enters the app
    immediately. First signup/login requires a network connection.
  - After a successful login, a cached authenticated session may reopen its account-scoped SwiftData
    logbook offline. A failed refresh caused only by unavailable connectivity does not hide or discard
    cached data; a definitively invalid session returns to authentication. Startup must expose the
    cached account and local logbook before awaiting network-backed profile/session validation, and an
    account restored as offline must not start automatic remote synchronization.
  - Phase 01 blocks sign-out while that account has pending or failed Catch creations, shows the pending
    count, and offers retry. The Phase 02 decision above extends that policy to every queued mutation and
    unresolved conflict.
  - Initial device acceptance uses an **iPhone 16 Pro on iOS 18.6**.
- **Consequences:** Phase 01 closeout requires migration evidence, an App Store Connect record, a signed
  TestFlight build, physical-device offline/reconnect results, and normally signed fresh-install hosted
  recovery evidence. The recovery check may use a second physical device or Simulator; Phase 11 repeats
  clean-install and second-device recovery on physical hardware against the final included schema.
  Simulator integration runs that exercise Supabase Auth must use normal Simulator ad-hoc signing;
  `CODE_SIGNING_ALLOWED=NO` prevents Keychain-backed session persistence and makes PostgREST requests
  fall back to the anonymous role.

## 2026-07-19 — Notifications behavior deferred; v1 row is disabled
- **Context:** The Profile mockup includes Notifications, but no notification event, cadence, permission
  timing, or user value has been specified. Building notification infrastructure would expand scope
  without an acceptance contract.
- **Decision:** Notifications behavior is post-v1. If the Settings row is retained in v1, it is disabled
  and labeled Coming Soon; it must not request notification permission or imply working behavior.
- **Consequences:** Phase 09 owns the honest placeholder state. A future notification feature requires a
  new decision/story before implementation.

## 2026-07-19 — Local-first SwiftData persistence with an explicit outbox
- **Context:** Offline logging/browsing is P0, including queued photo and Tackle Box work. An online-first
  Supabase client with a cache added later would make save reliability and UI behavior network-dependent.
- **Decision:** SwiftData is the authenticated UI's on-device source. Mutations commit locally first and
  enter an explicit outbox; a sync coordinator pushes pending work and merges pulled Supabase state.
  Client-generated UUIDs allow offline creation. Photos use local files plus separately queued uploads.
- **Consequences:**
  - Supabase DTOs stay separate from SwiftData persistence models.
  - Sync failure preserves local authored data and exposes retry state; remote calls never block a save.
  - Local data is account-scoped and must not leak across sign-out/account changes.
  - Minimum unsynced sign-out behavior is a pre-Phase-01 decision. Conflict resolution and tombstone
    retention remain pre-Phase-02 decisions.
  - Phase 01 validates the minimum real path before the sync engine is generalized.

## 2026-07-19 — Feature-oriented SwiftUI + Observation architecture
- **Context:** The app needs clear state/dependency ownership without introducing broad MVVM ceremony or
  a third-party state framework before actual complexity exists.
- **Decision:** Use SwiftUI-native state and Observation, organized by vertical feature. Keep value state
  local; introduce small `@Observable` feature models only for async or multi-step coordination. Feature
  repositories own application data operations. Root wiring owns auth, repositories, sync, connectivity,
  configuration, tabs, navigation paths, and enum-driven sheets.
- **Consequences:**
  - Views do not perform Supabase/SwiftData business operations directly.
  - Start with one app target plus unit/UI-test targets; split packages only from demonstrated pressure.
  - Add design-system components when a real slice first requires them rather than building a horizontal
    component library.
  - `context/implementation-plan.md` and `context/implementation-phases/` define the delivery sequence.

## 2026-07-19 — Drop in-app approval; TestFlight invite is the gate (supersedes part of Q1)
- **Context:** The original Q1 decision added an in-app **manual approval** step. On review, TestFlight
  distribution already gates access: if we **invite by email** (not a public link), only invited people
  can install and reach signup — so an approval step is a redundant second gate.
- **Decision:** **Remove in-app approval** for v1. **TestFlight email-invites are the access gate.**
  Users sign up and go straight in. Accounts/login (Supabase Auth) stay; each logbook is private (RLS).
- **Consequences:**
  - **Removed:** `User.approved`, `User.role` (admin/angler), the pending-approval screen, the
    signup→admin approval email, and the approve-link Edge Function. Story **E1b deleted**; E1 simplified.
  - **Condition:** invite **by email**, not a public TestFlight link (a public link would reopen the gap).
  - Reversible: approval can be added back later if we ever go public-link. Revocation for now = remove
    the user from TestFlight (and/or delete their account).

## 2026-07-19 — Schema details from the pre-implementation doc audit
- **Context:** an independent audit flagged three schema-blocking ambiguities and several smaller gaps.
- **Decisions:**
  - **Catch photos → child table `CatchPhoto`** (`id`, `catchId`, `storagePath`, `position`, `createdAt`)
    rather than an array column — needed for ordered, reorderable multi-photo. TackleItem keeps a single
    Storage-path column (no child table). Data model is now **four tables**: User, Catch, TackleItem,
    CatchPhoto (PRD §5.3).
  - **Catch time = `caughtAt timestamptz`** (not date-only), default now, editable. Required by
    weather-by-time, the `clear_night` sky value, and intra-day "Recent" sort (PRD §5.0).
  - **`species` = text** (not a DB enum) with a seed suggestion list, since custom values are allowed.
  - **Closed enums fixed:** `skyCondition` = {sunny, partly_cloudy, overcast, rain, fog, clear_night}
    (→ the 6 weather icons); `waterClarity` = {clear, stained, muddy}. Open-Meteo WMO-code → skyCondition
    mapping finalized at build time.
  - **Spot derivation rule:** group by **normalized `location`** (trim + case-insensitive exact match)
    for v1; proximity clustering is post-v1.
  - **Profile editing** exists (story E6); added `homeWater` to User; `anglerSince` is an int year.
  - **`bookmarked`** gets a retrieval surface: a **Saved filter** in the Log.
  - **Offline scope** includes Tackle Box CRUD and queued photo uploads (not just catches).
- **Consequences:** the schema and screen-by-screen plan can proceed (the admin-approval question was
  resolved by dropping approval — see the entry above).

## 2026-07-19 — UI conventions: dark-only + SF Symbols
- **Context:** design-system flagged two conventions to confirm.
- **Decision:** (1) **Dark-only** in v1 — the prototype's dark theme is the design; no light mode.
  (2) **SF Symbols** are the primary icon source; bundle a custom/FontAwesome glyph only where SF
  Symbols has no good match (e.g. lure/worm). Encode design tokens once (Theme + asset catalog + Font
  extension), per `design-system.md`.
- **Consequences:** simpler theming; revisit light mode only if a user asks.

## 2026-07-19 — Add a Tackle Box (structured lures/bait) — new feature
- **Context:** The prototype's `lure` is a single free-text field — messy and un-analyzable. Ed wants a
  catalog of gear to pick from.
- **Decision:** Add a **Tackle Box**: a per-user catalog of **TackleItem** records (name, type, size,
  color, brand, photo — see PRD §5.1). When logging a catch, the lure field becomes a **picker** from
  the Tackle Box (`tackleItemId`), with a **free-text fallback** (`lureText`) for one-offs.
  - New screen **Tackle Box** (catalog grid + add/edit sheet), reached from **Profile** and from the
    **Add-Catch lure picker** — **not** a 6th tab (tab bar is full at 5).
  - Items are private (RLS-scoped), stored in Supabase; photos in Supabase Storage.
  - Mockup built in the app's design language: **`mockups/tacklebox.html`** (catalog / add / pick-in-log).
- **Consequences:**
  - Catch model: replace free-text `lure` with `tackleItemId` (nullable) + `lureText` fallback.
  - New table `tackle_items`; `archived` flag to retire gear without breaking historical catches.
    Per-item catch count is derivable but its display remains post-v1 F4 unless reprioritized.
  - New user stories **Epic F** + **A7**; design-system gains a tackle-card + color-swatch component.

## 2026-07-19 — Minimum iOS target: iOS 18 (PRD Q9)
- **Context:** Ed & Lincoln are on iOS 26 (current, year-named; the version after iOS 18). Question was
  whether to set the floor that high.
- **Decision:** **Develop/test on iOS 26**, but set the **minimum deployment target to iOS 18**. The
  floor need not match the devs' devices; a lower floor lets friends/family install without being forced
  to the very latest OS, while iOS 18 still provides the full modern toolkit.
- **Rationale:** SwiftData, Observation, and modern MapKit-SwiftUI are all available at iOS 17+ / mature
  at 18 — so nothing modern is lost by targeting 18 instead of 26.
- **Consequences:**
  - **SwiftData** is available as the on-device local-cache option (helps resolve the open offline
    strategy — the Supabase-sync detail still to be finalized).
  - Trivially adjustable later (raise if all invitees are on 26; that's a single build-setting change).

## 2026-07-19 — Add kept/released flag (PRD Q8)
- **Context:** Prototype narrates releasing fish but has no field for it.
- **Decision:** Add a **`released` toggle** (Released / Kept) to each catch, **defaulting to Released**.
- **Consequences:** One extra toggle in Add Catch; a small badge on the catch card/detail; enables a
  future "release rate" stat. Trivial to store.

## 2026-07-19 — Conditions: layered auto/manual + structured (PRD Q7)
- **Context:** Prototype has free-text weather/water. Want convenience online, resilience offline, and
  cleaner data for future stats.
- **Decision:** Multi-layered conditions capture:
  - **Numeric (air temp):** auto-fetch from a **free, keyless weather API — Open-Meteo** (recommended)
    using the catch's **GPS + timestamp**; **editable**. **Offline → manual** numeric entry.
  - **Non-numeric:** **structured inputs** instead of free text:
    - **Sky condition** picker (e.g. Sunny, Partly Cloudy, Overcast, Light Rain, Rain, Fog, Clear
      Night) → drives the existing weather icons (`fa-sun`, `fa-cloud-sun`, `fa-cloud`, `fa-cloud-rain`,
      `fa-smog`, `fa-moon`). Auto-suggested from the API when online; always overridable.
    - **Water clarity** chips (Clear, Stained, Muddy) — **manual** (API can't know a local pond).
  - **Water temp:** manual numeric (no reliable API source for a specific spot).
- **Alternatives considered:** pure free text (prototype — less consistent); full API auto-fill only
  (breaks offline-first); fully structured only (slower to log). Layered wins.
- **Consequences:**
  - Adds an **Open-Meteo** client (no key, free, has historical). Must **degrade gracefully offline**
    and never block a save.
  - Catch model: replace free-text `weather`/`water` with `airTempF`, `skyCondition` (enum),
    `waterTempF`, `waterClarity` (enum). `weatherIcon` derives from `skyCondition`.

## 2026-07-19 — Export: per-catch share image in v1 (PRD Q6)
- **Context:** Profile has an "Export logbook" row with no behavior; also a per-catch share icon.
- **Decision:** v1 ships **per-catch share as a composed image** (photo + species + weight/length +
  spot/date) via the iOS **share sheet** — this fulfills the catch "share" action (story B6).
  **Full-logbook export (PDF/CSV) deferred** post-v1; the Profile "Export logbook" row shows as
  "coming soon"/disabled for now. Data safety is already covered by the Supabase backend, so a full
  export isn't needed for backup.
- **Consequences:** Need an image-composition step (render a catch card to an image). Keeps sharing
  personal (send a picture), not social-network posting.

## 2026-07-19 — Units: imperial-only in v1 (PRD Q5)
- **Context:** US/Massachusetts anglers; prototype is lb · in and shows a Units setting.
- **Decision:** Ship **imperial only** (lb · in) in v1. Keep weight/length as plain numeric fields.
  Metric toggle **deferred** (not blocked — store values consistently so a display-time converter can
  be added later without migration).
- **Consequences:** Units row in Settings is a static/placeholder for now; revisit if a metric user
  ever appears.

## 2026-07-19 — Photos: multiple per catch (PRD Q4)
- **Context:** Prototype shows one photo; anglers usually take several (grip shot, release, lure).
- **Decision:** A catch holds **multiple photos**. The **first photo is the hero** (card/detail image);
  the rest show in a small gallery/carousel on Catch Detail, added via a multi-select picker in Add
  Catch. Images stored in **Supabase Storage**; catch record holds an **ordered list of photo refs**.
- **Consequences:** Add Catch and Catch Detail gain a lightweight photo carousel/reorder. A catch with
  zero photos still saves (clean placeholder). Storage-cost trivial at this scale.

## 2026-07-19 — Map: MapKit + real GPS (PRD Q3)
- **Context:** The prototype's map is a decorative abstract canvas with fake pin coords. "Favorite
  spots" is a core value; it needs real geography.
- **Decision:** Use **Apple MapKit** with **real GPS coordinates** captured at logging time.
  - Request **location permission** (when-in-use); capture lat/long on a new catch when available.
  - Pins render on a real (dark-styled) map; Catch Detail's mini-map shows the true spot.
  - **Manual pin-drop / map-search fallback** when GPS is off, denied, or the catch is logged later.
  - Keep the free-text **named spot** too (human label like "Cedar Point Cove"), alongside coordinates.
- **Consequences:**
  - Catch model gains real `latitude`/`longitude` (replacing the prototype's `mapX`/`mapY`); `location`
    name stays. Consider a separate **Spot** concept later (cluster catches by proximity).
  - Adds a location-permission prompt + graceful "no location" path (privacy: coords stay in the
    user's own data under RLS).

## 2026-07-19 — Backend: Supabase (Database & sync, PRD Q2)
- **Context:** Q1 requires a hosted backend (accounts, photo storage, data stored for several separate
  users — each private). Ed already has a Supabase account.
- **Decision:** Use **Supabase** — reuse Ed's existing account, add a project/section for this app.
  - **Postgres** for relational data (users, catches, tackle items, catch photos). Spots are *derived*,
    not stored (PRD §5.3).
  - **Supabase Auth** for email/password login.
  - **Supabase Storage** for catch photos.
  - **Row-Level Security** so each angler sees only their own rows.
- **Alternatives considered:** Firebase (NoSQL, less natural for relational catches; Google lock-in);
  CloudKit (poor fit for multi-user + custom approval); custom server (overkill).
- **Consequences / follow-ups:**
  - Auth emails (confirm-email / password-reset) use Supabase's built-in email; configure SMTP only if
    deliverability needs it. (No custom approval email — approval was dropped.)
  - **Offline strategy superseded:** the later local-first SwiftData plus explicit outbox decision above
    resolves this follow-up; catches commit locally and synchronize to Supabase when online.
  - iOS client talks to Supabase via the `supabase-swift` SDK.

## 2026-07-19 — Real accounts (Auth model, PRD Q1)
> **Partially superseded** (same day): the **manual-approval** part was dropped — see "Drop in-app
> approval; TestFlight invite is the gate" above. Real accounts + no payments still stand.
- **Context:** Not just Lincoln — a handful of friends & family should be able to use the app.
- **Decision:** Real login/accounts backed by a server. Users self-register in-app; each new account
  is **manually approved** by an admin (Ed or Lincoln) before it can log in. Signup triggers an
  **email notification** to the admin(s). **No payments, no credit-card data** ever.
- **Consequences:**
  - We need a **backend + hosted database** (an account store, an `approved` flag per user, and a
    transactional email on signup). This effectively decides Q2 toward a cloud backend, not local-only.
  - Adds an **admin/approval concept** and roles (admin vs. angler) to the data model.
  - Keep the Welcome/Login/Signup screens from the prototype; add a "pending approval" state.
  - Passwords for minors — favor a provider that handles auth securely (hosted auth, hashed at rest);
    avoid rolling our own credential storage.

## 2026-07-19 — Distribution via TestFlight (no App Store)
- **Context:** Ed asked whether an app can be installed without being on the App Store.
- **Decision:** Distribute through **TestFlight**. Requires the **Apple Developer Program ($99/yr)**,
  enrolled individually. No public App Store listing, no in-app purchases.
- **Alternatives considered:** free-Apple-ID sideload (7-day expiry, cable+Xcode each time — no good
  for non-technical users); ad-hoc UDID / Enterprise (clunky / not permitted for this use).
- **Consequences:**
  - The **TestFlight email-invite list is the access gate** (later decision dropped the separate in-app
    approval — see "Drop in-app approval" above).
  - Builds expire ~**90 days** → periodic re-upload. First external build gets a light Apple beta review.
  - **Ed already has an Apple Developer Program account** — reuse it; no enrollment needed.

### Template

```
## YYYY-MM-DD — <decision title>
- **Context:** why this came up.
- **Decision:** what we chose.
- **Alternatives considered:** ...
- **Consequences:** tradeoffs, follow-ups.
```
