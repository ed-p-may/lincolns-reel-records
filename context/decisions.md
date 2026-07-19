# Reel Records — Decision Log (ADR-style)

Running record of consequential technical/product decisions. Add a dated entry when a decision is
made; keep the "Open" list current. Newest entries at the top.

## Open decisions

- **Database / persistence layer** — _undecided._ To discuss. Candidates and rough tradeoffs:
  - **SwiftData** — modern, SwiftUI-native, least boilerplate; iOS 17+ only, still maturing.
  - **Core Data** — mature, powerful, CloudKit sync built in; more boilerplate.
  - **GRDB (SQLite)** — full SQL control, fast, testable; manual sync, more setup.
  - **Realm** — easy object store with sync option; third-party, future uncertain.
  - **Cloud backend** (CloudKit / Supabase / Firebase) — only if sync/backup/sharing is required.
  - Decision drivers: offline-first (likely required), single-user vs. sync, min iOS version, backup needs.
- **Minimum iOS deployment target** — _undecided_ (gates SwiftData and other newer APIs).
- **App architecture pattern** — _undecided_ (e.g. plain SwiftUI + observation, MVVM).
- **Cloud sync / backup** — _undecided_ (personal use; may be device-only initially).

## Decisions made

_(none yet)_

### Template

```
## YYYY-MM-DD — <decision title>
- **Context:** why this came up.
- **Decision:** what we chose.
- **Alternatives considered:** ...
- **Consequences:** tradeoffs, follow-ups.
```
