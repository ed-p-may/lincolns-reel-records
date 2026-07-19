# Reel Records — User Stories

> Derived from the PRD and the Claude Design prototype. Users: a small invite-only circle of anglers,
> each with a private logbook (admins Ed/Lincoln also approve accounts).
> Format: _As an angler, I want [capability] so that [benefit]._ Acceptance criteria are testable.
> Priority: **P0** = v1 core, **P1** = v1 if time, **P2** = post-v1.

## Epic A — Logging a catch (the core loop)

**A1 · Log a catch quickly (P0)**
_As an angler, I want to log a catch in under a minute so I don't lose the moment._
- Given the app is open, when I tap the center **+** (or dashboard **Log a Catch**), the Add Catch
  sheet opens.
- Species is pickable from chips in one tap; date defaults to **today**.
- Only **species + date** are required to save; everything else is optional.
- Saving returns me to the Log with the new catch at the top.

**A2 · Add a photo (P0)**
_As an angler, I want to attach a photo so I remember what the fish looked like._
- I can add a photo from camera or library in the Add Catch sheet.
- The photo becomes the hero image on the catch's card and detail view.
- A catch with no photo still saves and shows a clean placeholder.

**A3 · Record measurements (P0)**
_As an angler, I want to log weight and length so I can track personal bests._
- Weight (lb) and length (in) accept decimals via a numeric keypad.
- Weight displays to one decimal (e.g. "5.8 lb").
- Both are optional; a catch without them still saves.

**A4 · Record conditions & gear (P1)**
_As an angler, I want to note weather, water, lure, and rod/reel so I can spot patterns later._
- **Decided (Q7):** air temp auto-fills from **Open-Meteo** (GPS + time) when online and stays editable;
  **offline → manual** entry. **Sky condition** and **water clarity** are **structured pickers**; water
  temp is manual. Sky condition drives the weather icon.
- **Lure/bait** is chosen via the Tackle Box picker (story A7), not free text. Free-text fields remain
  for **rod & reel** and **notes**.
- All optional; conditions fetch never blocks a save.

**A5 · Record the spot (P0)**
_As an angler, I want to capture where I caught it so I can find my productive spots._
- A free-text named `location` (e.g. "Cedar Point Cove"), **plus** GPS `latitude`/`longitude` captured
  automatically when permission is granted (decided Q3).
- **Manual pin-drop / map-search fallback** when GPS is off, denied, or the catch is logged later.
- Feeds the Map (Epic D) and derived "favorite spots".

**A6 · Edit or delete a catch (P0, not in prototype)**
_As an angler, I want to fix or remove a catch so my logbook stays accurate._
- From Catch Detail I can edit any field and re-save.
- I can delete a catch with a confirmation step.
- _Note: the prototype has no edit/delete — this is a required v1 addition._

**A7 · Pick the lure from my Tackle Box (P1)**
_As an angler, I want to choose the lure/bait from my saved gear so my logs are consistent and analyzable._
- In Add Catch, the lure field is a **Tackle Box picker** (see Epic F): select a saved item, or add a
  new one **inline** without leaving the form.
- A one-off can still be entered as **free text** (`lureText`) when it's not worth cataloging.
- The selected item shows on the catch card and Catch Detail; tapping it opens its Tackle Box entry.

## Epic B — Browsing & finding catches

**B1 · Browse the logbook (P0)**
_As an angler, I want to scroll all my catches so I can relive them._
- The Log lists every catch as a rich card (photo, weight/length, species, spot, date, lure, weather).
- Header shows the total count.

**B2 · Search (P0)**
_As an angler, I want to search so I can find a specific catch fast._
- Search matches across species, spot, lure, and notes.
- Results update as I type.

**B3 · Filter by species (P0)**
_As an angler, I want to filter by species so I can see just the bass, etc._
- Species chips (All + one per logged species) filter the list.
- Active chip is visually distinct.

**B4 · Sort (P0)**
_As an angler, I want to sort by recent/heaviest/longest so I can rank my catches._
- Sort toggles: Recent (default), Heaviest, Longest.
- Combines with active search + species filter.

**B5 · View catch detail (P0)**
_As an angler, I want a full detail view so I can see the whole story of a catch._
- Tapping any catch opens Detail: hero photo, weight + length, conditions & gear grid, field notes,
  and a "where it happened" mini-map.
- Back returns me to where I came from (Log, Dashboard, or Map).

**B6 · Bookmark / share a catch (P1)**
_As an angler, I want to save favorites and share a catch image so I can show a friend._
- Bookmark toggles a saved flag (`bookmarked`) on the catch.
- Bookmarked catches are retrievable via the Log's **Saved filter** (PRD §6.3).
- **Decided (Q6):** Share renders the catch to a **composed image** (photo + species + weight/length +
  spot/date) and hands it to the iOS **share sheet** — a personal picture, **not** a social post.

## Epic C — Dashboard & insight

**C1 · See my logbook at a glance (P0)**
_As an angler, I want a dashboard so I can see my totals and jump to logging._
- Shows greeting + date, total catches, a weekly trend, and a prominent Log a Catch button.

**C2 · See highlight stats (P0)**
_As an angler, I want key stats so I feel my progress._
- Tiles: biggest catch (weight + species), top species (+count), favorite spot (+count), species count.
- All derived from stored catches; no manual entry.

**C3 · Recent catches & favorite spots (P0)**
_As an angler, I want quick access to recent catches and top spots from the dashboard._
- Recent catches carousel → Catch Detail.
- Favorite spots list (name, count, best fish) → Map.

**C4 · Profile & breakdown (P1)**
_As an angler, I want a profile with a species breakdown so I can see my variety._
- Profile shows avatar, name/@handle, "angler since", stat row (total / personal best / species).
- Signature species highlight + species breakdown bars.

## Epic D — Map

**D1 · See catches on a map (P0)**
_As an angler, I want my catches on a map so I can see where I fish._
- All catches render as pins **at their real GPS locations** on a dark-styled **MapKit** map (Q3).
- Selecting a pin highlights it and shows a catch card → Catch Detail.
- Header shows catch + spot counts.

**D2 · Jump from a catch to its spot (P1)**
_As an angler, I want to go from a catch to its place on the map._
- Catch Detail's mini-map opens the Map focused on that catch's pin.

## Epic E — Account, data & settings

**E1 · Get into the app (P0)**
_As an angler, I want an account so my logbook is mine and follows me._
- Welcome → Create Account (username + email + password) or Log In.
- New accounts land in a **"pending approval"** state; an **email notifies** the admin (Ed/Lincoln).
- Once **approved**, the user can log in and use the app. Real accounts via Supabase Auth (decided Q1).

**E1b · Approve new users (P0, admin)**
_As an admin, I want to approve or decline new signups so only invited people get in._
- Admin receives an email on each signup and can set a user's `approved` flag to true.
- **Decline** = the account stays un-approved (admin may later delete it); no separate "rejected" state.
- Un-approved-but-authenticated users see the **pending** screen and cannot access any data (enforced by
  RLS, not just UI).
- _How_ the admin flips the flag (in-app screen vs. email link vs. Supabase Studio) — see decisions.md.

**E2 · Keep my data safe (P0)**
_As an angler, I never want to lose my catches._
- Catches persist to the **Supabase** backend (decided Q2) and to a local cache for offline use.
- Data is recoverable on a new device by logging back in.

**E3 · Set preferences (P1)**
_As an angler, I want to control my preferences._
- Units row shows lb·in (imperial-only in v1; metric deferred — Q5).
- Notifications entry (scope TBD — likely opt-in reminders; not a v1 blocker).

**E4 · Export my logbook (P2 — deferred)**
_As an angler, I want to export my whole logbook so I have a keepsake._
- Full-logbook export (PDF journal / CSV) is **deferred post-v1** (Q6). Backup is already covered by the
  Supabase backend. Profile's "Export logbook" row shows "coming soon" in v1. Per-catch sharing ships
  now via B6.

**E5 · Work offline (P0)**
_As an angler, I want to log on the water without signal._
- All logging, browsing, and viewing work fully offline — including **adding/editing Tackle Box items**
  and queuing **photo uploads** (they sync when back online).
- Weather auto-fill and sync degrade gracefully offline (manual entry; sync when back online).

**E6 · Edit my profile (P1)**
_As an angler, I want to set my name, photo, home water, and angler-since so my Profile feels like mine._
- An **Edit Profile** screen sets `displayName`, `homeWater`, `avatar`, and `anglerSince`.
- Signup collects only username + email + password; these are added afterward (empty is fine — screens
  fall back to `username`).

## Epic F — Tackle Box (structured lures & bait)

**F1 · Build my Tackle Box (P1)**
_As an angler, I want to catalog my lures & bait so I can reuse them and keep clean records._
- I can add an item with **name, type, size, color, optional brand, and a photo**.
- Type is a **structured picker** (Soft Plastic, Crankbait, Spinnerbait, Jig, Topwater, Spoon, Fly,
  Live Bait, Other).
- Items are private to me (RLS-scoped).

**F2 · Browse & find tackle (P1)**
_As an angler, I want to search and filter my Tackle Box so I can grab the right lure fast._
- Catalog grid shows photo, type, color swatch, name, size · brand.
- **Search** by name; **filter** by type.

**F3 · Edit / retire an item (P1)**
_As an angler, I want to fix or retire tackle without losing history._
- I can edit any field.
- I can **archive** an item (hidden from pickers) without deleting catches that reference it.

**F4 · See what's working (P2)**
_As an angler, I want to see how productive each lure is so I fish smarter._
- Each item shows a **catch count**; later, best species/size landed on it.

_(Selecting a Tackle Box item while logging is story **A7**, in Epic A.)_

## Not in scope (v1)

Followers / public feed / likes / comments; **any visibility or sharing between users** (multi-user
accounts exist, but each logbook is private); AI / catch-photo species recognition; regulations or
license tracking; full-logbook PDF/CSV export; metric units; a first-class Spot entity. (See PRD §4.)
