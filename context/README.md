# context/

Source-of-truth guideline docs for **Reel Records**. Written and agreed **before** code.
Read the relevant doc before building a feature; keep docs current as decisions change.

| File | Purpose |
|------|---------|
| `PRD.md` | Product requirements — what the app does and why. |
| `user-stories.md` | User stories + acceptance criteria driving each feature. |
| `design-system.md` | Design tokens + component specs (color, type, motion) from the prototype. |
| `decisions.md` | ADR-style log of tech/product decisions, plus a short "Open decisions" list. |

`PRD.md`, `user-stories.md`, and `design-system.md` are populated from the Claude Design prototype and
the design decisions. All 9 open PRD questions are **resolved** in `decisions.md`; only implementation-
time details remain open there (offline-sync strategy, email provider, app architecture pattern).
Static UI mockups live in `../mockups/`.
