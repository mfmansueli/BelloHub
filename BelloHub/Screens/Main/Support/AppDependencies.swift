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
    let subscription: SubscriptionService
    let recoveryKey: RecoveryKeyService
    let account: AccountService
    let notificationSettings: NotificationSettingsService
    let calendar: CalendarIntegrationService
    let export: DataExportService
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
        let permissions = PermissionService()
        let subscription = SubscriptionService()
        return AppDependencies(
            session: SessionService(provider: AuthProviderFactory.make(defaults: defaults), defaults: defaults),
            keyManager: keyManager,
            appLock: AppLockService(keyManager: keyManager, defaults: defaults),
            permissions: permissions,
            vault: vault,
            profile: ProfileService(vault: vault),
            registration: ClientRegistrationService(vault: vault, subscription: subscription),
            bookingSetup: BookingSetupService(vault: vault),
            appointments: AppointmentService(vault: vault),
            subscription: subscription,
            recoveryKey: RecoveryKeyService(keyManager: keyManager, defaults: defaults),
            account: AccountService(vault: vault, keyManager: keyManager, keyStore: keyStore, defaults: defaults),
            notificationSettings: NotificationSettingsService(permissions: permissions, defaults: defaults),
            calendar: CalendarIntegrationService(defaults: defaults),
            export: DataExportService(vault: vault),
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
        let keyStore = InMemoryKeyStore(seed: uiTestSeed)
        let keyManager = KeyManager(store: keyStore)
        let vault = VaultService(repository: InMemoryClientRecordRepository())
        let mode = options.biometricsMode.flatMap(UITestBiometrics.Mode.init(rawValue:)) ?? .success
        let biometrics = UITestBiometrics(mode: mode)
        let permissions = PermissionService(provider: UITestPermissionProvider())
        let subscription = SubscriptionService(
            provider: UITestSubscriptionProvider(hasPlan: options.uiPlan == "active"),
            verifier: OfflineSubscriptionVerifier()
        )
        return AppDependencies(
            session: SessionService(provider: LocalDevAuthProvider(defaults: defaults), defaults: defaults),
            keyManager: keyManager,
            appLock: AppLockService(keyManager: keyManager, biometrics: biometrics, defaults: defaults),
            permissions: permissions,
            vault: vault,
            profile: ProfileService(vault: vault),
            registration: ClientRegistrationService(vault: vault, subscription: subscription),
            bookingSetup: BookingSetupService(vault: vault),
            appointments: AppointmentService(vault: vault),
            subscription: subscription,
            recoveryKey: RecoveryKeyService(keyManager: keyManager, biometrics: biometrics, defaults: defaults),
            account: AccountService(vault: vault, keyManager: keyManager, keyStore: keyStore, defaults: defaults),
            notificationSettings: NotificationSettingsService(permissions: permissions, defaults: defaults),
            calendar: CalendarIntegrationService(provider: UITestCalendarAccess(), defaults: defaults),
            export: DataExportService(vault: vault),
            defaults: defaults
        )
    }
    #endif
}
