---
DATE: 2026-11-22
STATUS: Scoped
AUTHOR: Antigravity
ISSUE: https://github.com/ed-p-may/lincolns-reel-records/issues/14
---

# Water-Body Fishing Info — Research Findings

This document answers the research task in [Issue #14](https://github.com/ed-p-may/lincolns-reel-records/issues/14):
how to identify a tapped body of water on iOS 18 MapKit, which public data sources can reliably
supply species, hot-spots, lures, blogs, and photos, and what architecture fits Reel Records'
offline-first, private-logbook constraints.

---

## 1. Selecting a body of water on iOS 18 MapKit

### Current Map tab constraints (`ReelRecords/Location/CatchMapView.swift`)
- `CatchMapView` currently binds `Map(position: $cameraPosition, selection: $selectedCatchID)` where
  `selectedCatchID: UUID?`. That allows selecting custom catch `Marker`s only.
- `.mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))` hides
  Apple Maps POIs.
- When `pinnedCatches.isEmpty`, the view renders a full-screen `ContentUnavailableView` instead of
  the map, preventing an angler from scouting waters before logging pinned catches.

### Recommended interaction model (iOS 18 native + fallback)
Because Reel Records already sets its minimum deployment target to **iOS 18**, SwiftUI's
`MapSelection<SelectionValue>` solves the catch-pin vs. map-feature conflict cleanly:

1. **Primary path — `MapSelection<UUID>`:**
   - Replace `@State private var selectedCatchID: UUID?` with
     `@State private var mapSelection: MapSelection<UUID>?`.
   - Tag catch markers with `.tag(MapSelection(catchItem.id))`.
   - When the user taps a catch marker, `mapSelection.value` is populated (existing selected-catch
     card behavior is unchanged).
   - When the user taps a built-in Apple Maps vector feature (lakes, ponds, rivers, bays),
     `mapSelection.mapFeature` is populated with `title`, `coordinate`, and `kind`.
   - Filter to `feature.kind == .physicalFeature` (and verify water-body relevance; `.physicalFeature`
     also includes mountains/valleys, so non-water physical features must not show a fishing card).

2. **Fallback path — `MapReader` coordinate tap + OpenStreetMap Overpass:**
   - **Known MapKit limitation:** Apple Maps does not expose every small pond or unnamed cove as a
     tappable `MapFeature`, and tapping open water away from a lake's label may not trigger
     `MapFeature` selection.
   - Wrap `Map` in `MapReader` so a deliberate water-inspection gesture (e.g. long-press on water or
     tapping an "Inspect area" action when no `MapFeature` is selected) converts the screen point to
     `CLLocationCoordinate2D` and queries OpenStreetMap's Overpass API (`is_in` + `around:100` for
     `natural=water`, `waterway~"river|stream"`, `landuse=reservoir` with `name=*`).
   - **Why not resolve every plain tap via Overpass?** Plain taps on dry land or during panning would
     cause noisy lookups and rate-limit public Overpass endpoints. Keeping `MapFeature` for single
     taps on labeled waters and long-press (or search) for unlabeled/small waters avoids accidental
     triggers.
   - **Physical-device validation required in Phase 01:** Test Apple Maps `MapFeature` tap coverage
     on real Berkshire waters (Stockbridge Bowl, Lake Mansfield, Housatonic River, Lake Buel, Goose
     Pond, and a small local pond) to confirm how often the fallback is needed.

---

## 2. Public data source evaluation

No single public API provides all of: water identity, fish species, hot-spots, best lures, blogs,
and photos. A **layered pipeline** combines free structured APIs with cached web-grounded synthesis.

### Source matrix

| Source | Data provided | Coverage | Auth / Cost | Strengths & caveats |
|---|---|---|---|---|
| **Local SwiftData logbook** | Angler's own catch count, species caught, personal best, top lures at that water | Anywhere the angler has fished | Free, offline | Instant, 100% private. Match by normalized spot name or coordinate proximity (~1 km). |
| **OpenStreetMap (Overpass / Nominatim)** | Canonical water ID (`osm_type/osm_id`), official name, water type (lake/pond/river), `wikipedia`/`wikidata` tag, nearby boat ramps (`leisure=slipway`), parking | Global (strong in US/Northeast) | Free, no key | Public Overpass instances enforce fair-use rate limits. Query server-side from Supabase Edge Function with caching and a descriptive `User-Agent`. |
| **Wikipedia & Wikimedia Commons REST API** | Lake/river summary, basic geography (acreage, max depth when listed), CC-licensed hero photo, article URL | Major & medium waters (e.g. Stockbridge Bowl, Housatonic River); sparse for small ponds | Free, no key | Clean JSON via `/api/rest_v1/page/summary/{title}`. Reliable and fast. |
| **iNaturalist API (`api.inaturalist.org/v1/observations`)** | Geo-tagged ray-finned fish observations (`taxon_id=47178`, Actinopterygii) within radius: species list, observation counts, and **real CC-licensed photos** | US-wide; strong near popular waters, sparse on remote ponds | Free, no key | Rate-limited (~1 req/sec). Must display photographer attribution and license per CC terms. Great legal source of real local fish photos. |
| **USGS Water Services (NWIS IV)** | Live stream discharge (cfs), gauge height (ft), and occasionally water temperature (°F) via `waterservices.usgs.gov/nwis/iv/?bBox=...&parameterCd=00060,00065,00010` | US rivers and streams with active gauges (e.g. Housatonic River at Great Barrington) | Free, no key | Rivers/streams only; returns empty for ponds/lakes. High value for river anglers; fetch fresh (or 15-min cache). |
| **State Fisheries GIS (e.g. MassWildlife / MassGIS ArcGIS REST)** | Trout-stocked waterbodies, stocking dates & species, Coldwater Fisheries Resources (CFR), Office of Fishing & Boating Access (OFBA) ramps, links to official pond depth maps | State-by-state (MA directly covers Lincoln's home waters; NY DEC / CT DEEP have separate portals) | Free, no key | Authoritative, but every state has a different ArcGIS schema. Best built as optional regional adapters (Phase 03), starting with MA. |
| **Web-Grounded Fishing Intel (Search-grounded LLM via Supabase Edge Function)** | Local fishing blogs, forum reports, target species, hot-spots/structure, and **best lures/methods**, paired with verified clickable source URLs | Any named water body with public web mentions (blogs, Reddit, state DNR pages, local fly/bait shop reports) | Low (~$0.005–$0.03 per uncached lookup) | **Only scalable way** to extract lures, hot-spots, and blog links across arbitrary ponds. Must run server-side with strict citation-only prompting and shared Postgres caching (14-day TTL) so each lake is researched once for the invite circle. |
| **In-app Safari quick links (`SFSafariViewController`)** | One-tap curated searches (Google fishing reports, state fishing map, YouTube) | Universal | Free, zero backend | Reliable fallback whenever structured sources or web intel are sparse. |

### Ruled-out sources & approaches

- **Fishbrain, Fishidy, Navionics, OnWater scraping:** No public developer APIs; scraping violates
  Terms of Service, breaks on markup changes, and risks IP blocks. Ruled out.
- **Ungrounded LLM (no web search):** Would hallucinate species, fake coves/hot-spots, and broken
  URLs for small ponds. Unacceptable for field guidance. Ruled out.
- **Aggregating other Reel Records users' catches:** Directly violates `context/PRD.md` §4 ("no
  visibility or sharing between users; each logbook is private"). All shared water-body guides must
  contain **public third-party information only**.

---

## 3. Recommended architecture

### Two-tier enrichment behind one Supabase Edge Function (`water-body-info`)

```
iOS CatchMapView (MapSelection<UUID> + MapReader fallback)
  │
  ├── Local SwiftData (instant, offline): "Your History Here"
  │
  └── WaterBodyInfoService (protocol, fixture-testable)
        ├── Local disk/SwiftData cache (instant offline re-view of previously opened waters)
        └── Supabase Edge Function: POST /functions/v1/water-body-info (JWT-authenticated)
              │
              ├── 1. Resolve canonical water key (OSM ID or normalized name + state + grid cell)
              ├── 2. Check Postgres cache `public.water_body_guides` (TTL: 14 days)
              ├── 3. On miss, fan out in parallel (bounded timeouts):
              │     ├── OSM Overpass (water type, boat ramps, wikipedia tag)
              │     ├── Wikipedia REST (summary + hero photo)
              │     ├── iNaturalist (fish species + CC photos within radius)
              │     ├── USGS NWIS IV (live gauge if river/stream — always fresh or 15-min cache)
              │     └── [Phase 02] Web-grounded LLM (species, lures, hot-spots, cited blog/report URLs)
              │     └── [Phase 03] State adapter (MassWildlife ArcGIS for MA coords)
              └── 4. Store sanitized public JSON in `public.water_body_guides` & return to iOS
```

### Why server-side (Supabase Edge Function) instead of calling all APIs from iOS?
1. **Shared caching across the invite circle:** When Lincoln looks up Stockbridge Bowl, the cached
   public guide is reused for Ed and other invited anglers — cutting latency and keeping API costs
   near zero.
2. **Secret isolation:** Any web-search/LLM API key stays in Supabase Edge Function secrets, never
   shipped in the iOS binary (`Config/Base.xcconfig` stays publishable-only).
3. **Polite rate-limiting:** Overpass and iNaturalist rate limits are respected centrally with
   caching and timeouts instead of from individual client devices.
4. **Thin, testable iOS client:** iOS consumes one typed, versioned JSON schema behind a
   `WaterBodyInfoProviding` protocol (matching `WeatherSuggestionProviding` / `OpenMeteoClient`).

### Cost & quota estimate (Phase 02, friends & family scale)
- Assume 10–25 active anglers inspecting ~20–40 distinct water bodies per month.
- With a 14-day shared Postgres cache: ~30–60 uncached web-grounded lookups/month.
- At ~$0.01–$0.03 per search-grounded call (Gemini with Google Search grounding or OpenAI Responses
  with `web_search`): **< $2/month**.
- Guardrails: authenticate every call with Supabase JWT; enforce a per-user daily cap on uncached
  lookups (e.g. 20/day) and manual refreshes (e.g. 1/water/day) in the Edge Function.

---

## 4. Risks & mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Apple `MapFeature` doesn't cover small ponds | User taps a small pond and nothing happens | Pair `MapSelection<UUID>` with a `MapReader` long-press / "Inspect water here" fallback backed by OSM Overpass. |
| LLM fabricates lures or hot-spots for obscure ponds | Misleading advice erodes trust | Strict JSON schema requiring source URLs for every report; prompt instructs returning empty arrays when web search yields no credible water-specific results; UI shows honest sparse state + web search link. |
| Stale or wrong fishing regulations | Legal risk if angler relies on app for limits | Explicitly exclude regulations/licensing (per `PRD.md` §4); show a concise footer reminding anglers to verify state regulations. |
| Overpass / iNaturalist temporary outage | Card fails to load | Fan out with per-source timeouts (3–5s) and partial-success degradation: if one source fails, still return whatever succeeded + local history + Safari links. |
| Offline use on the water | No signal at the lake | Local history always renders immediately; previously fetched water guides stay cached on-device; uncached waters show an honest offline notice without blocking catch pins. |
