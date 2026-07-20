# Known Beta Limitations

These are approved v1 boundaries, not defects:

- iPhone only, portrait, dark-only, iOS 18 or later.
- Imperial units only (`lb`, `in`, and °F).
- Notifications and full-logbook export are disabled and labeled **Coming Soon**.
- No public feed, following, social sharing, public TestFlight link, metric mode, or payments.
- Map/weather suggestions require network and location permission; manual location/conditions remain
  available, and core logging/browsing works offline.
- Synchronization is eventual after reconnect. Do not sign out while the app reports pending/failed work;
  use its retry/recovery path first.
- Per-Catch share produces a journal image; it is not a full-logbook export.

The following are release blockers and must never be presented to testers as known limitations:

- unapplied hosted migrations or an undeployed account-deletion Function;
- failed RLS/private Storage isolation;
- missing privacy policy/App Store disclosures or unverified reset/deletion paths;
- any silent loss of locally committed data;
- unverified signed upgrade/clean install/physical permission and reconnect scenarios;
- a build that is not approved and assigned to the private email-only external group.
