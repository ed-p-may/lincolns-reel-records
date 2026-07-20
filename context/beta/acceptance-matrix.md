# Beta Acceptance Matrix — `0.1.0 (4)`

Status vocabulary: **PASS** has dated reproducible evidence; **BLOCKED** has an unavailable dependency
or unmet prerequisite; **NOT RUN** is runnable but has not yet passed. Simulator and local database
evidence never substitute for the consolidated hosted/physical gate.

## Phone-free evidence

| Area | Status | Evidence / remaining action |
|---|---|---|
| Phase 01 auth/local cache/outbox | PASS | [`../implementation-phases/01-tracer-bullet.md`](../implementation-phases/01-tracer-bullet.md) closeout. |
| Phase 02 Catch CRUD/offline/conflicts | PASS | [`../implementation-phases/02-catch-crud.md`](../implementation-phases/02-catch-crud.md) closeout. |
| Phase 03 Log/detail/delete | PASS | [`../implementation-phases/03-logbook-detail.md`](../implementation-phases/03-logbook-detail.md) closeout. |
| Phase 04 photos/local ordering/outbox | PASS | [`../implementation-phases/04-photos.md`](../implementation-phases/04-photos.md) closeout. |
| Phase 05 coordinates/map | PASS | [`../implementation-phases/05-location-map.md`](../implementation-phases/05-location-map.md) closeout. |
| Phase 06 conditions/Open-Meteo contract | PASS | [`../implementation-phases/06-conditions.md`](../implementation-phases/06-conditions.md) closeout. |
| Phase 07 dashboard derivations | PASS | [`../implementation-phases/07-dashboard.md`](../implementation-phases/07-dashboard.md) closeout. |
| Phase 08 Tackle Box/link ordering | PASS | [`../implementation-phases/08-tackle-box.md`](../implementation-phases/08-tackle-box.md) closeout. |
| Phase 09 profile/settings/delete contract | PASS | [`../implementation-phases/09-profile-settings.md`](../implementation-phases/09-profile-settings.md) local closeout; hosted Function remains below. |
| Phase 10 bookmarks/share renderer | PASS | [`../implementation-phases/10-bookmark-share.md`](../implementation-phases/10-bookmark-share.md) local closeout; destinations remain below. |
| Swift formatting/lint/unit/UI suite | PASS | Final `make ci` on 2026-07-20: 0 formatting/lint violations across 75 Swift files; 82/82 unit tests and 15/15 UI tests pass on iPhone 17 Pro / iOS 26.5. |
| Local Postgres migrations and pgTAP | PASS | Final `make ci`: local reset applied all 8 migrations; 8 pgTAP files / 99 assertions pass. Full local API stack remains separately blocked. |
| Privacy manifest plist and app-bundle placement | PASS | `plutil -lint`; Beta build copied an identical manifest to the app root on 2026-07-19. |
| Archive configuration / secret scan | PASS | Unsigned Beta Simulator build `0.1.0 (4)`, deployment target 18.0; tracked/bundle privileged-key scan clean. |
| Small/large Simulator layouts and Dynamic Type | PASS | iPhone 17e: 14/14 UI; iPhone 17 Pro Max: 2/2 largest-text tests on iOS 26.5. |
| Automated accessibility audit | PASS | `BetaHardeningUITests` audits Dashboard, Log, and Profile on iPhone 17 Pro / iOS 26.5. Actionable contrast, label, touch-target, and clipping findings were fixed; dedicated largest-text tests cover Dynamic Type, while the audit narrowly excludes native tab-bar occlusion and single-line text-field clipping artifacts. |
| VoiceOver reading/order and control labels | BLOCKED | Automated audit is partial evidence; complete manual review on the physical release candidate. |
| Contrast, Reduce Motion, keyboard, and touch targets | BLOCKED | Automated audit plus physical/manual inspection on the signed release candidate. |
| Icon, launch presentation, and placeholder audit | PASS | 1024 × 1024 PNG app icon, launch color asset, built primary Simulator surfaces, and source placeholder grep inspected 2026-07-20; only Notifications and Export Logbook retain approved Coming Soon labels. |
| Launch/Log/image/Map/sync performance and energy | BLOCKED | Profile the signed release candidate on physical hardware; Simulator timings are not acceptance. |
| iOS 18 deployment floor | BLOCKED | No iOS 18 Simulator runtime is installed; exercise the registered iOS 18.6 iPhone. |
| Debug/backend isolation | BLOCKED | Debug still targets hosted beta; create/start a local or separate dev backend before destructive app development. |

## Hosted, signed, and physical release gate

| Gate | Status | Required evidence |
|---|---|---|
| Hosted migrations 02–10 | BLOCKED | Apply in order to `ptoqkqisgyzypfpjvmvx`; compare migration ledger. |
| Hosted two-user table/Storage isolation | BLOCKED | Authenticated cross-user CRUD/object probes for every table and private bucket. |
| Hosted `delete-account` Function | BLOCKED | Deploy, verify authenticated deletion and object cleanup, retain invocation evidence. |
| Password-reset email/deep link | BLOCKED | Configure a receivable tester account and prove reset completion. |
| Privacy policy and App Store privacy answers | BLOCKED | Publish/confirm policy URL and reconcile answers with `privacy-inventory.md`. |
| Signed internal RC `0.1.0 (4)` | BLOCKED | Archive with normal signing, generate privacy report, upload, process, install internally. |
| Upgrade from `0.1.0 (3)` | BLOCKED | Physical-device upgrade preserves local/offline data and completes migration/sync. |
| Clean physical install/fresh restore | BLOCKED | Recover hosted account, Catches, photos, tackle, profile, bookmarks, and stable ordering. |
| Physical permissions/camera/photos/GPS/weather | BLOCKED | Run every scenario in the Phase 11 consolidated gate. |
| Physical offline/reconnect/low-storage/time-zone | BLOCKED | Run every scenario in the Phase 11 consolidated gate without silent data loss. |
| Physical share destinations and cleanup | BLOCKED | Messages, Mail, Save Image/equivalent, cancellation, sparse/complete records. |
| External App Review and invite-only group | BLOCKED | Internal acceptance first; then submit/add approved build to the named email-only group. |

Phase 11 cannot close while any row in the second table is blocked.
