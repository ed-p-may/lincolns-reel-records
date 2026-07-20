# Beta Operations Packet

Release verification for Reel Records `0.1.0 (5)`. This packet is operational evidence, not approval to
distribute the build. The hosted baseline and primary build-4 physical scenarios pass; Phase 11 stays
open until build 5 completes recovery/accessibility/performance/privacy checks, signed TestFlight upload,
and Apple review gates in
`../implementation-phases/11-beta-hardening.md` pass.

| File | Purpose |
|---|---|
| `acceptance-matrix.md` | Traceable pass, blocked, and not-run release criteria. |
| `privacy-inventory.md` | Privacy-manifest and App Store Connect disclosure source. |
| `release-checklist.md` | Repeatable hosted migration, archive, TestFlight, and rollback procedure. |
| `tester-script.md` | Bounded friends-and-family test script and What to Test copy. |
| `known-limitations.md` | Approved beta limitations and release blockers that must not be mislabeled. |

Release owner: Ed May. Repository/technical triage: Ed May with Codex-assisted evidence capture.
Feedback intake is TestFlight feedback; a monitored fallback email must be confirmed in App Store
Connect before external distribution.
