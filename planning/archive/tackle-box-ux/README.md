---
DATE: 2026-11-23
STATUS: Complete
AUTHOR: Antigravity
ISSUE: https://github.com/ed-p-may/lincolns-reel-records/issues/11
---

# Tackle Box UX

**Source:** [GitHub Issue #11](https://github.com/ed-p-may/lincolns-reel-records/issues/11)
**Status:** Complete — see [STATUS.md](STATUS.md) for shipped PRs and verification evidence.
**Canonical context affected:** `context/PRD.md` (§6.5 Add / Edit Catch, §6.8 Tackle Box), `context/user-stories.md` (Story A7, Epic F), `context/decisions.md`

## Scope

Improve how anglers pick a lure or bait from their Tackle Box when logging a catch:

1. **Recently Used strip on Log a Catch:** Derive the angler's last 5 distinct selectable tackle items from their visible catch history and show those first under **Lure / Bait** instead of scrolling through the entire catalog inline.
2. **Full-screen Tackle Gallery Picker:** Add a one-tap option from Log a Catch to open a full-screen tile gallery for selecting a tackle item, with **Recently Used** first followed by sections grouped by `TackleItemType` (`Soft Plastic`, `Crankbait`, `Spinnerbait`, `Jig`, `Topwater`, `Spoon`, `Fly`, `Live Bait`, `Other`).
3. **Catalog parity (Phase 02):** Apply the same type-grouped sections to the standalone `TackleBoxView` catalog (`You → My Tackle Box`) when viewing all types, and match search across `name`, `brand`, and `color` in both screens.

No SwiftData schema changes, Supabase migrations, RLS changes, sync protocol changes, or third-party dependencies are required.

## Read order

1. [STATUS.md](STATUS.md) — current state, phase inventory, resolved decisions, and next step.
2. [PRD.md](PRD.md) — behavior contract, recency derivation rules, UX anatomy, edge cases, and acceptance criteria.
3. Phase plans under `plans/`:
   - [Phase 01 — Recently-used strip and full-screen gallery picker](plans/phase-01-recent-strip-and-gallery-picker.md) *(core Issue #11 scope)*
   - [Phase 02 — Type-grouped sections in Tackle Box catalog](plans/phase-02-catalog-type-sections.md) *(included parity pass)*
