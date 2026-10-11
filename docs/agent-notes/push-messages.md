# Push messages that say what happened

Branch `push-messages` (from `build/v1`). Owner bug on a real iPhone: a booking made through the page raised a
lock-screen alert reading `push.booking.new`.

## Root causes

1. The app never had strings for the server's push `loc-key`s. iOS resolves `loc-key` from the app bundle (also
   for a closed app); with no string it shows the key itself.
2. The server used one key, `push.booking.new`, for a new confirmed booking, a request waiting for approval, a
   client's move and a client's cancellation (`handleBookingWritten.ts`), so even with a string she could not tell
   what happened.

## What changed

- **Server.** `PushMessage` has an optional `event` (`new | request | moved | cancelled`, only for `kind: booking`).
  `buildFcmMessage` sends it as `data.event` (old apps ignore it; the tap routing still reads only `kind` and `id`)
  and picks the alert key through `pushAlertOf`. `PUSH_ALERT_KEYS` is keyed by alert (`booking.new`, `booking.request`,
  `booking.moved`, `booking.cancelled`, `bookingLate`, `bookingConfirmed`, `rescheduleRequest`, `waitlist`). The
  trigger sends `request` for a new `pendingApproval` booking (also the unverified WhatsApp requests of D58), `new`
  otherwise, `moved` for a client's reschedule, `cancelled` for a client's cancellation. Still no name, service,
  time, `loc-args`, title or body. The emulator outbox records the event too.
- **Shared key list.** `firebase/functions/contracts/push-keys.json` (`npm run gen:push-keys`, a unit test fails on
  drift), copied into `BelloHubTests/Resources/ServerContract/` by `scripts/sync-server-contract.sh` (and checked by
  `check-server-contract.sh` in `test.sh`).
- **iOS strings.** `Config/Locale/strings/push-alerts.json`: the eight keys in all twelve authored languages, plus
  en-GB overrides ("cancelled", "Waiting list update"). They are batch strings, so `extractionState: manual`: Xcode
  never marks them stale, and `merge-strings.py --prune` keeps every authored key even when no Swift file names it
  (it removes only keys no batch authors). Wording avoids personal data and, where the language allows, the client's
  gender (impersonal or passive forms; pt keeps "Uma cliente" as the owner wrote it, matching the app's "clientes").
- **iOS test.** `PushAlertStringsTests` reads `push-keys.json` from the test bundle and checks every key in all
  fourteen compiled `.lproj` folders: resolved, non-empty, no placeholder; and that the four booking events read
  differently in every language.
- **Foreground.** `willPresent` showed every push as a banner; iOS resolves the `loc-key` before the delegate, so with
  the strings the banner is readable. For a key the app does not know yet (a server newer than the app),
  `PushPresentation` hides the banner instead of showing the raw key; the event still syncs.

## Order of release

A new key must ship in the app before the server sends it. This change sends four keys old apps do not have
(`push.booking.request`, `.moved`, `.cancelled` in addition to the never-localized old ones), so: reinstall the app,
then redeploy the functions. An app that predates this already showed raw keys, so nothing gets worse.

## OWNER DECISION (not implemented): details on the lock screen

She may want "Ana, Facial, Fri 10:00" on the lock screen. Options:

1. **Send the details in the push (opt-in toggle).** Cheapest (server change plus a toggle). But the name, service
   and time would travel through Google (FCM) and Apple (APNs) and sit in the phone's notification store, readable
   on a locked phone by anyone holding it. Breaks docs/06 section 8 and API.md section 7 as written; needs a privacy
   policy change, a DPA review for FCM and APNs as processors of client data, and a per-device opt-in. Not
   recommended.
2. **Notification Service Extension (NSE) that fills the text on the phone.** The push stays as today (kind, id,
   event); the extension (`mutable-content: 1`) gets about 30 seconds to rewrite the alert. It could read the
   booking from the server with the user's credentials (needs Firebase Auth shared through an app group and keychain
   access group, a small callable or a Firestore read, and graceful fallback to the generic text on timeout) or from
   the local vault (needs the store moved into an app-group container the extension can open, plus the vault key
   shared with it through a keychain access group; the store is `completeUntilFirstUserAuthentication`, so it is
   readable while locked after first unlock, but a second process opening it widens the attack surface). Cost:
   a new target, app-group plumbing, memory limit of about 24 MB, more review surface. Privacy: nothing extra leaves
   the phone, but details still show on a locked screen, so it must stay an opt-in and respect iOS "Show previews:
   When unlocked".
3. **Keep generic text (current).** No cost; she opens the app to see who.

Recommendation: stay with 3 for v1; if she insists, 2 via a server read, opt-in, generic fallback.
