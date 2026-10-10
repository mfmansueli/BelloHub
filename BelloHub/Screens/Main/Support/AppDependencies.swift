//
//  AppDependencies.swift
//  BelloHub
//

import Foundation

/// The Services of the app session, built in one place so `RootView` creates them once and distributes them with
/// `.environment(...)`. UI-test launches get in-memory versions; nothing else about the app changes.
@MainActor
struct AppDependencies {
    let session: SessionService
    let keyManager: KeyManager
    let appLock: AppLockService
    let permissions: PermissionService
    let vault: VaultService
    let profile: ProfileService
    let registration: ClientRegistrationService
    let bookingSetup: BookingSetupService
    let appointments: AppointmentService
    let timeBlocks: TimeBlockService
    let messages: MessageService
    let agendaDigest: AgendaDigestService
    let notifications: NotificationService
    let treatmentTools: TreatmentTools
    let publishing: PublishingService
    let subscription: SubscriptionService
    let recoveryKey: RecoveryKeyService
    let account: AccountService
    let notificationSettings: NotificationSettingsService
    let calendar: CalendarIntegrationService
    let export: DataExportService
    let inbox: InboxServices
    let defaults: UserDefaults

    static func make(options: LaunchOptions = .current) -> AppDependencies {
        #if DEBUG
        if options.isUITesting { return makeForUITests(options: options) }
        #endif
        return makeLive()
    }

    private static func makeLive() -> AppDependencies {
        let defaults = UserDefaults.standard
        let keyStore = KeychainKeyStore()
        let keyManager = KeyManager(store: keyStore)
        let vault = VaultService.live(keyManager: keyManager)
        let session = SessionService(provider: AuthProviderFactory.make(defaults: defaults), defaults: defaults)
        let tokens = SessionIDTokenProvider(session: session)
        let client = URLSessionCallableClient(tokens: tokens)
        let profile = ProfileService(vault: vault)
        let permissions = PermissionService()
        let appointments = AppointmentService(vault: vault)
        let timeBlocks = TimeBlockService(vault: vault)
        let subscription = makeLiveSubscription(client: client, profile: profile)
        let inbox = InboxServices.make(
            repository: RemoteInboxRepository(client: client, firestore: URLSessionFirestoreClient(tokens: tokens)),
            keys: keyManager, vault: vault, appointments: appointments, pushProvider: makePushProvider()
        )
        return AppDependencies(
            session: session,
            keyManager: keyManager,
            appLock: AppLockService(keyManager: keyManager, defaults: defaults),
            permissions: permissions,
            vault: vault,
            profile: profile,
            registration: ClientRegistrationService(vault: vault, subscription: subscription),
            bookingSetup: BookingSetupService(vault: vault),
            appointments: appointments,
            timeBlocks: timeBlocks,
            messages: MessageService(vault: vault),
            agendaDigest: AgendaDigestService(appointments: appointments, timeBlocks: timeBlocks, vault: vault),
            notifications: NotificationService(
                appointments: appointments, vault: vault, permissions: permissions, profile: profile,
                prefs: DefaultsNotificationPrefsStore(defaults: defaults)
            ),
            treatmentTools: TreatmentTools.make(),
            publishing: PublishingService(
                repository: RemoteBookingRepository(client: client),
                source: VaultPublishingSource(vault: vault, keys: keyManager), defaults: defaults
            ),
            subscription: subscription,
            recoveryKey: RecoveryKeyService(keyManager: keyManager, defaults: defaults),
            account: AccountService(
                vault: vault, keyManager: keyManager, keyStore: keyStore, deleter: makeAccountDeleter(client: client),
                defaults: defaults
            ),
            notificationSettings: NotificationSettingsService(permissions: permissions, defaults: defaults),
            calendar: CalendarIntegrationService(defaults: defaults),
            export: DataExportService(vault: vault),
            inbox: inbox,
            defaults: defaults
        )
    }

    /// StoreKit for the purchase, the server for the verdict (`ensureAccount` for the account token, `syncPlan` for the
    /// plan); the profile gives the region and language of a server account created at the first purchase.
    private static func makeLiveSubscription(
        client: any CallableClient, profile: ProfileService
    ) -> SubscriptionService {
        let verifier = RemoteSubscriptionVerifier(
            client: client, accounts: RemoteBookingRepository(client: client), profile: { await profile.profile }
        )
        return SubscriptionService(provider: StoreKitSubscriptionProvider(), verifier: verifier)
    }

    /// The server deletes her account. A `-devLogin` run (DEBUG) carries a fake token the server rightly refuses, so it
    /// clears only the iPhone, as a UI test does.
    private static func makeAccountDeleter(client: any CallableClient) -> any AccountDeleting {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-devLogin") { return OfflineAccountDeleter() }
        #endif
        return RemoteAccountDeleter(client: client)
    }

    /// The Firebase Messaging token source, also handed to `PushBridge` because the AppDelegate (outside the view
    /// tree) forwards the APNs token to it.
    private static func makePushProvider() -> FirebaseMessagingManager {
        let provider = FirebaseMessagingManager()
        PushBridge.shared.provider = provider
        return provider
    }

    #if DEBUG
    /// A fixed seed, so the in-memory vault of a test launch is readable after a relaunch.
    static let uiTestSeed = Data(repeating: 0x42, count: 16)
    static let uiTestSuite = "app.bellohub.uitests"

    private static func makeForUITests(options: LaunchOptions) -> AppDependencies {
        let defaults = UserDefaults(suiteName: uiTestSuite) ?? .standard
        if !options.keepsState { defaults.removePersistentDomain(forName: uiTestSuite) }
        let keyStore = InMemoryKeyStore(seed: uiTestSeed)
        let keyManager = KeyManager(store: keyStore)
        let vault = VaultService(repository: InMemoryClientRecordRepository())
        let profile = ProfileService(vault: vault)
        let permissions = PermissionService(provider: UITestPermissionProvider())
        let appointments = AppointmentService(vault: vault)
        let timeBlocks = TimeBlockService(vault: vault)
        let mode = options.biometricsMode.flatMap(UITestBiometrics.Mode.init(rawValue:)) ?? .success
        let biometrics = UITestBiometrics(mode: mode)
        let subscription = SubscriptionService.preview(hasPlan: options.uiPlan == "active")
        let inbox = makeUITestInbox(
            options: options, keyManager: keyManager, vault: vault, appointments: appointments, defaults: defaults
        )
        return AppDependencies(
            session: SessionService(provider: LocalDevAuthProvider(defaults: defaults), defaults: defaults),
            keyManager: keyManager,
            appLock: AppLockService(keyManager: keyManager, biometrics: biometrics, defaults: defaults),
            permissions: permissions,
            vault: vault,
            profile: profile,
            registration: ClientRegistrationService(vault: vault, subscription: subscription),
            bookingSetup: BookingSetupService(vault: vault),
            appointments: appointments,
            timeBlocks: timeBlocks,
            messages: MessageService(vault: vault, sender: UITestMessageSender()),
            agendaDigest: AgendaDigestService(appointments: appointments, timeBlocks: timeBlocks, vault: vault),
            notifications: NotificationService(
                appointments: appointments, vault: vault, permissions: permissions, profile: profile,
                prefs: DefaultsNotificationPrefsStore(defaults: defaults), scheduler: UITestNotificationScheduler()
            ),
            treatmentTools: TreatmentTools.make(),
            publishing: PublishingService(
                repository: uiTestBookingServer(options: options),
                source: VaultPublishingSource(vault: vault, keys: keyManager), defaults: defaults,
                debounce: .milliseconds(300), retryDelays: [.seconds(2)]
            ),
            subscription: subscription,
            recoveryKey: RecoveryKeyService(keyManager: keyManager, biometrics: biometrics, defaults: defaults),
            account: AccountService(
                vault: vault, keyManager: keyManager, keyStore: keyStore, deleter: OfflineAccountDeleter(),
                defaults: defaults
            ),
            notificationSettings: NotificationSettingsService(permissions: permissions, defaults: defaults),
            calendar: CalendarIntegrationService(provider: UITestCalendarAccess(), defaults: defaults),
            export: DataExportService(vault: vault),
            inbox: inbox,
            defaults: defaults
        )
    }

    /// No network in a UI test: either the in-memory fake server (`-uiOnline fake`) or none at all.
    private static func uiTestBookingServer(options: LaunchOptions) -> any BookingRepository {
        options.uiOnline == "fake" ? UITestBookingRepository() : OfflineBookingRepository()
    }

    /// The inbox of a UI-test launch: the in-memory inbox server when `-uiInbox` names a scenario, none otherwise.
    private static func makeUITestInbox(
        options: LaunchOptions, keyManager: KeyManager, vault: VaultService, appointments: AppointmentService,
        defaults: UserDefaults
    ) -> InboxServices {
        let inbox: any InboxRepository = options.uiInbox.flatMap(UITestInboxRepository.Scenario.init(rawValue:)).map {
            UITestInboxRepository(scenario: $0, publicKey: { try keyManager.currentInboxPublicKey() })
        } ?? OfflineInboxRepository()
        return InboxServices.make(
            repository: inbox, keys: keyManager, vault: vault, appointments: appointments,
            pushProvider: NoPushTokenProvider(), defaults: defaults, retryDelays: [.seconds(2)], pollInterval: nil,
            notifier: UITestNotificationPoster()
        )
    }
    #endif
}
