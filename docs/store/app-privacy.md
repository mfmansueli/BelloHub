# App Privacy answers (App Store Connect) and the privacy manifest

Draft for H14 (App Store Connect record). Source: `docs/06-PRIVACY-SECURITY.md` sections 1 to 3 and 8, the code on
`build/v1` (S8 leftovers, 2026-10-10) and `BelloHub/SupportFiles/PrivacyInfo.xcprivacy`, which says the same thing in
machine form. If the answers here and the manifest disagree, fix both in one change; `scripts/check-privacy.sh` fails
when the manifest is missing, claims tracking, or misses a required-reason API the code uses.

Engineering draft, not legal advice (`LEGAL-REVIEW`, O8).

## 1. The short version

- **Tracking:** No. No advertising, no data broker, no third-party analytics or crash SDK, no IDFA, no
  `AppTrackingTransparency` prompt.
- **Health data: not collected.** Health answers, consents, treatment notes, photos, voice and transcripts live on her
  iPhone and in her own iCloud, encrypted with a key derived from her recovery words that Bello Hub never holds (D26).
  A client's health form reaches the phone as a sealed envelope (HPKE) that the server stores but cannot open, and it is
  deleted as soon as the phone acknowledges it (30 days at most). Apple's definition of "collect" is data that we or our
  partners can access; we cannot, so the answer is "not collected".
- **What is collected:** only what is needed to run her account, her booking page and her subscription, always linked to
  her account, never used for tracking, only for App Functionality.

## 2. Answers, data type by data type

App Store Connect asks, for each type: collected? linked to the user? used for tracking? purposes?

| App Store Connect type | Collected | Linked | Tracking | Purpose | What it is in Bello Hub |
|---|---|---|---|---|---|
| Contact Info · Name | Yes | Yes | No | App Functionality | Her name from Sign in with Apple (Firebase Auth) and the display name or business name she publishes on her booking page |
| Contact Info · Email Address | Yes | Yes | No | App Functionality | The email Sign in with Apple gives Firebase Auth (often an Apple relay address); never shown, never used for marketing |
| Contact Info · Phone Number | Yes | Yes | No | App Functionality | Her clients' phones, sent only for operational actions she takes: stop online booking for one client, reset a client's no-show count (docs/06 class O). Declared conservatively: they are numbers about other people, linked to her account |
| Contact Info · Physical Address | No | | | | The published page carries no address in v1 (`PublishProfileRequest`) |
| Contact Info · Other User Contact Info | No | | | | |
| Health & Fitness · Health | **No** | | | | Sealed on the client's device, opened only on hers; vault encrypted end to end (see section 1) |
| Health & Fitness · Fitness | No | | | | |
| Financial Info (all) | No | | | | No payments in the app (product rule 1); the App Store handles the subscription |
| Location (precise, coarse) | No | | | | Her region is a choice in onboarding, not a location reading |
| Sensitive Info | No | | | | |
| Contacts | No | | | | The contact picker reads one contact on her tap, on the device; the list never leaves the phone |
| User Content · Emails or Text Messages | No | | | | WhatsApp messages open in WhatsApp with the text ready; the app does not send them |
| User Content · Photos or Videos | No | | | | Treatment photos stay in the vault (iCloud, encrypted); the profile photo on the booking page is not uploaded in v1 (check before submission if that changes) |
| User Content · Audio Data | No | | | | Voice notes are transcribed on the device and the audio is discarded |
| User Content · Gameplay Content | No | | | | |
| User Content · Customer Support | No | | | | Support is by email outside the app |
| User Content · Other User Content | Yes | Yes | No | App Functionality | Her public booking page (`PublishProfileRequest`, `publishAvailability`): services she chose to publish (prices only if she shows them), hours and busy times without any detail, booking rules and policy texts, credentials, the health-form template (questions only), the inbox public key |
| Browsing History, Search History | No | | | | |
| Identifiers · User ID | Yes | Yes | No | App Functionality | Firebase Auth uid; the server's `appAccountToken` (a random UUID tied to the account) |
| Identifiers · Device ID | Yes | Yes | No | App Functionality | The Firebase Cloud Messaging token, for push about her bookings |
| Purchases · Purchase History | Yes | Yes | No | App Functionality | The App Store's signed transaction of her Bello Hub Pro plan, re-verified on the server (`syncPlan`) and kept as a plan state with an end date |
| Usage Data (all) | No | | | | No analytics |
| Diagnostics · Crash Data, Performance Data, Other | No | | | | No crash SDK (Crashlytics was removed in S0); MetricKit, if added, stays on the device |
| Other Data | No | | | | |

### Data her clients give through the web page

The booking page is a website, not the app, so it is outside the App Privacy label. It is covered by the privacy policy
(`legal/`): client name, phone, optional email, booking facts, an optional short note, and sealed envelopes the server
cannot read. Phone numbers are hashed with a server pepper for counters and blocks (`PHONE_HASH_PEPPER`).

## 3. The privacy manifest (`PrivacyInfo.xcprivacy`)

| Key | Value | Why |
|---|---|---|
| `NSPrivacyTracking` | `false` | No tracking of any kind |
| `NSPrivacyTrackingDomains` | empty | No tracking domain is contacted |
| `NSPrivacyCollectedDataTypes` | UserID, Name, EmailAddress, PhoneNumber, OtherUserContent, PurchaseHistory, DeviceID; each linked, not tracking, purpose App Functionality | Same as the table above |
| `NSPrivacyAccessedAPITypes` | `NSPrivacyAccessedAPICategoryUserDefaults`, reason `CA92.1` | The app reads and writes its own settings (`DefaultsKey`, `@AppStorage`); nothing is shared with other apps (no app group) |

Required-reason API categories the app's own code does **not** use (checked with `scripts/check-privacy.sh`, which
fails the build the day one of them appears without a manifest entry):

| Category | Status |
|---|---|
| File timestamp (`creationDate`, `modificationDate`, `attributesOfItem`, `stat`, `getattrlist`) | Not used. The importers read `fileSizeKey` and `contentTypeKey` only, which are not timestamp APIs |
| Disk space (`volumeAvailableCapacity…`, `systemFreeSize`, `statfs`) | Not used |
| System boot time (`systemUptime`, `mach_absolute_time`) | Not used (`ContinuousClock` and `Task.sleep` are not on Apple's list) |
| Active keyboards (`activeInputModes`) | Not used |

Third-party SDKs: Firebase Auth, Firebase Core and Firebase Messaging (Swift Package Manager). Each ships its own
`PrivacyInfo.xcprivacy` in its package; Xcode merges them into the privacy report of the archive. Before submission,
open **Product > Archive > Generate Privacy Report** and check that the merged report adds nothing that contradicts the
table above (Firebase Messaging declares its installation ID and FCM token, which is the "Device ID" row).

## 4. Before you submit (human, H14)

1. Archive, generate the privacy report, compare with section 2.
2. Enter section 2 in App Store Connect > App Privacy, in this order: Data Collection = Yes; the seven types; for each
   "Linked to the user" = Yes, "Tracking" = No, purpose = App Functionality.
3. Privacy policy URL: the hosted `legal/` privacy policy (needs the domain, H6).
4. If a feature starts sending anything new (a profile photo upload, crash reports, a support chat), update the manifest,
   this file and the policy in the same change.
