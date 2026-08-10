# Last-used Catch Defaults

**Source:** [GitHub Issue #2](https://github.com/ed-p-may/lincolns-reel-records/issues/2)
**Status:** Complete
**Owner:** Reel Records iOS app

## Goal

Reduce repeated input while an angler logs several catches during one fishing day without carrying
stale trip details into a later day or reusing an old GPS pin.

## Resolved product contract

The Issue #2 discussion resolves the feature as follows:

- A new catch may reuse values only from the owner's latest visible catch on the same local calendar day.
- The carried fields are the named spot, saved Tackle Box selection and/or one-off lure text, sky, and
  water clarity. If the latest catch left one of those fields blank, that field remains blank.
- A different calendar day starts from the existing empty/default form state.
- The named spot may carry forward, but latitude and longitude never do; the angler captures a fresh
  coordinate for each catch.
- Weather auto-fill remains authoritative for sky when it returns a value. The last-used sky is a
  fallback while weather is unavailable; a manual sky edit still wins over a late weather response.
- Water clarity is user-entered and remains the carried value because the weather service does not
  provide it.
- Only these four field groups are in scope. Species, measurements, time, temperatures, rod/reel,
  notes, disposition, photos, and bookmark state keep their current defaults.

## UX and state contract

- Defaults are evaluated once when a new Add Catch form opens, using its initial catch date.
- Editing an existing catch never applies last-used defaults.
- Default lookup is a fetch-limited local query bounded to the owner's current calendar day and does
  not add a remote request or persisted setting.
- Loading defaults must not affect sync, saved catch data, or the previous catch.

## Acceptance criteria

1. A new form opened after a same-day catch prefills its spot name, lure/bait values, sky, and water
   clarity from that latest catch.
2. The new form has no coordinate until the user captures or chooses a fresh pin.
3. A catch from another local calendar day supplies no defaults.
4. A weather suggestion replaces the carried sky fallback, while a manual sky edit blocks a later
   suggestion.
5. Owner isolation, existing Add/Edit Catch behavior, offline entry, and sync behavior remain unchanged.

## Non-goals

- Persisted per-user default settings or a Defaults screen.
- Carrying coordinates, temperatures, rod/reel, notes, measurements, disposition, photos, or species.
- Inferring a fishing trip, using elapsed-hour windows, or scanning older same-day catches for each
  field independently.
