---
DATE: 2026-11-22
STATUS: Scoped
AUTHOR: Antigravity
ISSUE: https://github.com/ed-p-may/lincolns-reel-records/issues/14
---

# Water-Body Fishing Info — PRD

**Source:** [GitHub Issue #14](https://github.com/ed-p-may/lincolns-reel-records/issues/14)
**Status:** Scoped
**Owner:** Reel Records iOS app (client-only in v1; backend deferred to Phase 02)
**Affected canonical docs:** `context/PRD.md` (§6.4 Map), `context/user-stories.md` (Epic D), `context/decisions.md`

## Goal

Let an angler tap a body of water on the Catch Map and immediately see a Google Maps-style info
card with publicly available fishing guidance — fish species, hot-spots/access, recommended lures
and methods, photos, live river flow when applicable, and links to public blogs/reports — paired
with their own private catch history at that water.

## User story (new Epic D story — D3)

**D3 · Scout a body of water on the map (P1)**
_As an angler, I want to tap a lake, pond, or river on the map and see publicly available species,
lure tips, access points, and fishing reports so I can prepare for a spot before or during a trip._

## Product contract

### 1. Map selection & entry points
- **Catch pins take priority:** Tapping one of the user's catch pins continues to select that catch
  and show the existing compact `selectedCatchCard` at the bottom of the map.
- **Tap a labeled body of water:** Tapping an Apple Maps physical water feature (`MapFeature` with
  `.physicalFeature` resolved as a water body) selects that water, clears any catch-pin selection,
  and presents the Water-Body Info sheet in its compact peek detent.
- **Inspect an unlabeled or small pond:** Long-pressing on the map (or tapping an explicit
  "Inspect water" fallback when no `MapFeature` is tapped) resolves the nearest enclosing/adjacent
  named water body via coordinate lookup. If no named water body is found within the search radius,
  show a brief non-blocking inline notice ("No named body of water found here") rather than an empty
  card.
- **Map stays usable with zero pinned catches:** When the user has no pinned catches yet, the Map
  tab still displays the interactive MapKit map (centered on a sensible default/user region) with a
  compact header hint rather than blocking the screen with a full-screen empty state.

### 2. Google Maps-style card / sheet UX
Presented in Reel Records' dark-only design language (`ReelTheme`, `ReelFont`, SF Symbols) as a
bottom sheet with interactive detents (`.fraction(0.28)` peek, `.medium`, `.large`) and background
map interaction enabled in peek/medium states so the angler can keep orienting on the map.

**Peek state (collapsed card):**
- Water body name (display font) + type & region subtitle (e.g. `Lake · Stockbridge, MA`).
- Optional square thumbnail (Wikimedia Commons or iNaturalist photo when available).
- Compact metadata row:
  - "Your catches here" pill (when > 0 local catches match)
  - Top 3–4 species chips (when available)
  - Live river flow pill (e.g. `420 cfs`) when an active USGS gauge is matched on a river/stream.
- Dismiss button (`xmark.circle.fill`) and drag indicator.

**Expanded sheet sections (only render sections that have real data):**
1. **Your History Here** *(local SwiftData, instant & offline)*
   - Count of the owner's catches at this water (matched by normalized `location` name or within
     proximity of the water body's coordinates), personal best weight/length, and top lures the
     angler has logged here.
   - Never includes any other user's catches.
2. **Overview & Access**
   - Concise summary (Wikipedia or synthesized overview).
   - Public access / boat ramps (from OSM `leisure=slipway` or state access data) when found.
   - Live river conditions card (USGS gauge name, discharge in cfs, gauge height in ft, water temp
     if reported, and reading timestamp) for rivers/streams.
3. **Fish Species**
   - Chips/list of reported species with compact source indicators (e.g. iNaturalist, MassWildlife,
     Public Reports).
4. **Best Lures & Methods** *(Phase 02)*
   - Concise, scannable tips (e.g. lure types, seasonal/depth notes) strictly backed by retrieved
     public reports. Omitted when no credible reports exist.
5. **Hot-Spots & Structure** *(Phase 02)*
   - Publicly reported areas/structure notes (coves, drop-offs, dams, weed edges) backed by sources.
     Omitted when none exist.
6. **Photos & Public Reports**
   - Horizontal thumbnail strip of attributed public photos (Wikimedia Commons / iNaturalist) with
     photographer credit and license caption.
   - Clickable report/blog links (title, domain, 1–2 line summary) that open in an in-app
     `SFSafariViewController`.
7. **Explore Further (always available)**
   - One-tap in-app Safari links to search public fishing reports for `"<Water Name> <State> fishing
     report"` and state fishing agency pages.
8. **Footer**
   - Freshness timestamp ("Updated X days ago") + Refresh action (rate-limited).
   - Concise note: "Publicly sourced info — verify local fishing regulations and access rules."

### 3. Sparse, loading, error, and offline states
- **Loading:** Peek card opens immediately with the water body's name and local "Your History Here"
  section while remote public info loads in an inline skeleton/spinner state.
- **Sparse water body:** When a small pond has little or no public info, omit empty sections cleanly
  and display an honest card ("Limited public fishing info found for <Name>") alongside the user's
  own history (if any) and the "Explore Further" web search links. Never fabricate species, lures,
  or spots.
- **Partial failure:** If one upstream source times out (e.g. iNaturalist or USGS), still display
  all sources that succeeded.
- **Offline:** Show local "Your History Here" + any previously cached public guide for that water
  body (with a subtle "Saved offline" label). If uncached and offline, show a non-blocking inline
  notice ("Connect to load public fishing info") while keeping the map and catch pins functional.

### 4. Privacy, security, and data boundaries
- **No cross-user data leakage:** In v1, all lookups run directly from the iOS client against free
  public APIs with an on-device cache; no user catches, spots, or tackle are ever sent to third
  parties or shared across accounts.
- **Minimal request payload:** Public API requests send only the water body's public name and
  coordinates — never user catch data or account identifiers.
- **Zero backend changes in v1:** No Supabase migration, Edge Function, or third-party API secrets
  are required in Phase 01. (If Phase 02 web-grounded synthesis is enabled later, its shared cache
  and API keys stay strictly server-side behind Supabase JWT auth.)

## Acceptance criteria

1. Tapping a catch pin on the Map still opens the selected-catch card and navigates to Catch Detail
   with no regression.
2. Tapping a labeled lake/river `MapFeature` on the Map opens the Google Maps-style peek card for
   that water body and clears catch-pin selection.
3. Long-pressing a small pond not exposed as an Apple `MapFeature` resolves the named water body
   and opens its info card, or shows an honest "No named body of water found here" notice on dry
   land.
4. The sheet displays the owner's own local catches at that water body immediately, even offline,
   and never exposes another account's catches.
5. Public info sections (overview, boat ramps, species, attributed photos, live river flow, and
   in-app Safari report links) render cleanly when present, attribute photo sources, open links
   in-app, and omit cleanly without fabricated placeholders when a water body has sparse public
   data.
6. Repeated lookups of the same water body hit the on-device cache (and remain viewable offline).
7. Map browsing works when the user has 0 pinned catches, and offline/network failures never block
   map interaction or crash.

## Non-goals

- Official fishing regulations, size/creel limits, or license tracking (`PRD.md` §4).
- Cross-user catch sharing, community comments, or user-submitted public reports inside Reel
  Records.
- Scraping Fishbrain, Fishidy, or other paywalled/ToS-restricted fishing apps.
- Turning water bodies into a new synced user-owned `Spot` entity in the catch schema.
- Offline bundling of nationwide water-body databases inside the app binary.
