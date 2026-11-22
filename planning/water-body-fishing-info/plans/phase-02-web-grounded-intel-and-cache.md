---
DATE: 2026-11-22
STATUS: Deferred
AUTHOR: Antigravity
ISSUE: https://github.com/ed-p-may/lincolns-reel-records/issues/14
---

# Phase 02 — Web-grounded fishing intel and shared Supabase cache

**Status:** Deferred (per 2026-11-22 decision: keep v1 strictly free & client-only; revisit after Phase 01 field feedback)
**Depends on:** Phase 01 complete; future sign-off on a search-grounded LLM provider and Supabase Edge Function/cache migration

## Goal

Add the high-value public fishing guidance requested in Issue #14 — **best lures/methods,
hot-spots/structure, and clickable local blogs/fishing reports** — via a search-grounded synthesis
step in the `water-body-info` Edge Function, backed by a shared Supabase Postgres cache so each
body of water is researched once for the entire invite-only circle.

## Implementation sequence

1. **Shared Postgres cache migration (`supabase/migrations/<timestamp>_water_body_guides.sql`):**
   - Create `public.water_body_guides`:
     - `canonical_key text primary key` (e.g. `osm:way:12345` or `geo:<slug>:<state>:<lat2>:<lon2>`)
     - `name text not null`
     - `water_type text`
     - `region text`
     - `latitude double precision not null`, `longitude double precision not null`
     - `payload jsonb not null` (sanitized public structured guide — never user data)
     - `fetched_at timestamptz not null default now()`
     - `expires_at timestamptz not null`
   - Create lightweight rate-limit tracking table `public.water_body_lookup_log` (or RPC counter)
     keyed by `(owner_id, day)` to cap uncached lookups (e.g. 20/day) and manual refreshes (1/water/day).
   - **RLS policies:**
     - `water_body_guides`: `SELECT` allowed for `authenticated`; `INSERT`/`UPDATE`/`DELETE`
       restricted to `service_role` only.
     - `water_body_lookup_log`: `service_role` only.
   - Add pgTAP / database tests verifying authenticated read access, denial of client writes, and
     zero cross-user leakage.

2. **Web-grounded synthesis in `supabase/functions/water-body-info/index.ts`:**
   - Check `public.water_body_guides` first; on unexpired cache hit (and not a manual refresh),
     return cached guide + fresh USGS live gauge (if river).
   - On cache miss, run the Phase 01 structured fetchers AND a search-grounded LLM call (provider
     configured via Supabase Edge Function secret, e.g. `GEMINI_API_KEY` with Google Search
     grounding or `OPENAI_API_KEY` with `web_search`).
   - Enforce a strict structured JSON output schema:
     - `reportedSpecies`: `[{ name, confidenceNote? }]`
     - `bestLures`: `[{ lure, context, sourceIndex }]`
     - `hotSpots`: `[{ area, tip, sourceIndex }]`
     - `reports`: `[{ title, url, domain, snippet }]`
   - **Anti-hallucination rules in prompt + post-validation:**
     - Only include lures, hot-spots, and species explicitly supported by retrieved web sources for
       *that specific water body and state* (prevent same-name lake confusion, e.g. "Long Pond").
     - Post-validate that every returned `reports[].url` is a valid `https://` URL returned by the
       search grounding metadata (drop any unverified/invented URLs).
     - If no credible public fishing reports exist, return empty arrays so the UI shows the honest
       sparse state.
   - Graceful degradation: if the LLM secret is absent or the provider fails/times out, still return
     and serve Phase 01 structured sources without failing the request.

3. **iOS sheet enhancements (`ReelRecords/Location/WaterBodyInfoSheet.swift`):**
   - Render **Best Lures & Methods**, **Hot-Spots & Structure**, and **Blogs & Fishing Reports**
     cards (tapping a report opens `SFSafariViewController`).
   - Show cache freshness timestamp ("Updated X days ago") and a manual **Refresh** button in the
     footer.
   - Update on-device offline cache to store the full Phase 02 payload.

4. **Verification:**
   - Database test suite (`supabase test db` / `make ci`) covering RLS and cache table policies.
   - Unit tests for URL/schema sanitization, empty-intel sparse rendering, and cache TTL behavior.
   - UI test verifying lures, hot-spots, and report link presentation from fixture.
   - Live hosted Edge Function smoke test against 3 real test waters:
     1. Well-documented lake (`Stockbridge Bowl, MA`) — should return species, lures, reports.
     2. River with gauge (`Housatonic River, Great Barrington, MA`) — should return USGS flow + fly/lure reports.
     3. Tiny/obscure pond — should return honest sparse state with zero fabricated hot-spots.

## Touch points

- `supabase/migrations/<timestamp>_water_body_guides.sql` (new)
- `supabase/tests/water_body_guides_test.sql` (new)
- `supabase/functions/water-body-info/index.ts`
- `ReelRecords/Location/WaterBodyModels.swift`
- `ReelRecords/Location/WaterBodyInfoService.swift`
- `ReelRecords/Location/WaterBodyInfoSheet.swift`
- `ReelRecordsTests/WaterBodyInfoTests.swift`
- `ReelRecordsUITests/WaterBodyInfoUITests.swift`
- `context/decisions.md`

## Exit criteria

- Shared Postgres cache hits serve in < 300 ms without re-invoking upstream search/LLM APIs.
- Every displayed blog/report URL is verified from grounding metadata and opens cleanly in-app.
- Obscure ponds return an honest sparse state with no hallucinated lures or hot-spots.
- Database RLS tests and `make ci` pass.
