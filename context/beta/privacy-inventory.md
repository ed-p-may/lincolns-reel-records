# Privacy Inventory

Repository source for `ReelRecords/Resources/PrivacyInfo.xcprivacy`, App Store Connect privacy answers,
permission review, and the public privacy policy. This is an engineering inventory, not legal advice.

## Collected data

All listed data is linked to the signed-in account, used only for app functionality, and not used for
tracking, advertising, or analytics.

| Apple category | Reel Records data | Why collected / where sent |
|---|---|---|
| Name | Optional display name | Private Supabase profile and in-app display. |
| Email address | Supabase Auth email | Authentication, account recovery, and account operation. |
| User ID | Auth UUID and username | Ownership, RLS, private object paths, and in-app identity. |
| Precise location | Optional Catch latitude/longitude | User-requested Catch location, map, and weather suggestion. |
| Photos or videos | Catch, tackle, and avatar JPEGs | Private logbook/profile features; photos are downsampled before upload. |
| Other user content | Catch, conditions, notes, tackle, and profile fields | The private fishing journal and its derived dashboard. |

The app has no ad SDK, analytics SDK, cross-app tracking, public feed, following, sharing between users,
payments, or card data. Catch-share images leave the app only after an explicit system-share action.

## Required-reason APIs

| API category | Reason | Repository use |
|---|---|---|
| User defaults | `CA92.1` | Store the app's last authenticated account/session hint in app-owned defaults. |
| File timestamp | `C617.1` | Remove expired Catch-share JPEGs from the app's temporary directory. |

## Permission purpose strings

| Permission | Current copy |
|---|---|
| Camera | Photograph a catch or an item in your private Tackle Box. |
| Location When In Use | Save the location of a catch when you choose to capture it. |
| Photo Library | Choose photos for your private fishing logbook and Tackle Box. |

Physical acceptance must check initial grant, denial, limited-library access, Settings recovery, and that
the app remains usable with manual/no-photo alternatives. Location capture is explicit foreground-only.

## External actions before distribution

- Publish and enter a privacy-policy URL that describes Supabase processing, retention/deletion,
  optional precise location/photos, account deletion, and a contact route.
- Reconcile App Store Connect privacy answers exactly to the six categories above and the privacy report
  generated from the signed archive.
- Because the invite list can include a minor and the app stores photos/precise locations, have the owner
  confirm the applicable consent/guardian and retention policy before inviting minors.
- Confirm Supabase's current data-processing terms and the Open-Meteo request behavior in the public
  policy. When a Catch has coordinates and empty eligible weather fields, the editor automatically
  sends its coordinates and Catch time to Open-Meteo to suggest conditions.
- Verify the hosted account-deletion path removes Auth, database rows, and all three private buckets.
