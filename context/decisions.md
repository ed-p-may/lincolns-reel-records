# Reel Records — Decision Log (ADR-style)

Running record of consequential technical/product decisions. Add a dated entry when a decision is
made; keep the "Open" list current. Newest entries at the top.

## Open decisions

- **On-device persistence + offline strategy** — backend is Supabase (decided), but how the iOS client
  caches locally for offline logging (PRD E5) is open: e.g. **SwiftData/Core Data local store synced to
  Supabase**, vs. a lighter **write-through + outbox queue**. Drivers: offline-first, min iOS version.
- **Transactional email provider** for the signup→approval notice (Resend / Postmark / Supabase SMTP).
- **App architecture pattern** — _undecided_ (e.g. plain SwiftUI + Observation, MVVM).

## Decisions made

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
  - New table `tackle_items`; derived **catch count** per item; `archived` flag to retire gear without
    breaking historical catches.
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
- **Context:** Q1 requires a hosted backend (accounts, per-user `approved` flag, photo storage, signup
  emails, data shared across a few users). Ed already has a Supabase account.
- **Decision:** Use **Supabase** — reuse Ed's existing account, add a project/section for this app.
  - **Postgres** for relational data (users, catches, spots).
  - **Supabase Auth** for email/password login.
  - **Supabase Storage** for catch photos.
  - **Row-Level Security** so each angler sees their own catches; admins can approve users.
  - **Edge Function / DB webhook** to send the signup→admin approval email.
- **Alternatives considered:** Firebase (NoSQL, less natural for relational catches; Google lock-in);
  CloudKit (poor fit for multi-user + custom approval); custom server (overkill).
- **Consequences / follow-ups:**
  - Pick a transactional email provider for the approval notice (e.g. Resend/Postmark) — sub-decision.
  - **Offline strategy** still open: catches must be loggable offline (PRD E5, P0). Likely a local
    cache on device that syncs to Supabase when online. Depth TBD with the persistence choice — see
    Open decisions.
  - iOS client talks to Supabase via the `supabase-swift` SDK.

## 2026-07-19 — Real accounts with manual approval (Auth model, PRD Q1)
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
  - Two access gates: **TestFlight invite** (who can install) + **in-app account approval** (who can
    log in). Both retained intentionally.
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
