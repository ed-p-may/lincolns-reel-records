# Beta Acceptance Matrix — `0.1.0 (5)`

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
| Swift formatting/lint/unit/UI suite | PASS | Build-5 `make ci` on 2026-07-20: 0 formatting/lint violations across 75 Swift files; 85/85 unit tests and 16/16 UI tests pass on iPhone 17 Pro / iOS 26.5. |
| Local Postgres migrations and pgTAP | PASS | Final `make ci`: local reset applied all 8 migrations; 8 pgTAP files / 99 assertions pass. Full local API stack remains separately blocked. |
| Privacy manifest plist and app-bundle placement | PASS | `plutil -lint`; Beta build copied an identical manifest to the app root on 2026-07-19. |
| Archive configuration / secret scan | PASS | Development-signed build `0.1.0 (5)` archive validates with deployment target 18.0, expected bundle ID and recovery scheme, app/dependency privacy manifests, and no privileged-key bundle scan hits. |
| Small/large Simulator layouts and Dynamic Type | PASS | iPhone 17e: 14/14 UI; iPhone 17 Pro Max: 2/2 largest-text tests on iOS 26.5. |
| Automated accessibility audit | PASS | `BetaHardeningUITests` audits Dashboard, Log, and Profile on iPhone 17 Pro / iOS 26.5. Actionable contrast, label, touch-target, and clipping findings were fixed; dedicated largest-text tests cover Dynamic Type, while the audit narrowly excludes native tab-bar occlusion and single-line text-field clipping artifacts. |
| VoiceOver reading/order and control labels | BLOCKED | Automated audit is partial evidence; complete manual review on the physical release candidate. |
| Contrast, Reduce Motion, keyboard, and touch targets | BLOCKED | Automated audit plus physical/manual inspection on the signed release candidate. |
| Icon, launch presentation, and placeholder audit | PASS | 1024 × 1024 PNG app icon, launch color asset, built primary Simulator surfaces, and source placeholder grep inspected 2026-07-20; only Notifications and Export Logbook retain approved Coming Soon labels. |
| Launch/Log/image/Map/sync performance and energy | BLOCKED | Profile the signed release candidate on physical hardware; Simulator timings are not acceptance. |
| iOS 18 deployment floor | PASS | Build 4 installed and passed the primary physical suite on the registered iPhone running iOS 18.6 on 2026-07-20. |
| Debug/backend isolation | BLOCKED | Debug still targets hosted beta; create/start a local or separate dev backend before destructive app development. |

## Hosted, signed, and physical release gate

| Gate | Status | Required evidence |
|---|---|---|
| Hosted migrations 02–10 | PASS | Pre-change logical backup captured; Phase 01 ledger mismatch reconciled after exact schema comparison; all 8 Git timestamps match hosted on 2026-07-20. |
| Hosted two-user table/Storage isolation | PASS | Two disposable users passed 17 table, object, JWT, and cleanup checks across all 4 tables and 3 private buckets; counts returned to baseline. |
| Hosted `delete-account` Function | PASS | Active JWT-verified Function deployed; disposable physical account deletion removed Auth, rows, cached data, and objects with no orphans. |
| Password-reset email/deep link | PASS | Ed's receivable account completed the real build-5 reset request, email link, app deep link, and new-password flow on the physical iPhone on 2026-07-20. |
| Privacy policy and App Store privacy answers | BLOCKED | Publish/confirm policy URL and reconcile answers with `privacy-inventory.md`. |
| Signed internal RC `0.1.0 (5)` | PASS | Xcode archive validation and the six-category/no-tracking privacy report passed; App Store Connect processed build 5; Ed installed the Apple-hosted internal build on the physical iPhone and confirmed existing Home, Log/photos, Profile, Tackle Box, and Map data. |
| Upgrade from `0.1.0 (3)` | PASS | Physical build-3 → build-4 and build-4 → build-5 upgrades preserved the existing Catches, Profile, and Tackle Box data; build 5 also retained data through password recovery. |
| Clean physical install/fresh restore | PASS | Build 4 uninstall/reinstall recovered 8 Catches/photos, exact Walleye map/conditions/bookmark, Tackle item/photo, Profile, and avatar from hosted state. |
| Physical permissions/camera/photos/GPS/weather | PASS | Camera, Photos none/limited, Location never/while-using, Settings recovery, manual fallback, live GPS/Open-Meteo, and exact hosted conditions passed on iOS 18.6. |
| Physical offline/reconnect | PASS | Airplane-mode Catch/photo/manual map/conditions, relaunch, unchanged hosted state while offline, reconnect upload, Tackle ordering, Profile/avatar, and bookmark sync passed. |
| Physical low-storage/time-zone boundary | NOT RUN | Both runnable failure/derived-date scenarios still need final-RC evidence. |
| Physical share destinations and cleanup | NOT RUN | Save Image and cancellation pass; Messages/Mail, representative sparse/complete cards, and final temporary-file inspection remain. |
| External App Review and invite-only group | BLOCKED | Verified build 5 is assigned to the email-only `Reel Records Friends & Family` group and is `Waiting for Review` as of 2026-07-20; Apple approval/availability remains. Superseded build 3 is no longer under review or assigned externally. |

Phase 11 cannot close while any row in the second table is blocked.
