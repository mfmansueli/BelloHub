# 04 · Architecture for this product

The repo's `CLAUDE.md` defines the rules (MVVM + Services, Observation, Swift 6, folders, naming, one type per file, design system, tests, scripts, zero warnings). This document says **how they apply to Bello Hub**: which services exist, which protocols guard which boundary, and where things go. If anything here conflicts with `CLAUDE.md`, `CLAUDE.md` wins.

## 1. The three data boundaries

```
                 iPhone (the professional)                               The cloud                      Any browser (the client)
 ┌──────────────────────────────────────────────────┐   ┌─────────────────────────────┐   ┌─────────────────────────────┐
 │ Views ─ ViewModels ─ Services                    │   │ Firebase                    │   │ Preact web app              │
 │            │                                      │   │  Firestore  (operational)   │   │  booking, portal, forms     │
 │            ├─ ClientRecordRepository ──▶ Vault ──▶ SwiftData + CloudKit (her iCloud)  │   │  seals sensitive answers    │
 │            ├─ BookingRepository ───────────────────▶ Functions / Firestore / Storage ◀──▶ with her public key        │
 │            ├─ MailboxService ──(HPKE open)─────────▶ sealed envelopes (opaque)        │   └─────────────────────────────┘
 │            └─ system managers (Speech, AI, Camera, StoreKit, Notifications, EventKit)  │
 └──────────────────────────────────────────────────┘   └─────────────────────────────┘
```

- **Boundary 1, the vault:** `ClientRecordRepository` is the only door to SwiftData/CloudKit and the only place that encrypts and decrypts sensitive fields. Nothing outside `Managers/Persistence/` imports `SwiftData` or `CloudKit`.
- **Boundary 2, the server:** `BookingRepository` is the only door to Firebase. Nothing outside `Managers/Booking/` imports a `Firebase*` module. The SDK is swappable (D3).
- **Boundary 3, the mailbox:** `MailboxService` is the only code that holds the inbox private key during decryption, using `KeyManager`.

## 2. Folder tree (extends `CLAUDE.md` §3)

```
BelloHub/
├── BelloHub/
│   ├── DesignSystem/
│   │   ├── Tokens/        Palette, StatusPalette, AvatarPalette, Typography, Spacing, Radius, Elevation, Motion
│   │   ├── Fonts/         Fraunces-VF.ttf, DMSans-VF.ttf (+ OFL license files)
│   │   ├── Styles/        BelloButtonStyle (+ Variant), BelloToggleStyle?, chip styles
│   │   ├── Components/    Card, ListCard, InsightTile, HeroCard, Avatar, StatusChip, SectionHeader, EmptyState, InlineNotice, Skeleton, OfflineBanner, SuccessSeal
│   │   ├── Motion/        StaggerModifier, PressStyle, HeroGlow, SheetScrim, SuccessDraw
│   │   └── Backgrounds/
│   ├── Models/            pure domain structs/enums (Client, Appointment, Service, Policy, Money, …)
│   ├── Managers/
│   │   ├── Persistence/   ClientRecordRepository.swift, SwiftDataClientRecordRepository.swift, InMemoryClientRecordRepository.swift (tests target holds the fake? see §6), Schema/ (@Model types), Migration/
│   │   ├── Vault/         KeyManager, KeychainKeyStore, SecretBox, RecoveryPhrase (+ Bip39Wordlist), VaultFieldCodec
│   │   ├── Booking/       BookingRepository.swift, RemoteBookingRepository.swift (Firebase), BookingSyncService, OutboundQueue, SlugService
│   │   ├── Mailbox/       MailboxService, SealedEnvelope, IntakePayload, HPKEBox
│   │   ├── Session/       SessionService, AuthProvider, FirebaseAuthProvider, LocalDevAuthProvider (#if DEBUG)
│   │   ├── Sync/          SyncStatusService
│   │   ├── Speech/        SpeechTranscriber (protocol), AppleSpeechTranscriber
│   │   ├── AI/            RecordStructuringService (protocol), FoundationModelsStructuringService, AvailabilityProbe
│   │   ├── Photos/        PhotoPipeline, PhotoStore
│   │   ├── Messaging/     WhatsAppLauncher, MessageComposer, MessageTemplateStore
│   │   ├── Notifications/ NotificationScheduler, PushRouter
│   │   ├── Calendar/      CalendarBridge (EventKit)
│   │   ├── Store/         SubscriptionService (StoreKit 2)
│   │   ├── Export/        RecordPDFRenderer, DataExportService
│   │   ├── Locale/        LocaleSettingsService, Formatters (date, time, money, phone), WeekConfig, RegionCatalog, PhoneNormalizer, DigitNormalizer, BidiIsolate
│   │   └── Config/        AppConfig (env, base URL, flags), FeatureFlags
│   ├── Screens/
│   │   ├── Main/          RootView, MainView, Support/ (routing, tab selection)
│   │   ├── Shared/        Concept folders used by several features (e.g. ClientPicker, ServicePicker, ReminderQueue)
│   │   ├── Onboarding/ Home/ Clients/ ClientProfile/ Calendar/ Appointments/ Treatment/ Business/ Policies/ Account/ Privacy/ Notifications/
│   └── SupportFiles/      BelloHubApp, AppDelegate (UIApplicationDelegateAdaptor for push), LaunchOptions, BelloHub.entitlements, PrivacyInfo.xcprivacy, Localizable.xcstrings, InfoPlist.xcstrings, Assets.xcassets
├── BelloHubTests/         Fakes/ (Fake*, InMemory*), mirrors the app folders, Vectors/ (crypto test vectors)
├── BelloHubUITests/       one file per user flow
├── Config/                *.xcconfig (+ Config/Firebase/{Dev,Staging,Prod}/GoogleService-Info.plist), TestPlans/
├── firebase/              firebase.json, firestore.rules, firestore.indexes.json, storage.rules, functions/ (TS), emulator tests
├── web/                   the Preact client app (src/, test/, vectors/, vite.config.ts)
├── scripts/               existing wrappers + e2e-local.sh, check-strings.sh, fetch-fonts.sh, fetch-wordlist.sh
├── docs/  design/         this handoff (do not edit design/; edit docs/ only to record progress and decisions)
└── CLAUDE.md DESIGN.md README.md
```

`CLAUDE.md` says fakes live only in the tests target (`Fake<Entity>Repository`). `InMemoryClientRecordRepository` is also used by SwiftUI previews and DEBUG launch modes, so it lives in the **app** target under `#if DEBUG` in `Managers/Persistence/`; `Fake*` stay in `BelloHubTests/Fakes/`.

## 3. Protocols (the contract surface)

Signatures are guidance; keep the intent. Every protocol is in its own file next to its implementation (one type per file).

```swift
protocol ClientRecordRepository: Sendable {       // boundary 1
    func clients() -> AsyncStream<[Client]>
    func client(id: Client.ID) async throws -> Client?
    func save(_ client: Client) async throws
    func appointments(in range: DateInterval) -> AsyncStream<[Appointment]>
    func save(_ appointment: Appointment) async throws
    func save(_ draft: TreatmentRecordDraft) async throws -> TreatmentRecord          // sets lockedAt = createdAt + 24h
    func addCorrection(_ c: RecordCorrectionDraft, to id: TreatmentRecord.ID) async throws
    func photo(id: Photo.ID) async throws -> PhotoData                               // decrypts
    func importIntake(_ intake: IntakePayload, itemID: String) async throws          // idempotent by itemID
    func deleteClient(id: Client.ID) async throws                                    // cascades locally
    func exportSnapshot() async throws -> ExportSnapshot
    // … one method per use case; no generic "fetch with predicate" leaking SwiftData types
}

protocol BookingRepository: Sendable {            // boundary 2
    func publish(profile: PublicProfile) async throws
    func publish(availability: AvailabilitySnapshot) async throws
    func isSlugAvailable(_ slug: String) async throws -> Bool
    func bookings() -> AsyncStream<[IncomingBooking]>
    func respond(to request: BookingRequestResponse) async throws
    func rescheduleRequests() -> AsyncStream<[RescheduleRequest]>
    func waitlist() -> AsyncStream<[WaitlistItem]>
    func mailboxItems() async throws -> [MailboxItem]
    func acknowledgeMailboxItem(_ id: String) async throws
    func registerDevice(pushToken: Data) async throws
    func requestDataExport() async throws
    func deleteServerData() async throws
}

protocol AuthProvider: Sendable {                 // phone sign-in of the professional
    func requestCode(phoneE164: String) async throws
    func verify(code: String) async throws -> AuthUser
    func signOut() throws
}

protocol SpeechTranscriber { /* start(locale:) -> AsyncThrowingStream<TranscriptChunk>, stop(), supports(locale:) */ }
protocol RecordStructuringService { /* availability(for locale:) , structure(transcript:, template:) async throws -> StructuredRecord */ }
protocol WhatsAppLaunching { /* canOpen, open(phoneE164:, text:) */ }
protocol NotificationScheduling { /* schedule(_ plan:), cancelAll(for:) */ }
protocol CalendarBridging { /* requestAccess(), write(appointment), remove(appointment) */ }
protocol SubscriptionProviding { /* entitlement stream, purchase, restore */ }
protocol KeyStoring { /* load/save/delete seed material in iCloud Keychain */ }
```

Rules:
- A real implementation is the **default argument** of the Service/ViewModel `init`; tests pass fakes.
- ViewModels never call a repository from `body`; they expose state and actions (`CLAUDE.md` §2).
- Streams (`AsyncStream`) are started/stopped by `startListening()` / `stopListening()` pairs on the owning Service (`CLAUDE.md` §2).
- **Offline first.** Every write to the vault is local and immediate. Every write that must reach the server goes through `OutboundQueue` (persistent, idempotent ids, exponential backoff, ordered per aggregate). The UI shows `SyncStatus` and never blocks on the network except where noted (sign-in, slug check, plan purchase).

## 4. Services and where they are created

| Scope | Created in | Services |
|---|---|---|
| App session | `RootView` (`@State`, `.environment`) | `SessionService`, `AppConfig`, `FeatureFlags`, `LocaleSettingsService`, `KeyManager`, `SyncStatusService`, `SubscriptionService` |
| Signed-in user | `MainView` | `ClientRecordRepository` (via a `VaultService` facade if useful), `BookingSyncService`, `MailboxService`, `NotificationScheduler`, `PushRouter`, `CalendarBridge`, `MessageComposer`, `PhotoPipeline`, `AvailabilityProbe` |

One `SessionService` owns the current professional (uid, phone, slug). No view reads an SDK for the user.

All `UserDefaults` keys in `enum DefaultsKey`. Secrets, key material and tokens in Keychain only.

## 5. Navigation

- `RootView` is the state gate `onboarding → login → setup → locked → app` (`@AppStorage` flags).
- `MainView` is the system `TabView` with **five tabs: Home, Clients, Calendar, Alerts, More** (prototype names; localize). On iOS 26 the system tab bar is the floating glass bar the prototype imitates; **do not build the custom pill** (`CLAUDE.md` §2). Style with `.tint`, the accent from `Palette`, and SF Symbols chosen to match the prototype icons.
- Each tab owns a `NavigationStack` with a **typed `Route` enum per tab** and a `NavigationPath`. Secondary flows are sheets; success/celebration and media viewers are `fullScreenCover`.
- Deep links from push: `AppDelegate` posts a `Notification.Name`, `PushRouter` maps `{kind, id}` to a `Route`. Payloads carry only ids (no names, no health data).
- The multi-screen flows from the prototype (Onboarding, Tx-1…Tx-5, new appointment) are **one ViewModel per flow** with a step enum, so state survives back/forward and process death (persist drafts to the vault, not UserDefaults).
- Prototype "sheets" are native sheets with detents. Do not reproduce the 30 pt custom radius; use the system's. Keep the handle, title and content layout.

## 6. Concurrency (Swift 6)

- `@MainActor` on every ViewModel and UI-facing Service. Delegate callbacks are `nonisolated` and hop with `Task { @MainActor in … }`.
- SwiftData work runs in a `@ModelActor`; the repository maps `@Model` types to `Sendable` domain structs before returning them. Never pass `@Model` instances across actors.
- `PhotoPipeline`, `SecretBox`, crypto and PDF rendering are `actor`s or `nonisolated` pure functions on `Sendable` values.
- No `DispatchQueue`. No `Task.sleep` for synchronization in tests (use `Wait.until`, `CLAUDE.md` §6).

## 7. Configuration, environments, flags

- `Config/*.xcconfig` only (never `project.pbxproj`). Add `Config/Dev.xcconfig`, `Staging.xcconfig`, `Prod.xcconfig` layered over `Project.xcconfig`, exposing via `Info.plist` keys: `BELLO_ENV`, `BELLO_WEB_BASE_URL`, `BELLO_FIREBASE_PLIST`. `AppConfig` reads them.
- Firebase config files per environment under `Config/Firebase/<Env>/GoogleService-Info.plist`; a build phase script (or a single `FirebaseApp.configure(options:)` call that loads the plist chosen by `AppConfig`) selects the right one. Do not commit service-account keys (client plists are not secrets).
- Feature flags (`FeatureFlags`): `cloudAssist` (always false in v1, D23), `whatsAppAutomation` (D31, from Remote Config), `googleCalendar` (false), `teamPlan` (false). Defaults compiled in; Remote Config may override; the app works offline with the defaults.
- Launch arguments (DEBUG only, parsed once in `SupportFiles/LaunchOptions.swift`): `-uiTesting`, `-uiSeed <fixture>`, `-uiLocale <id>`, `-uiOffline`, `-uiICloudFull`, `-uiNoAI`, `-uiLocked`, `-uiTimeTravel <ISO8601>`, `-designCatalog`. Fixtures come from the prototype's demo data (`design/PROTOTYPE-NOTES.md`).

## 8. Dependencies

Allowed third-party: **`firebase-ios-sdk`** (Auth, Firestore, Functions, Messaging, AppCheck, Storage; nothing else, **no Analytics, no Crashlytics in v1** so that no client text can leak; use MetricKit and `os.Logger` instead). Everything else is Apple frameworks: `SwiftData`, `CloudKit`, `CryptoKit` (HPKE), `Security`, `LocalAuthentication`, `Speech`, `FoundationModels`, `AVFoundation`, `PhotosUI`, `Contacts`, `EventKit`, `StoreKit`, `PDFKit`, `CoreImage`, `UserNotifications`, `MetricKit`.

Add the SDK through Swift Package Manager (this changes `project.pbxproj` package references only; build settings stay in xcconfig). Pin exact versions and record them in `PROGRESS.md`.

## 9. Errors, logging, privacy in code

- A typed `BelloError` hierarchy per boundary with user-facing localized messages that say what happened and how to fix it (`01-PRODUCT.md` voice). Never show `error.localizedDescription` from an SDK.
- `os.Logger` with categories; interpolated values default to `.private`; **never log** names, phones, health answers, notes, transcripts, photo metadata. A SwiftLint custom rule bans `print(` and `NSLog(` outside `#if DEBUG` tools.
- Screenshots in the app switcher are blurred (`scenePhase` + overlay) and the Locked state hides content (D34).
- No analytics in v1. If Mateus later wants any, it goes behind `AnalyticsService` with an allow-list of event names and no free text.

## 10. Prototype → code mapping rules

- A prototype **screen** is a View (+ ViewModel when it has state or IO). A prototype **`hubState` key** (state that flows between screens, e.g. `CancelPolicy`, `BookingSettings`, `LanguageRegion`) is a **domain value owned by a repository or service**, not a global.
- Prototype demo data is **fixtures** for previews and UI tests only. Never ship it as default content.
- Prototype strings are English source; keys are semantic (`home.nextUp.title`). Every View uses the String Catalog (`07-LOCALIZATION.md`).
- Where the prototype uses a custom control that iOS 26 provides natively (tab bar, sheets, switches, menus, date/time pickers, toolbars), use the native control and style it with tokens (`CLAUDE.md` §4).
