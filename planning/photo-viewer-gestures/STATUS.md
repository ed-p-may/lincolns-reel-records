# Photo viewer gestures

Sources: [Pinch zoom (#9)](https://github.com/ed-p-may/lincolns-reel-records/issues/9)
and [Photo scroll stutter (#10)](https://github.com/ed-p-may/lincolns-reel-records/issues/10).

Both the Log gallery and Catch Detail use the same full-screen viewer. A normal
short swipe should commit one page, a cancelled swipe should leave the current
caption intact, and opening a specific photo should preserve its position.
Pinch and double-tap should zoom a loaded photo, and a drag should pan when
zoomed in. Returning to fit should restore paging. Missing files keep their
placeholder. Catch records and photo files require no migration.

Verification: run the gallery simulator flows, including a short swipe and a
pinch on a seeded image, followed by the repository gate and independent PR review.

## Current state

Implemented locally from `main` at `7c1e436`. The local stage is `codex/photo-viewer-gestures`
and the combined candidate is `codex/issues-9-14-integration`.

The full-screen gallery test passed on iPhone 17 Pro with iOS 26.5. It checked both entry points, pinch zoom, panning and a short paging swipe.

SwiftFormat, SwiftLint and the Git diff check passed. Independent review of the integrated
candidate found no actionable defects. The Docker-backed database gate passed on November 22, 2026
on the integrated checkout, with 99 tests across eight files. This stage has the same database tree.
GitHub review publication and merge are pending.
