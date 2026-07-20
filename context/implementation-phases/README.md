# Reel Records — Implementation Phase Plans

These plans implement [`../implementation-plan.md`](../implementation-plan.md) as deployable vertical
slices. Read the high-level plan and the relevant product/design documents before starting a phase.

| Phase | Plan | Status |
|---|---|---|
| 01 | [`01-tracer-bullet.md`](01-tracer-bullet.md) | Complete |
| 02 | [`02-catch-crud.md`](02-catch-crud.md) | Complete |
| 03 | [`03-logbook-detail.md`](03-logbook-detail.md) | Complete |
| 04 | [`04-photos.md`](04-photos.md) | Complete |
| 05 | [`05-location-map.md`](05-location-map.md) | Complete |
| 06 | [`06-conditions.md`](06-conditions.md) | Ready |
| 07 | [`07-dashboard.md`](07-dashboard.md) | Planned |
| 08 | [`08-tackle-box.md`](08-tackle-box.md) | Planned |
| 09 | [`09-profile-settings.md`](09-profile-settings.md) | Planned |
| 10 | [`10-bookmark-share.md`](10-bookmark-share.md) | Planned |
| 11 | [`11-beta-hardening.md`](11-beta-hardening.md) | Planned |

## Status vocabulary

- **Planned** — scope drafted; implementation not started.
- **Ready** — dependencies and open decisions resolved; implementation may begin.
- **In progress** — backend or application work has started.
- **Verification** — implementation complete; phase gates are being tested.
- **Complete** — all acceptance and deployment gates have evidence.
- **Blocked** — an explicit dependency or decision prevents meaningful progress.

Each plan is a scope boundary. Work discovered outside that boundary is recorded as a follow-up unless
it is required to satisfy the phase's acceptance criteria safely.
