# Reel Records — Product Requirements (PRD)

> Derived from the Claude Design prototype (`Lincoln's Reel Records - Claude Design/`).
> Source of truth for scope. Update as decisions land in `decisions.md`.

## 1. Summary

**Reel Records** is a personal iOS app that lets one angler **log, browse, and remember fishing
catches**. It should feel like a **premium fishing journal** crossed with a **modern tracking app**:
dark, image-forward, tactile, fast to log in the field. It is a private logbook, **not** a public
social network.

## 2. Who it's for

- **Primary user:** Lincoln — 15, fishes lakes/ponds in western Massachusetts (Sheffield area).
- **Built by:** Ed (his uncle). Single-user, personal use.
- **Implication:** one person's data, one device to start. Any multi-user, following, or public feed
  is explicitly out of scope. "Share" a catch = export/send an image, not post to a network.

## 3. Product goals

1. **Log a catch in under a minute**, one-handed, possibly offline, standing on a bank or in a boat.
2. **Make the logbook a joy to revisit** — a beautiful, browsable, searchable history.
3. **Surface simple insight** — biggest fish, top species, favorite spots, species variety — without
   feeling like a spreadsheet.
4. **Never lose a catch** — durable local storage; the record is the point.

## 4. Non-goals (v1)

- Public/social feed, followers, likes, comments.
- Multi-user accounts or sharing between anglers.
- Live weather/water API integration (conditions are typed by hand in v1).
- Real-time GPS map tiles / third-party map SDK (see Map notes §6.4).
- Catch identification (AI species ID from photo).
- Regulations, licensing, or catch-limit tracking.

These are parked, not rejected — revisit post-v1.

## 5. The core object: a Catch

Every feature orbits one entity. Fields below come directly from the prototype's data model.

| Field | Type | Notes | Required |
|-------|------|-------|----------|
| `id` | id | stable unique id | yes (system) |
| `species` | enum + custom | picked from a known list; allow custom entry | yes |
| `weight` | decimal (lb) | 1 decimal shown | recommended |
| `length` | decimal (in) | | recommended |
| `date` | date | defaults to today | yes |
| `location` | string | named spot (e.g. "Cedar Point Cove") | recommended |
| `coordinates` | lat/long | real GPS; prototype fakes this as `mapX/mapY` | optional |
| `weather` | string | free text in v1 (e.g. "Overcast · 66°F") | optional |
| `water` | string | free text (e.g. "Stained · 68°F") | optional |
| `lure` | string | lure / bait used | optional |
| `rodReel` | string | rod & reel setup | optional |
| `notes` | string (long) | field notes / story | optional |
| `photo` | image | one photo in prototype; consider multiple | recommended |
| `released` | bool | kept vs. released — *not in prototype, propose adding* | optional |

**Species list (v1 seed):** Largemouth Bass, Smallmouth Bass, Northern Pike, Walleye, Crappie,
Bluegill, Channel Catfish, Rainbow Trout. Editable/extendable; allow "Other → custom".

**Units:** imperial (lb · in). A metric toggle is shown in Settings — treat as display preference over
stored canonical units. Confirm whether v1 ships the toggle or just imperial (see §9).

## 6. Features / screens

### 6.1 Onboarding — Welcome / Login / Signup
- Welcome: hero photo, brand mark, tagline "Track every catch. Remember every adventure.", Get Started
  / Log In / Create Account.
- Login (email + password) and Signup (username + email + password).
- **Open question:** for a single-user personal app, is real auth needed at all, or is this a local-only
  passcode / "it's your phone" model? Drives infra. See `decisions.md`.

### 6.2 Home / Dashboard
- Date + greeting ("Morning, Lincoln").
- Hero stat: **total catches logged** + trend ("+2 this week") + primary **Log a Catch** button.
- Four stat tiles: **biggest** (weight + species), **top species** (+count), **favorite spot**
  (+count), **species this year** (distinct count).
- **Recent catches** horizontal carousel (photo, weight badge, species, spot) → opens Catch Detail.
- **Favorite spots** list (name, catch count, best fish) → opens Map.

### 6.3 Log (the logbook)
- Header with total ("N in your records").
- **Search** across species, spot, lure, notes.
- **Species filter** chips (All + one per logged species).
- **Sort**: Recent / Heaviest / Longest.
- Rich catch cards: photo, weight + length badges, species, spot, date, lure, weather icon → Catch
  Detail.

### 6.4 Map
- All catches as pins over a stylized "home lake" backdrop; selected pin enlarges + ripples.
- Header: "N catches across M spots".
- Selected-catch card at bottom → Catch Detail.
- **Prototype uses fake `mapX/mapY` on an abstract canvas.** v1 decision: keep the stylized abstract
  map, or adopt a real map (MapKit) with GPS-tagged catches? Real GPS is the bigger lift but the more
  useful feature for "favorite spots." See `decisions.md`.

### 6.5 Profile / You
- Avatar, name, @handle, "Angler since YYYY · Home Lake".
- Stat row: total catches / personal best / species count.
- **Signature species** highlight.
- **Species breakdown** bars (count per species).
- **Settings:** Units (lb · in), Notifications, **Export logbook**.
- Sign out.

### 6.6 Add Catch (overlay)
- Bottom-sheet form: photo, species chips, weight, length, date (default today), location, weather,
  water, lure/bait, rod & reel, notes → **Save Catch**.
- Optimized for speed: sensible defaults, big tap targets, minimal required fields (species + date).

### 6.7 Catch Detail (overlay)
- Full-bleed hero photo; bookmark + share actions.
- Hero stats: weight + length.
- **Conditions & gear** grid: weather, water, lure/bait, rod & reel.
- **Field notes** block.
- **"Where it happened"** mini-map → jumps to Map.

## 7. Derived data / stats (computed, not stored)

From the catch set: total; biggest (max weight); top/favorite species (mode); distinct species count;
per-spot counts and best fish; favorite spot; recent (by date); species breakdown; weekly trend.
Keep these as pure derivations over the stored catches.

## 8. Key UX principles

- **Field-first:** logging must work fast, one-handed, offline. Save first, enrich later.
- **Photo-forward:** the fish photo is the hero of every card and screen.
- **Calm, premium, dark:** see `design-system.md`. No noisy feed, no gamification pressure.
- **Personal + durable:** it's Lincoln's record; nothing is public, nothing is lost.

## 9. Open questions (resolve before/with infra)

1. **Auth model** — real accounts vs. local-only/passcode for a single-user app.
2. **Storage & sync** — device-only vs. iCloud/CloudKit backup (protects against a lost phone).
3. **Map** — stylized abstract map vs. real MapKit + GPS coordinates.
4. **Photos** — single vs. multiple per catch; where images live (on-device, iCloud).
5. **Units** — ship metric toggle in v1 or imperial-only.
6. **Export logbook** — format (PDF journal? CSV? shareable image per catch?) and priority.
7. **Weather/water** — free text (v1) vs. later auto-fill from a weather API + timestamp/location.
8. **"released" flag** — add catch-and-release tracking to the model?
9. **Min iOS version / device** — gates SwiftData and other APIs.

All infra-flavored questions feed `decisions.md`; product-flavored ones update this PRD.
