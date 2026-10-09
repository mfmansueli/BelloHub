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
    let outbound: OutboundQueue
    let bookingSync: BookingSyncService
    let mailbox: MailboxService
    let push: PushService
    let defaults: UserDefaults

    static func make(options: LaunchOptions = .current) -> AppDependencies {
        #if DEBUG
        if options.isUITesting { return makeForUITests(options: options) }
        #endif
        return makeLive()
    }

    private static func makeLive() -> AppDependencies {
        let defaults = UserDefaults.standard
        let keyManager = KeyManager()
        let vault = VaultService.live(keyManager: keyManager)
        let session = SessionService(provider: AuthProviderFactory.make(defaults: defaults), defaults: defaults)
        let tokens = SessionIDTokenProvider(session: session)
        let client = URLSessionCallableClient(tokens: tokens)
        let server = RemoteBookingRepository(client: client)
        let inbox = RemoteInboxRepository(client: client, firestore: URLSessionFirestoreClient(tokens: tokens))
        let profile = ProfileService(vault: vault)
        let permissions = PermissionService()
        let appointments = AppointmentService(vault: vault)
        let timeBlocks = TimeBlockService(vault: vault)
        let outbound = OutboundQueue(repository: inbox, defaults: defaults)
        let bookingSync = BookingSyncService(
            repository: inbox, queue: outbound, appointments: appointments, vault: vault, defaults: defaults
        )
        let mailbox = MailboxService(
            repository: inbox, keys: keyManager, vault: vault, queue: outbound, bookings: bookingSync,
            defaults: defaults
        )
        let pushProvider = FirebaseMessagingManager()
        PushBridge.shared.provider = pushProvider
        return AppDependencies(
            session: session,
            keyManager: keyManager,
            appLock: AppLockService(keyManager: keyManager, defaults: defaults),
            permissions: permissions,
            vault: vault,
            profile: profile,
            registration: ClientRegistrationService(vault: vault),
            bookingSetup: BookingSetupService(vault: vault),
            appointments: appointments,
            timeBlocks: timeBlocks,
            messages: MessageService(vault: vault),
            agendaDigest: AgendaDigestService(appointments: appointments, timeBlocks: timeBlocks, vault: vault),
            notifications: NotificationService(
                appointments: appointments, vault: vault, permissions: permissions, profile: profile
            ),
            treatmentTools: TreatmentTools.make(),
            publishing: PublishingService(
                repository: server, source: VaultPublishingSource(vault: vault, keys: keyManager), defaults: defaults
            ),
            outbound: outbound,
            bookingSync: bookingSync,
            mailbox: mailbox,
            push: PushService(provider: pushProvider, queue: outbound, bookings: bookingSync, mailbox: mailbox, defaults: defaults),
            defaults: defaults
        )
    }

    #if DEBUG
    /// A fixed seed, so the in-memory vault of a test launch is readable after a relaunch.
    static let uiTestSeed = Data(repeating: 0x42, count: 16)
    static let uiTestSuite = "app.bellohub.uitests"

    private static func makeForUITests(options: LaunchOptions) -> AppDependencies {
        let defaults = UserDefaults(suiteName: uiTestSuite) ?? .standard
        if !options.keepsState { defaults.removePersistentDomain(forName: uiTestSuite) }
        let keyManager = KeyManager(store: InMemoryKeyStore(seed: uiTestSeed))
        let vault = VaultService(repository: InMemoryClientRecordRepository())
        let profile = ProfileService(vault: vault)
        let permissions = PermissionService(provider: UITestPermissionProvider())
        let appointments = AppointmentService(vault: vault)
        let timeBlocks = TimeBlockService(vault: vault)
        let mode = options.biometricsMode.flatMap(UITestBiometrics.Mode.init(rawValue:)) ?? .success
        // No network in a UI test: either the in-memory fake server or none at all.
        let server: any BookingRepository = options.uiOnline == "fake"
            ? UITestBookingRepository() : OfflineBookingRepository()
        let inbox: any InboxRepository = options.uiInbox.flatMap(UITestInboxRepository.Scenario.init(rawValue:)).map {
            UITestInboxRepository(scenario: $0, publicKey: { try keyManager.inboxPrivateKey(generation: 1).publicKey })
        } ?? OfflineInboxRepository()
        let outbound = OutboundQueue(repository: inbox, defaults: defaults, retryDelays: [.seconds(2)])
        let bookingSync = BookingSyncService(
            repository: inbox, queue: outbound, appointments: appointments, vault: vault, defaults: defaults,
            pollInterval: nil
        )
        let mailbox = MailboxService(
            repository: inbox, keys: keyManager, vault: vault, queue: outbound, bookings: bookingSync,
            notifier: UITestNotificationPoster(), defaults: defaults
        )
        return AppDependencies(
            session: SessionService(provider: LocalDevAuthProvider(defaults: defaults), defaults: defaults),
            keyManager: keyManager,
            appLock: AppLockService(
                keyManager: keyManager, biometrics: UITestBiometrics(mode: mode), defaults: defaults
            ),
            permissions: permissions,
            vault: vault,
            profile: profile,
            registration: ClientRegistrationService(vault: vault),
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
                repository: server, source: VaultPublishingSource(vault: vault, keys: keyManager), defaults: defaults,
                debounce: .milliseconds(300), retryDelays: [.seconds(2)]
            ),
            outbound: outbound,
            bookingSync: bookingSync,
            mailbox: mailbox,
            push: PushService(
                provider: NoPushTokenProvider(), queue: outbound, bookings: bookingSync, mailbox: mailbox,
                defaults: defaults
            ),
            defaults: defaults
        )
    }
    #endif
}
