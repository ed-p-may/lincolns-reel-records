# Environments, Accounts, and Distribution Runbook

Operational source of truth for the accounts and identifiers used to build, sign, distribute, and run
Lincoln's Reel Records. Last reconciled against the repository and live Supabase project on
**2026-07-19**. App Store Connect values were reconciled against the setup completed that day.

This GitHub repository is **public**. Record stable, non-secret identifiers here; never record passwords,
Apple two-factor recovery information, signing private keys, device serials/UDIDs, Supabase secret keys,
or service-role credentials.

## Keep the three account layers distinct

1. **Apple Developer / App Store Connect account** — owns and signs the app. Xcode uses this account.
2. **TestFlight tester email** — controls who may install the beta. It is not an in-app login.
3. **Supabase Auth account** — signs into Reel Records and owns that user's private logbook through RLS.

An invited tester must still create or log into a Supabase account inside the app. Removing a TestFlight
tester prevents future beta access but does not automatically delete that person's Supabase account/data.

## Apple Developer and App Store Connect

| Item | Current value / source |
|---|---|
| Apple Developer membership | Edwin May, Individual; Apple Developer Program |
| Xcode Apple account | `ed.p.may@gmail.com` |
| Team ID | `JPJ3AJ5U8A` |
| App name | Lincoln's Reel Records |
| Xcode project / scheme | `LincolnReelRecords` |
| Bundle identifier | `com.bldgtyp.LincolnsReelRecords` |
| App ID description | `Lincolns Reel Records` (Apple identifier record) |
| App Store Connect Apple ID | `6792562563` |
| SKU | `lincolns-reel-records-ios` |
| Signing | Automatic, Xcode-managed; `DEVELOPMENT_TEAM` is declared in `project.yml` |
| Archive configuration | Shared `LincolnReelRecords` scheme archives with the `Beta` configuration |
| Encryption declaration | `ITSAppUsesNonExemptEncryption = false` in the app Info.plist |

Xcode Settings > Accounts must show the Apple account above. The app target's Signing & Capabilities tab
must show team **Edwin May**, automatic signing, and the exact bundle identifier. Certificates and
provisioning profiles are renewable Xcode-managed assets; their transient IDs are intentionally not
treated as project configuration.

Apple membership billing/contact information and two-factor recovery data live only in the Apple
Developer account. Do not copy them into this public repository.

### TestFlight

| Group | Type | Membership / current state |
|---|---|---|
| `Reel Records Internal` | Internal | Ed May; build `0.1.0 (3)` is available internally |
| `Reel Records Friends & Family` | External, email-only | Lincoln Fisher is added; build `0.1.0 (3)` is in TestFlight App Review |

There is no public TestFlight link. Tester email addresses are authoritative in App Store Connect; the
minor tester's address is intentionally not duplicated in this public repository.

The Phase 01 physical device is an iPhone 16 Pro on iOS 18.6, registered to the developer team with
Developer Mode enabled. Its serial number and UDID are authoritative in Apple Developer > Devices and
Xcode > Devices and Simulators, not in Git.

## Supabase hosted beta

| Item | Current value / source |
|---|---|
| Organization | `bldgtyp` (`xsifcxxbthurutbojpbw`) |
| Organization plan | Free (`$0/month` base plan when live-verified 2026-07-19) |
| Project name | `lincolns-reel-records` |
| Project reference | `ptoqkqisgyzypfpjvmvx` |
| Region | `us-east-1` |
| API URL | `https://ptoqkqisgyzypfpjvmvx.supabase.co` |
| Live status | `ACTIVE_HEALTHY` when verified 2026-07-19 |
| Database | PostgreSQL 17, hosted by Supabase |
| Current hosted migration | `20260719191234_create_phase_01_schema` |
| Signup | Email/password enabled; email confirmation disabled for this invite-only beta |

The active client key is the modern Supabase **publishable** key named `default`. Its one canonical
committed value is `SUPABASE_PUBLISHABLE_KEY` in `Config/Base.xcconfig`; that value matched the active
hosted key when verified. A publishable key is expected to ship in a mobile client and relies on Auth,
grants, and RLS for data protection. A Supabase `sb_secret_...` key, legacy `service_role` key, database
password, or JWT signing secret must never appear in the app or Git.

`supabase/config.toml` configures a possible local Supabase stack. Its
`project_id = "lincolns_reel_records"` is a local CLI identifier, **not** the hosted project reference.
The local stack is not currently the app's Debug backend, and no production Supabase project exists yet.

### Build configuration mapping

| Xcode configuration | Configuration file | Current backend |
|---|---|---|
| Debug | `Config/Debug.xcconfig` → `Config/Base.xcconfig` | Hosted beta project |
| Beta | `Config/Beta.xcconfig` → `Config/Base.xcconfig` | Hosted beta project |
| Release | `Config/Beta.xcconfig` → `Config/Base.xcconfig` | Hosted beta project; not the archive scheme's selected configuration |

This shared hosted endpoint is an explicit Phase 01 shortcut. The target architecture is a local or
separate development backend for Debug and hosted beta for TestFlight. When that split is implemented,
override the public host/key in the configuration-specific files without moving configuration into Swift
business logic.

`project.yml` is the source for build settings and XcodeGen structure; regenerate the `.xcodeproj` after
changing it. `AppConfiguration.swift` reads the host and publishable key from the generated Info.plist.
The iOS app does not read a shell `.env` file.

## Login accounts

| Purpose | System | Account | Status / notes |
|---|---|---|---|
| Developer, signing, App Store Connect | Apple | `ed.p.may@gmail.com` | Apple password and 2FA remain only with Apple/Ed |
| Internal TestFlight install | App Store Connect | Ed May | Tester email is maintained in the internal group |
| Ed's private logbook | Supabase Auth | `ed.p.may@gmail.com`; username `edpmay` | Confirmed live account |
| Apple beta review | Supabase Auth | `app-review@lincolnsreelrecords.test`; username `apple_review` | Confirmed live account; credentials entered in App Store Connect Test Information |
| External TestFlight install | App Store Connect | Lincoln Fisher | Invite is maintained in the external group; no Supabase account exists until in-app signup |

Passwords are intentionally absent from Git. The Apple review password's operational copy is in App
Store Connect Test Information. Because its `.test` email address cannot receive password-reset mail,
any rotation requires an administrator-side Supabase Auth password update and the matching App Store
Connect Test Information update in the same maintenance action.

## Change checklist

- **New build:** increment `CURRENT_PROJECT_VERSION` in `project.yml`, regenerate the Xcode project,
  archive the shared scheme, and distribute through App Store Connect.
- **Publishable-key rotation:** update the active key in Supabase and `Config/Base.xcconfig`, verify a
  signed build, then disable the old key only after deployed clients are accounted for.
- **Reviewer credential rotation:** update Supabase Auth and App Store Connect Test Information together.
- **New external tester:** add by email to `Reel Records Friends & Family`; do not create a public link.
- **Environment split:** create/confirm the new backend first, then override Debug's host/key and document
  its project reference here. Never point a destructive development workflow at the hosted beta by
  accident.

## Authoritative-source order

| Question | Source of truth |
|---|---|
| Bundle/team/build settings | `project.yml` |
| Client API host and publishable key | `Config/*.xcconfig` |
| Schema | `supabase/migrations/` plus the hosted migration ledger |
| Hosted plan, project health, Auth users | Supabase Dashboard / Management API |
| Signing assets, registered devices | Apple Developer and Xcode |
| Build availability, tester emails, review credentials | App Store Connect |
| Product/architecture rationale | `context/decisions.md` |

