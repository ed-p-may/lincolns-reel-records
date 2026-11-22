# Custom Species Chips

**Source:** [GitHub Issue #13](https://github.com/ed-p-may/lincolns-reel-records/issues/13)
**Status:** Implemented on branch
**Owner:** Reel Records iOS app

## Goal

A species the angler types into "Other species" on Log a Catch becomes a one-tap species chip on later
catches, so a regular catch outside the eight seed species never has to be retyped.

## Resolved product contract

- Add Catch species chips are the eight seed species in their fixed order, followed by every other
  species the owner has logged, alphabetically.
- Logged species are the distinct text values on the owner's visible (non-deleted) catches, compared
  case-, diacritic- and width-insensitively, the same rule the Log species filter uses. A logged value
  that matches a seed species adds no chip.
- The list is derived, not stored. There is no species catalog, schema, migration, sync or backend
  change. A custom chip disappears once no visible catch uses that species, so a typo fixes itself
  when its catch is corrected or deleted.
- Editing a catch whose species text exactly matches a chip shows that chip selected and the "Other
  species" field empty. A case variant of a chip (stored "yellow perch", chip "Yellow Perch") stays in
  the custom field, so saving it unchanged never rewrites the stored species text. (Other fields can
  still change on an unchanged save: the edit form rounds measurements to two decimals. That predates
  this feature and is tracked as a follow-up.)
- Species stays out of the last-used defaults: a new form still starts with no species selected.

## Acceptance criteria

1. After saving a catch with a custom species, a new Log a Catch form shows that species as an
   unselected chip.
2. Editing that catch shows its chip selected and the custom field empty.
3. Seed order is unchanged; custom chips follow alphabetically with case-insensitive duplicates merged.
4. Owner isolation, tombstone hiding, offline entry and sync behavior are unchanged.

## Non-goals

- Renaming, hiding or deleting custom species chips from a management screen.
- Sharing species across users, or a global species catalog.
- Reordering chips by frequency or recency.
