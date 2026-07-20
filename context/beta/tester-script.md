# Friends-and-Family Tester Script

Target build: `0.1.0 (4)`. Expected time: 15–20 minutes. Each logbook is private; testers cannot see
another person's Catch, profile, or photos.

## What to Test

Create or sign into an account, record a Catch while offline, add a photo and location, reconnect and
confirm it syncs, browse the Log and map, bookmark/share a Catch, add a Tackle Box item, and edit your
profile. Please report anything that loses data, exposes another account, becomes stuck syncing, or is
difficult to understand.

## Steps

1. Install from the email-only TestFlight invite. Create an account with a unique username, email, and
   password, or sign into your existing beta account.
2. Turn on Airplane Mode. Add a Catch with species, date/time, one measurement, a named location, and a
   note. Save it, close/reopen the app, and confirm it remains in Log.
3. Edit that offline Catch. Add a photo from Camera or Library, manually set a map point if GPS is
   unavailable, enter conditions, and save again.
4. Turn Airplane Mode off. Open **You** and pull down to trigger sync, wait for it to finish, then
   close/reopen the app. Confirm the Catch, photo, coordinates, and conditions remain exact.
5. Search/filter the Log, open the Catch on the map, bookmark it, and share its journal card. Cancel one
   share, then complete one through an available destination.
6. Add a Tackle Box item and use it on a second Catch. Archive/restore the item and confirm Catch history
   still shows it.
7. Edit display name, home water, angler-since year, and avatar. Sign out only after sync is finished;
   sign back in and confirm the private data returns.
8. Optional destructive check with a disposable account only: delete the account and confirm it cannot
   sign back in.

## Report format

Use TestFlight's Send Beta Feedback and include: build number, iPhone model/iOS version, the numbered
step, online/offline state, expected result, actual result, and a screenshot if it contains no password
or other person's private data. Mark any apparent data loss or cross-account exposure as **urgent**.
