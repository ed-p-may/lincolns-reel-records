# context/

Source-of-truth guideline docs for **Reel Records**. Written and agreed **before** code.
Read the relevant doc before building a feature; keep docs current as decisions change.

| File | Purpose |
|------|---------|
| `PRD.md` | Product requirements — what the app does and why. |
| `user-stories.md` | User stories + acceptance criteria driving each feature. |
| `design-system.md` | Design tokens + component specs (color, type, motion) from the prototype. |
| `decisions.md` | ADR-style log of tech/product decisions, plus a short "Open decisions" list. |
| `implementation-plan.md` | High-level architecture, vertical-slice sequence, and shared completion gate. |
| `implementation-phases/` | Standalone implementation plans for phases 01–11. |

`PRD.md`, `user-stories.md`, and `design-system.md` are populated from the Claude Design prototype and
the design decisions. All 9 open PRD questions are **resolved** in `decisions.md`; only implementation-
time details remain open there (sync conflict/deletion/sign-out semantics and signup email confirmation).
Static UI mockups live in `../mockups/`. Implementation is planned as deployable vertical slices;
start with `implementation-plan.md`, then read the relevant file in `implementation-phases/`.
