# 14 · Human tasks (for Iago and Mateus)

Things the code cannot do on its own. Claude Code builds everything around them with fakes and emulators and marks the integration point `TODO(HUMAN-Hn)`. Each task says **who**, **when it is needed**, **exact steps**, and **what Claude Code expects as the result**. Claude Code keeps this file current: it adds tasks it discovers and ticks nothing (humans tick).

Who is who: **Iago** owns the Apple Developer account (Individual, team `X5392U638Q`), the product, `pt-BR` and the business side; the Mac that runs Claude Code is his (Xcode 27). **Mateus** owns Firebase and engineering support; he must be added to the Apple team (see H1) to help with signing and TestFlight.

| Id | Task | Who | Needed by |
|---|---|---|---|
| H1 | Xcode signing and capabilities | Iago (Mateus helps) | S2 (iCloud), S8 (push) |
| H2 | CloudKit container and schema to Production | Iago / Mateus | S2 on device, before TestFlight |
| H3 | Two real iPhones for sync, AI and voice checks | Iago / Mateus | end of S2, S7, S12 |
| H4 | Firebase projects, billing, Auth, SMS region list, APNs key, budgets (**done by the owners**; the Firestore database is created by Claude Code in S0) | Mateus | done / SMS list before S8 deploys |
| H5 | App Check providers (App Attest, reCAPTCHA Enterprise) | Mateus | before S8/S9 deploy |
| H6 | Domain `bellohub.app`, DNS, Hosting | Iago / Mateus | before S9 deploys |
| H7 | Transactional email provider | Mateus | before S8 deploys |
| H8 | In-app browser tests on real phones | Iago | end of S9 |
| H9 | Google Calendar OAuth (optional, v1.1) | Mateus | optional |
| H10 | Native reading of the languages (`pt-BR` first, read by Iago). **Not planned (D41); optional, any time** | Iago; native readers | optional |
| H11 | Legal review per market. **After sales appear (D40)**, not before launch | data-protection lawyer | when the owner decides |
| H12 | Fonts if the build environment has no network | Iago / Mateus | S1 |
| H13 | WhatsApp Business (Meta) onboarding (optional, **post-v1**: v1 stays manual, wa.me links) | Iago | after v1 |
| H14 | App Store Connect, subscriptions, privacy labels, TestFlight | Iago / Mateus | S12 |
| H15 | Open markets in App Store Connect: **every market the owner can (D40)** | Iago | at the owner's discretion |
| H16 | Individual-account duties (trader status, seller name) and release Xcode for uploads | Iago | before the first App Store submission |
| H17 | GitHub CLI login (to open pull requests) and repository access for pushes | Iago | end of phase A |
| H18 | Breach plan: read `docs/BREACH-PLAN.md`, name who is on call, keep a private incident log, have the professional email template ready | Iago / Mateus | before the first real professional |
| H19 | Release-candidate checks on a real iPhone: VoiceOver pass, hitches, cold start, Apple Calendar, camera, Face ID (S12) | Iago / Mateus | before external TestFlight |
| H20 | Decide the phone sign-in: keep v1 Apple only, or have Claude Code wire Firebase phone auth and test it on a device | Iago | before the App Store submission |

---

### H1 · Xcode signing and capabilities
The account is Iago's, so he does this on his Mac, signed into Xcode with his Apple ID (*Xcode → Settings → Accounts*).
1. Add Mateus to the team so he can help: App Store Connect → *Users and Access* → invite with role *Admin* (or *App Manager* + *Developer*). The Individual account can invite members.
2. Open `BelloHub.xcodeproj`, target **BelloHub**, *Signing & Capabilities*, team `X5392U638Q`, bundle id `com.bellohub` (D38; Claude Code changes it in S0).
3. Add **iCloud** → check **CloudKit** → container `iCloud.com.bellohub`.
4. Add **Push Notifications** and **Background Modes → Remote notifications**.
5. Add **App Attest** (Firebase App Check on iOS) if Xcode lists it as a capability; keep the entitlement `com.apple.developer.devicecheck.appattest-environment`.
6. Commit the generated `BelloHub.entitlements` (the build setting `CODE_SIGN_ENTITLEMENTS` must live in `Config/App.xcconfig`, not in the project file).
Claude Code may try `xcodebuild … -allowProvisioningUpdates` with the account already signed in to let Xcode register the App ID, capabilities and container itself; if that fails, it records the error and leaves the steps above to Iago.
**Claude Code expects:** an entitlements file with the container id above and `aps-environment`; until then it runs with `cloudKitDatabase: .none` and a `LocalDevAuthProvider`.

### H2 · CloudKit schema
After the first device run with the container, open the CloudKit Dashboard → container `iCloud.com.bellohub` → *Deploy Schema Changes to Production*. Repeat before every TestFlight/App Store build that changes the model. **Expected:** a note in `PROGRESS.md` with the date and schema version.

### H3 · Real devices
Two iPhones (iOS 26+, ideally one with Apple Intelligence) signed into the **same Apple ID** with iCloud Drive and Keychain on. Follow the checklist in `docs/spikes/SPIKE-swiftdata-cloudkit.md` (Claude Code writes it): create client + record + photos on A, see them on B; edit offline on both; fill iCloud quota test; restore on a fresh install; try the recovery key; run voice transcription **in Portuguese (Brazil) first, then every language the device offers**, and record the results in `docs/spikes/VOICE-LANGUAGE-MATRIX.md` (`12-AI-AND-VOICE.md` §8). Paste the numbers into the spike report.

### H4 · Firebase
1. Create three projects `bellohub-dev`, `bellohub-staging`, `bellohub-prod` (Blaze plan for Functions).
2. Region decided in D29: Firestore **`eur3`**, Storage in the EU location, Functions `europe-west1`. The Firestore database itself is created by Claude Code in S0 with that location; the owners only confirm nothing else was created before it.
3. Enable **Authentication → Phone**; add test numbers for dev. Set the **SMS region policy as an allow-list** with the calling codes printed by `firebase/scripts/sms-regions.mjs` (D37). Set an SMS budget alert.
4. Upload the **APNs auth key** (Cloud Messaging) for each project; add the iOS apps (`com.bellohub`) and download `GoogleService-Info.plist` into `Config/Firebase/<Env>/`.
5. Set **budget alerts** and a monthly cap; enable **Firestore TTL policies** for `inbox/{uid}/items` and `holds` on `expiresAt`, and `rate`, `audit` per `firebase/README.md`; enable **PITR** with the shortest window.
6. Add Secret Manager secrets: `PHONE_HASH_PEPPER`, email provider key; give Functions access.
**Expected:** `.firebaserc` aliases and `firebase deploy --only firestore,functions,hosting --project bellohub-staging` working.

### H5 · App Check
iOS: register **App Attest** (and DeviceCheck fallback) in Firebase App Check. Web: create a **reCAPTCHA Enterprise** key for the Hosting domains and register it. Turn on **enforcement** per product (Firestore, Functions, Storage) only after staging passes. **Expected:** site key in `web/.env.<env>`; enforcement flags noted in `PROGRESS.md`.

### H6 · Domain
Register **`bellohub.app`** (recommended: HTTPS-only top-level domain, short, no local-presence rules), point it to Firebase Hosting (prod) and a staging subdomain (`staging.bellohub.app`), enable HTTPS, serve `/.well-known/apple-app-site-association` with app id `X5392U638Q.com.bellohub` when universal links are wanted. **Expected:** `BELLO_WEB_BASE_URL` values in `Config/*.xcconfig` and `web/.env.*`.

### H7 · Email provider
Pick a transactional email service (Resend, Postmark, SES…), verify the sending domain (SPF, DKIM, DMARC), create an API key, store it as a Functions secret. Sign the provider's DPA. **Expected:** `EmailProvider` implementation selected in `firebase/functions/src/messaging/` (Claude Code writes the adapter for the one you choose; tell it which).

### H8 · In-app browser tests
On real phones, open a booking link **inside** WhatsApp, Instagram and Facebook on iOS and Android and walk through booking, management, health form and check-in using staging; do it also once in Arabic (right-to-left) and once with an Arabic-Indic digit keyboard. Record failures with screenshots in `docs/PROGRESS.md` (Claude Code fixes them).

Checklist added in S9 (`docs/agent-notes/s9-web.md`, `web.md` section 8): the page renders in the right language; a booking runs to the confirmation with the e-mail code; the `.ics` and Google links work or the "open in browser" note appears; the personal link copies; the check-in photo can be taken and chosen (camera and library) and previews; sheets open, trap focus and close with the back gesture; no horizontal scroll at 320 px; Arabic mirrors; largest text sizes; Low Power Mode; private mode (storage blocked) still books; WhatsApp links open the app; whether Safari's console prints the WebKit `<select>` CSP line on the "you" step (cosmetic if so); **a waiting-list offer link sent from the app opens on her details with the kept time; after she goes online, the health form on the page shows her own questions in her language** (the app publishes it since S9).

### H9 · Google Calendar (optional)
Create an OAuth client in Google Cloud for the app and complete Google's verification; until then the `Integrations` row says "coming soon". Not required for v1.

### H10 · Reading the languages
> **Owner decision D41 (2026-10-08): not planned.** Kept for the day someone wants to read a language; nothing waits for it.

There are no reviewers yet. The plan:
1. **`pt-BR`: Iago reads it** (needed for Brazil, wave 1) using `docs/review/pt-BR.md` (the ordered list of screens and strings, ready since S11) and the spreadsheets from `scripts/export-strings.sh pt-BR` (`build/strings-pt-BR.csv` for the app, `build/web-strings-pt-BR.csv` for the booking pages). He edits the spreadsheet only (never the catalog), then runs `scripts/import-strings.sh pt-BR build/strings-pt-BR.csv --reviewed` and `python3 scripts/merge-strings.py`; the approved strings become `translated` (the round trip is in `docs/review/README.md`). This unlocks wave 1 (together with H11).
2. Other languages: **wave 1 needs a native reader each for `pt-PT`, `es`, `it`, `fr`, `de` and `en-GB`** (English readers also cover `en`); the others when their market is about to open. Find one native reader per language (friends, family, clients, a paid freelancer). Give them the exported spreadsheet (`key, en, <language>, comment`) and the glossary; ask them to read the whole app once as a user and edit directly. Return edits through `scripts/import-strings.sh`.
3. Review also covers the message templates (`docs/strings/message-templates.json`), the emails (`firebase/functions/src/messaging/emailTemplates.ts`), the profession catalog and the legal drafts' *wording* (not their legal validity). Each `docs/review/<id>.md` (wave 1: pt-BR, pt-PT, es, it, fr, de, en, en-GB) lists them with the S11 decisions to check first (for example German *du* in the app and *Sie* to clients, French generic *clients*).
4. **Screenshots for readers:** `TEST_RUNNER_SCREENSHOT_LOCALES=<id> TEST_RUNNER_SCREENSHOT_DIR=$PWD/build/screenshots/s11 ONLY_TESTING=BelloHubUITests/LocalizationScreenshotUITests scripts/test.sh full` saves the key screens of a language (about a minute per language).
5. When a language is fully read, remove it from "Strings awaiting reviewers" in `docs/PROGRESS.md`, so `check-strings.sh --final` keeps it complete.
Until a language is read, it stays `needs_review` and its market stays closed in App Store Connect (H15).

### H11 · Legal review
> **Owner decision D40 (2026-10-08): after sales appear.** Claude Code writes the texts for every market now (`legal/`); the owner sends them to a lawyer when the product gets traction. Not a gate for opening a market.

Read `legal/EUROPE.md` first: since S11 the European terms and privacy policy (`2026-10-2`) are one **common GDPR core (Part A) plus a national annex (Part B)** per country (PT, ES, IT, FR, DE with AT and CH notes, UK with IE, AU, NZ, ZA notes), so a European lawyer reviews Part A once and local counsel each annex. Start with **Brazil**: a data-protection lawyer (LGPD) reviews the terms and DPA, privacy policy, client notice and data-request wording (the consent texts are no longer produced, D55), retention minimums per profession, international-transfer wording (servers in the EU), the "sealed in your browser" claims. Then, per wave (`16-MARKETS.md`): Portugal/Spain (EU), Mexico, United States, Latin America, Italy, France, Germany, United Kingdom, India, Turkey, Indonesia, and last Saudi Arabia and the UAE (these two need a written opinion on health-data residency). One lawyer can coordinate local counsel. Return the final texts; Claude Code replaces drafts under `legal/` and bumps `textVersion`; update `legal/STATUS.md`.

### H12 · Fonts
If `scripts/fetch-fonts.sh` cannot download Fraunces and DM Sans (network blocked), download the variable `.ttf` files from the official Google Fonts repositories (SIL OFL) into `BelloHub/DesignSystem/Fonts/` and `web/public/fonts/` with their license files. (Arabic and Devanagari use system fonts; nothing to download.)

### H13 · WhatsApp Business (optional, post-v1)
> **Owner decision (2026-10-10): v1 stays in manual WhatsApp mode** (the professional opens a `wa.me` link with the
> prepared text and taps send). Nothing here is needed for v1.

State of the code: `WhatsAppCloudProvider` (`firebase/functions/src/messaging/`) is built and tested with mocks, but it
is **not wired**: `createDeps.ts` always builds `DisabledWhatsAppProvider`, so automation after v1 needs a small code
change as well as the onboarding (a `WHATSAPP_PHONE_NUMBER_ID` parameter and a `WHATSAPP_ACCESS_TOKEN` secret,
`createMessenger` building the Cloud provider only when both are set, like the Resend email provider). Steps when the
owner wants it: Meta Business account and business verification; a WhatsApp Business app and phone number; message
templates submitted **per language** (confirmation, reminder, code; utility category) and approved; the phone number id
and a permanent access token handed to Claude Code (the token as a Secret Manager secret); Claude Code wires the
provider and its tests; then Remote Config `whatsAppAutomation = true` for the cohort you choose. Note per-message
costs, which differ by country. **Expected:** the web and app copy switch to the automated wording only after that.

### H14 · App Store Connect
Create the app record (bundle id `com.bellohub`), the subscription group "Bello Hub Pro" with monthly and yearly products (`com.bellohub.pro.monthly`, `com.bellohub.pro.yearly`) **with no free trial and no introductory offer** (D33, D42), set the prices per storefront (EUR 14.99 and 149.99 for the euro-zone storefronts, USD 14.99 and 149.99 for the United States, BRL 39.90 and 399.90 for Brazil; other storefronts take Apple's equalized price unless you set them), fill in **App Privacy** answers from `06-PRIVACY-SECURITY.md` §1–§2, add the privacy policy URL, add the metadata and screenshots per language from `docs/store/`, create the TestFlight group (internal first). **Expected:** the StoreKit product ids match D33; `PrivacyInfo.xcprivacy` matches the answers.

### H15 · Open markets
> **Owner decision D40 (2026-10-08): open every market possible, formalize later.** The conditions below are recommendations. Still required by Apple, whatever the market: a public privacy-policy URL and the App Privacy answers (H14), and for the EU the trader declaration (H16).

In App Store Connect → the app → *Pricing and Availability* → countries and regions, keep **only the open markets** selected (start: none; open Brazil when H10 `pt-BR` and H11 Brazil are done, and each European country when its language is read, the European legal set is reviewed and H16 trader status is done). A market opens only when its language is read (H10) and its legal set is reviewed (H11); update `legal/STATUS.md` and the "Market readiness" table in `PROGRESS.md`. Waves and conditions: `16-MARKETS.md` §2.

### H16 · Individual account duties and release Xcode
1. **Seller name:** with an Individual account the App Store lists *Iago Xavier de Lima* as the seller. An Organization account (needs a D-U-N-S number and a legal entity) can be created later and the app transferred; decide before real revenue.
2. **EU trader status:** a seller of auto-renewing subscriptions to EU customers is normally a "trader" under the Digital Services Act and must provide and publish contact details in App Store Connect (*Business → Compliance*). Check with the accountant before opening any EU market (**wave 1**).
3. **Agreements and tax:** accept the Paid Apps agreement and fill in bank and tax information in App Store Connect before subscriptions can be tested in production. (This is Apple's payout for the subscription, the only money in the system, D4.)
4. **Xcode for uploads:** TestFlight and App Store uploads need a release version of Xcode. If `xcodebuild -version` shows a beta (D39), keep developing with it but install the matching release before uploading.

### H18 · Breach plan
Read `docs/BREACH-PLAN.md` once together. Decide who is on call, where the private incident log lives (not in the
repository), and keep a short email template for professionals ready (facts, data affected, what we did, what she can
do). A lawyer can turn the page into the formal procedure when H11 happens.


### H19 · Release-candidate checks on a real iPhone (S12)
The simulator cannot measure these; run them on the `v1.0.0-rc1` build (an iPhone 12-class device or newer, iOS 26+):
1. **VoiceOver pass**: `docs/agent-notes/accessibility-audit.md` section 3, in `en` then `pt-BR`, also with Increase
   Contrast, Reduce Motion and the largest text size. Note any stop that reads an identifier, a raw date or nothing.
2. **Performance** (`docs/13-TESTING-QUALITY.md` section 6): Instruments > Animation Hitches while scrolling the
   Clients list with 2,000 clients (`-uiTesting -uiPerfClients 2000` on a Debug build, or a real import), the week
   view with about 80 visits, and Tx-6-Photos with 200 photos (memory under 250 MB); cold start to Locked/Home on a
   Release build (budget 1.5 s); a 12 MP photo save (budget 800 ms). Simulator numbers of S12 are in `PROGRESS.md`.
3. **Apple Calendar** (More > Integrations): switch on, allow full access; a calendar "Bello Hub" appears with the
   week's visits titled "Bello Hub appointment"; turn on names on the lock screen (Privacy) and the titles become
   "Client · Service"; cancel a visit and its event goes; switch off and the calendar is gone.
4. Face ID unlock and the lock grace period, the camera in the treatment flow (photos never in the camera roll),
   contacts import, a push for a booking made on the web page, the recovery key restored on a second iPhone (H3).
**Expected:** findings written in `docs/PROGRESS.md` (Claude Code fixes them).

### H20 · Phone sign-in (decision)
D44 keeps the phone code as the alternative to Sign in with Apple, but the v1 Firebase provider does not send codes
(`FirebaseAuthProvider` answers `unavailable`), so since S12 the Welcome screen shows "Continue with phone" only on
builds whose provider can (the development provider). Choose: (a) v1 stays Apple only (nothing to do), or (b) Claude
Code wires Firebase phone auth (`PhoneAuthProvider`, the reCAPTCHA URL scheme from `GoogleService-Info.plist`, APNs
silent verification) and a person tests it on a real iPhone with a real number in an allow-listed country.

---

## Notes from Claude Code (kept current; humans tick, Claude Code does not)

**2026-10-08 · S0**
- **H1 verified.** `xcodebuild -allowProvisioningUpdates` for a device build succeeded with team `X5392U638Q` and produced the profile "iOS Team Provisioning Profile: com.bellohub" with iCloud/CloudKit container `iCloud.com.bellohub`, Push (`aps-environment`) and App Attest entitlements. Still for a person: add Mateus to the team, and confirm iCloud on a real device (H3).
- **H4 is only partly done.** `firebase projects:list` shows one project, `bello-hub`, not `bellohub-dev`, `bellohub-staging` and `bellohub-prod`. Steps for the owners: (1) create the `dev` and `staging` projects (and `prod` when ready) on the Blaze plan in the same Google account; (2) tell Claude Code the ids so it adds the aliases to `firebase/.firebaserc` and puts each `GoogleService-Info.plist` under `Config/Firebase/<Env>/`; (3) per project: Firestore `(default)` in `eur3` (Claude Code can run `firebase firestore:databases:create '(default)' --location=eur3 --project <id>` from `firebase/` once the project exists), the default Storage bucket in the **EU** location (console: Build > Storage > Get started; this Mac has no `gcloud`), plus the items already listed in H4 (Auth Phone with the SMS allow-list, APNs key, budgets, TTL policies, Secret Manager). Already done by Claude Code in `bello-hub`: Firestore `(default)` in `eur3` with deny-all rules.
- `TODO(HUMAN-H4)` marks: `firebase/.firebaserc` (aliases) and `firebase/storage.rules` (bucket).
- **H17 (new).** `gh auth login` on this Mac so Claude Code can open the pull requests at the end of each phase, and make sure the SSH key can push to `git@github.com:mfmansueli/BelloHub.git` (branch `build/v1`). Until then Claude Code pushes branches only and keeps the pull request text in `docs/PROGRESS.md`.
