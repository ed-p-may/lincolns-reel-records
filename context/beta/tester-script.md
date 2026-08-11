# Friends-and-Family Tester Script

Target build: `0.1.0 (6)`. Expected time: 20–25 minutes. Each logbook is private; testers cannot see
another person's Catch, profile, or photos.

## What to Test

Try the new photo gallery and full-screen paging, same-day reuse of recent Catch details, and photo-based
date/time and GPS defaults. Confirm a date or pin you manually change is never replaced by another photo.
Also repeat the core offline/reconnect flow. Please report anything that loses data, exposes another
account, becomes stuck syncing, or is difficult to understand.

## Steps

1. Install from the email-only TestFlight invite. Create an account with a unique username, email, and
   password, or sign into your existing beta account.
2. Add a Catch with a named location, lure/bait, sky, and water clarity. Start another Catch on the same
   day and confirm those details are reused, but the previous Catch's GPS pin is not.
3. On a new Catch, choose a library photo known to contain capture date/time or location metadata.
   Confirm the available date/time and pin appear. Manually change the date or clear/select the pin, add
   another photo, and confirm the manual values remain unchanged.
4. Open the photo gallery from Log, select a photo, and swipe through the full-screen viewer. Repeat from
   Catch Detail and confirm the photo count and paging remain usable.
5. Turn on Airplane Mode. Add or edit a Catch with a photo, location, conditions, and note. Save it,
   close/reopen the app, and confirm it remains in Log.
6. Turn Airplane Mode off. Open **You** and pull down to trigger sync, wait for it to finish, then
   close/reopen the app. Confirm the Catch, photo, coordinates, and conditions remain exact.
7. Search/filter the Log, open the Catch on the map, bookmark it, and share its journal card. Cancel one
   share, then complete one through an available destination.
8. Add a Tackle Box item and use it on a second Catch. Archive/restore the item and confirm Catch history
   still shows it.
9. Edit display name, home water, angler-since year, and avatar. Sign out only after sync is finished;
   sign back in and confirm the private data returns.
10. Optional destructive check with a disposable account only: delete the account and confirm it cannot
   sign back in.

## Report format

Use TestFlight's Send Beta Feedback and include: build number, iPhone model/iOS version, the numbered
step, online/offline state, expected result, actual result, and a screenshot if it contains no password
or other person's private data. Mark any apparent data loss or cross-account exposure as **urgent**.
