# Reel Records — User Stories

> Derived from the PRD and the Claude Design prototype. One user: **Lincoln** (the angler).
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
- Free-text fields remain for **lure/bait, rod & reel, notes**.
- All optional; conditions fetch never blocks a save.

**A5 · Record the spot (P0)**
_As an angler, I want to name where I caught it so I can find my productive spots._
- Location is a free-text named spot (e.g. "Cedar Point Cove").
- _(P1)_ Optionally capture GPS coordinates for the map — see Epic D.

**A6 · Edit or delete a catch (P0, not in prototype)**
_As an angler, I want to fix or remove a catch so my logbook stays accurate._
- From Catch Detail I can edit any field and re-save.
- I can delete a catch with a confirmation step.
- _Note: the prototype has no edit/delete — this is a required v1 addition._

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
- Bookmark toggles a saved flag on the catch.
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
- All catches render as pins; header shows catch + spot counts.
- Selecting a pin highlights it and shows a catch card → Catch Detail.
- _v1 decision (PRD §6.4 / decisions.md): stylized abstract map vs. real MapKit + GPS._

**D2 · Jump from a catch to its spot (P1)**
_As an angler, I want to go from a catch to its place on the map._
- Catch Detail's mini-map opens the Map focused on that catch's pin.

## Epic E — Account, data & settings

**E1 · Get into the app (P0)**
_As an angler, I want to open my logbook without friction._
- Welcome → Get Started leads into the app.
- Auth model TBD (real account vs. local/passcode — PRD §9 / decisions.md). Acceptance criteria
  finalize once decided.

**E2 · Keep my data safe (P0)**
_As an angler, I never want to lose my catches._
- Catches persist locally across app restarts.
- _(P1)_ Backup/sync so a lost phone doesn't mean a lost logbook (iCloud/CloudKit — decisions.md).

**E3 · Set preferences (P1)**
_As an angler, I want to control units and notifications._
- Units setting (lb·in; metric toggle TBD).
- Notifications entry (scope TBD).

**E4 · Export my logbook (P2 — deferred)**
_As an angler, I want to export my whole logbook so I have a keepsake._
- Full-logbook export (PDF journal / CSV) is **deferred post-v1** (Q6). Backup is already covered by the
  Supabase backend. Profile's "Export logbook" row shows "coming soon" in v1. Per-catch sharing ships
  now via B6.

**E5 · Work offline (P0)**
_As an angler, I want to log on the water without signal._
- All logging, browsing, and viewing work fully offline.
- Any sync/weather features degrade gracefully when offline.

## Not in scope (v1)

Followers / public feed / likes / comments; multi-user; AI species ID; live weather API; regulations
or license tracking. (See PRD §4.)
