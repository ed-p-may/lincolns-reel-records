# Reel Records — Product Requirements (PRD)

> Derived from the Claude Design prototype (`Lincoln's Reel Records - Claude Design/`).
> Source of truth for scope. Update as decisions land in `decisions.md`.

## 1. Summary

**Reel Records** is an iOS app for a small, invite-only circle of anglers to **log, browse, and
remember fishing catches**. Each angler keeps their **own private logbook**. It should feel like a
**premium fishing journal** crossed with a **modern tracking app**: dark, image-forward, tactile, fast
to log in the field. It is **not** a public social network — there is no feed, following, or sharing
between users.

## 2. Who it's for

- **Instigator / first user:** Lincoln — 15, fishes lakes/ponds in western Massachusetts (Sheffield).
- **Built & administered by:** Ed (his uncle).
- **User base:** a **handful of friends & family** (not just Lincoln), invited via TestFlight and
  **manually approved** by an admin (Ed/Lincoln) before their account works.
- **Implication:** real multi-user backend; each user's catches/tackle are **private to them** (no
  cross-user visibility in v1), synced across their own devices. Still **not** social — no followers,
  feed, or inter-user sharing. "Share" a catch = export/send an image, not post to a network.

## 3. Product goals

1. **Log a catch in under a minute**, one-handed, possibly offline, standing on a bank or in a boat.
2. **Make the logbook a joy to revisit** — a beautiful, browsable, searchable history.
3. **Surface simple insight** — biggest fish, top species, favorite spots, species variety — without
   feeling like a spreadsheet.
4. **Never lose a catch** — synced to the Supabase backend and cached locally; the record is the point.

## 4. Non-goals (v1)

- Public/social feed, followers, likes, comments.
- **Sharing or visibility between users** (each logbook is private; multi-user accounts *do* exist).
- **Full-logbook export** (PDF/CSV) — deferred; per-catch share image ships (§6, Q6).
- **Metric units** — imperial only in v1 (Q5).
- Catch identification (AI species ID from photo).
- Regulations, licensing, or catch-limit tracking.
- A dedicated **Spot** entity — "favorite spots" are *derived* by grouping catches in v1 (see §5.3).

These are parked, not rejected — revisit post-v1.

## 5. Data model

Three stored entities — **User**, **Catch**, **TackleItem** — plus derived **Spots** (§5.3). Every
`ownerId` / `userId` is RLS-scoped so a user only ever sees their own rows.

### 5.0 The core object: a Catch

Fields below come from the prototype's data model, updated by our decisions.

| Field | Type | Notes | Required |
|-------|------|-------|----------|
| `id` | id | stable unique id | yes (system) |
| `ownerId` | ref → User | whose catch this is (RLS-scoped) | yes (system) |
| `species` | enum + custom | picked from a known list; allow custom entry | yes |
| `weight` | decimal (lb) | 1 decimal shown | recommended |
| `length` | decimal (in) | | recommended |
| `date` | date | defaults to today | yes |
| `location` | string | named spot (e.g. "Cedar Point Cove") | recommended |
| `latitude` / `longitude` | double | real GPS captured at logging (or manual pin-drop); replaces prototype `mapX/mapY` | optional |
| `airTempF` | number (°F) | auto from Open-Meteo (GPS+time) when online; manual offline | optional |
| `skyCondition` | enum | structured picker; drives weather icon; API-suggested, overridable | optional |
| `waterTempF` | number (°F) | manual (no reliable API source) | optional |
| `waterClarity` | enum | Clear / Stained / Muddy (manual) | optional |
| `tackleItemId` | ref → TackleItem | selected from the **Tackle Box** (§5.1); nullable | optional |
| `lureText` | string | free-text fallback when no Tackle Box item is picked (one-offs) | optional |
| `rodReel` | string | rod & reel setup | optional |
| `notes` | string (long) | field notes / story | optional |
| `photos` | ordered list of images | **multiple** per catch; first = hero. In Supabase Storage | recommended |
| `released` | bool | **Released (default) / Kept** (Q8) | recommended |
| `bookmarked` | bool | user's saved/favorite flag (story B6) | optional |
| `createdAt` / `updatedAt` | timestamp | system audit fields (sync/ordering) | yes (system) |

**Species list (v1 seed):** Largemouth Bass, Smallmouth Bass, Northern Pike, Walleye, Crappie,
Bluegill, Channel Catfish, Rainbow Trout. Editable/extendable; allow "Other → custom".

**Units:** imperial (lb · in) only in v1 (Q5). Store plain numeric values; the Settings "Units" row is a
static placeholder (metric deferred, no data migration needed later).

### 5.1 Second object: a TackleItem (Tackle Box)

A per-user catalog of lures & bait, built once and reused. Replaces the prototype's free-text `lure`
field with structured, selectable, analyzable data. Mockup: `mockups/tacklebox.html`.

| Field | Type | Notes | Required |
|-------|------|-------|----------|
| `id` | id | stable unique id | yes (system) |
| `ownerId` | ref → User | each angler has their own Tackle Box (RLS-scoped) | yes (system) |
| `name` | string | e.g. "Green Pumpkin Senko" | yes |
| `type` | enum | Soft Plastic, Crankbait, Spinnerbait, Jig, Topwater, Spoon, Fly, Live Bait, Other | yes |
| `size` | string | free text — length or weight ("5\"", "1/2 oz") | optional |
| `color` | string | color name (e.g. "Green Pumpkin") | optional |
| `brand` | string | optional maker (e.g. "Yamamoto") | optional |
| `photo` | image | one photo, Supabase Storage | optional |
| `archived` | bool | hide retired items without deleting history | optional |

- **Relationship:** a Catch references one TackleItem via `tackleItemId` (nullable); `lureText` is the
  free-text fallback for a one-off not worth cataloging. A TackleItem's **catch count** is derived
  (how many catches reference it) — shown on its card.
- **Ownership:** private to each user, like catches. Not shared between anglers in v1.

### 5.2 Third object: a User (account)

Backed by Supabase Auth (credentials) + a `profiles` row (app data). Central to the approval workflow.

| Field | Type | Notes | Required |
|-------|------|-------|----------|
| `id` | id | matches the Supabase Auth user id | yes (system) |
| `email` | string | login credential (managed by Supabase Auth) | yes |
| `username` | string | display handle (e.g. "lincoln_reels") | yes |
| `displayName` | string | full name shown on Profile ("Lincoln Reyes") | optional |
| `role` | enum | `admin` (Ed/Lincoln — can approve) or `angler` | yes |
| `approved` | bool | **false until an admin approves**; gates all access | yes |
| `avatar` | image | profile photo, Supabase Storage | optional |
| `anglerSince` | year/date | shown as "Angler since YYYY" | optional |
| `createdAt` | timestamp | signup time; drives the admin email | yes (system) |

- **Approval flow:** signup → `approved=false` → **email to admin(s)** → admin flips `approved=true` →
  user can log in and use the app. Un-approved users see a **pending** state.
- **Security:** Supabase Auth handles credentials (hashed at rest); we never store passwords or card
  data. RLS ties every Catch/TackleItem to its `ownerId`.

### 5.3 Relationships & derived data

- **User 1—* Catch** (`Catch.ownerId`), **User 1—* TackleItem** (`TackleItem.ownerId`).
- **Catch *—1 TackleItem** (`Catch.tackleItemId`, nullable; `lureText` is the free-text fallback).
- **Catch 1—* Photo** (ordered; first = hero). **TackleItem 0..1 Photo.**
- **Spots are derived, not stored (v1):** "favorite spots" come from grouping a user's catches by
  `location` name (and/or proximity of `latitude`/`longitude`). A first-class **Spot** entity is a
  post-v1 consideration (see §4, decisions.md).
- **Catch counts / stats** (§7) are computed over a user's catches — not stored.

## 6. Features / screens

### 6.1 Onboarding — Welcome / Login / Signup
- Welcome: hero photo, brand mark, tagline "Track every catch. Remember every adventure.", Get Started
  / Log In / Create Account.
- Login (email + password) and Signup (username + email + password).
- **Decided (Q1):** **real accounts** backed by a server. A handful of friends & family, not just
  Lincoln. Self-registration + **manual admin approval** (Ed/Lincoln) before login; signup sends an
  **email notice** to admin(s). **No payments / no card data.** New screen state: **"pending approval"**
  after signup, before an admin approves. Roles: **admin** vs. **angler**.
- **Distribution:** **TestFlight** (Apple Developer Program, $99/yr), not the public App Store. Install
  = TestFlight invite; use = approved account. See `decisions.md`.

### 6.2 Home / Dashboard
- Date + greeting ("Morning, {first name}" — the logged-in user).
- Hero stat: **total catches logged** + trend ("+2 this week") + primary **Log a Catch** button.
- Four stat tiles: **biggest** (weight + species), **top species** (+count), **favorite spot**
  (+count), **species this year** (distinct count).
- **Recent catches** horizontal carousel (photo, weight badge, species, spot) → opens Catch Detail.
- **Favorite spots** list (name, catch count, best fish) → opens Map.

### 6.3 Log (the logbook)
- Header with total ("N in your records").
- **Search** across species, spot, lure (tackle item name / `lureText`), notes.
- **Species filter** chips (All + one per logged species).
- **Sort**: Recent / Heaviest / Longest.
- Rich catch cards: photo, weight + length badges, species, spot, date, lure, weather icon → Catch
  Detail.

### 6.4 Map
- Real **MapKit** map (dark-styled) with all of the user's catches as **pins at their true GPS
  locations** (Q3). Selected pin enlarges + ripples (per the prototype's styling).
- **GPS** is captured at logging (location permission); **manual pin-drop / map-search fallback** when
  GPS is off/denied or a catch is logged later. Free-text named `location` is kept alongside coordinates.
- Header: "N catches across M spots".
- Selected-catch card at bottom → Catch Detail.

### 6.5 Profile / You
- Avatar, name, @handle, "Angler since YYYY · Home Lake".
- Stat row: total catches / personal best / species count.
- **Signature species** highlight.
- **Species breakdown** bars (count per species).
- **My Tackle Box** row → opens the Tackle Box (§6.8).
- **Settings:** Units (lb · in), Notifications, **Export logbook** (full-export deferred → "coming
  soon"; per-catch share image ships in v1 via the catch share action).
- Sign out.

### 6.6 Add Catch (overlay)
- Bottom-sheet form: photo(s), species chips, weight, length, date (default today), location, weather,
  water, **lure (Tackle Box picker)**, rod & reel, released toggle, notes → **Save Catch**.
- **Lure picker:** select from the Tackle Box (currently-picked item shown as a card; a horizontal row
  of other items; **+ New lure** adds one inline; **Manage Tackle Box** opens §6.8). Free-text fallback
  (`lureText`) for a one-off. See `mockups/tacklebox.html`, frame 3.
- Optimized for speed: sensible defaults, big tap targets, minimal required fields (species + date).

### 6.7 Catch Detail (overlay)
- Full-bleed hero photo (swipe for the catch's other photos); bookmark + share actions.
- Hero stats: weight + length.
- **Conditions & gear** grid: weather (sky + air temp), water (clarity + temp), **lure/bait** (the
  Tackle Box item — photo/name/type, tap → its Tackle Box entry), rod & reel; released/kept badge.
- **Field notes** block.
- **"Where it happened"** mini-map → jumps to Map.
- **Edit / delete** actions (story A6).

### 6.8 Tackle Box
- A per-user catalog of lures & bait (see §5.1). Mockup: `mockups/tacklebox.html`.
- **Catalog:** header + count, **search**, **type filter** chips, 2-col grid of item cards (photo, type
  badge, color swatch, name, size · brand, **catch count**). Tap a card → edit.
- **Add / Edit item** (bottom sheet): photo, name, type chips, size, color (+ swatch), optional brand →
  Save.
- **Entry points:** from Profile ("My Tackle Box") and inline from the Add-Catch lure picker.
- **Navigation note:** the bottom tab bar is already full (Home / Log / + / Map / You), so Tackle Box is
  a **pushed screen**, not a 6th tab. Revisit if it deserves top-level status later.

## 7. Derived data / stats (computed, not stored)

From the catch set: total; biggest (max weight); top/favorite species (mode); distinct species count;
per-spot counts and best fish; favorite spot; recent (by date); species breakdown; weekly trend.
Keep these as pure derivations over the stored catches.

## 8. Key UX principles

- **Field-first:** logging must work fast, one-handed, offline. Save first, enrich later.
- **Photo-forward:** the fish photo is the hero of every card and screen.
- **Calm, premium, dark:** see `design-system.md`. No noisy feed, no gamification pressure.
- **Personal + durable:** each angler's logbook is theirs alone; nothing is shared between users,
  nothing is lost (synced + cached).

## 9. Open questions (resolve before/with infra)

1. ~~**Auth model**~~ — ✅ **Decided:** real accounts + manual approval + email notice; TestFlight
   distribution; no payments. See `decisions.md` (2026-07-19).
2. ~~**Storage & sync**~~ — ✅ **Decided:** **Supabase** backend (Postgres + Auth + Storage + RLS).
   On-device offline-cache strategy still to be finalized. See `decisions.md` (2026-07-19).
3. ~~**Map**~~ — ✅ **Decided:** real MapKit + GPS capture, manual fallback. See `decisions.md`.
4. ~~**Photos**~~ — ✅ **Decided:** multiple per catch (first = hero), in Supabase Storage. See
   `decisions.md`.
5. ~~**Units**~~ — ✅ **Decided:** imperial-only (lb · in) in v1; metric deferred. See `decisions.md`.
6. ~~**Export logbook**~~ — ✅ **Decided:** v1 = per-catch **share image** (fulfills B6); full-logbook
   PDF/CSV export deferred. See `decisions.md`.
7. ~~**Weather/water**~~ — ✅ **Decided:** layered — auto-fill air temp from Open-Meteo (GPS+time,
   editable), manual offline; structured pickers for sky condition & water clarity; water temp manual.
   See `decisions.md`.
8. ~~**"released" flag**~~ — ✅ **Decided:** add Released/Kept toggle, default Released. See
   `decisions.md`.
9. ~~**Min iOS version**~~ — ✅ **Decided:** build on iOS 26, **minimum target iOS 18** (keeps
   SwiftData + modern APIs). See `decisions.md`.

All nine are resolved. **Remaining open items are implementation-time details** (tracked in
`decisions.md` → "Open decisions"), not product scope: (a) on-device persistence + offline-sync
strategy, (b) transactional email provider for the approval notice, (c) app architecture pattern. These
get decided as we build; they don't block the phase plan.
