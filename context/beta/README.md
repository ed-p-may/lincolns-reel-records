# Beta Operations Packet

Release preparation for Reel Records `0.1.0 (6)`, preserving the completed build-5 baseline evidence.
This packet is operational evidence, not approval to distribute the build. Build 6 packages the merged
Issues #1–3 without a backend or privacy-contract change. Its signed archive passed CI and validation,
processed in App Store Connect, and is assigned to the internal group. External distribution remains
held until the physical-device smoke test and remaining privacy/Apple gates pass.

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
