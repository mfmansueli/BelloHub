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
        return AppDependencies(
            session: SessionService(provider: AuthProviderFactory.make(defaults: defaults), defaults: defaults),
            keyManager: keyManager,
            appLock: AppLockService(keyManager: keyManager, defaults: defaults),
            permissions: PermissionService(),
            vault: vault,
            profile: ProfileService(vault: vault),
            registration: ClientRegistrationService(vault: vault),
            bookingSetup: BookingSetupService(vault: vault),
            appointments: AppointmentService(vault: vault),
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
        let mode = options.biometricsMode.flatMap(UITestBiometrics.Mode.init(rawValue:)) ?? .success
        return AppDependencies(
            session: SessionService(provider: LocalDevAuthProvider(defaults: defaults), defaults: defaults),
            keyManager: keyManager,
            appLock: AppLockService(
                keyManager: keyManager, biometrics: UITestBiometrics(mode: mode), defaults: defaults
            ),
            permissions: PermissionService(provider: UITestPermissionProvider()),
            vault: vault,
            profile: ProfileService(vault: vault),
            registration: ClientRegistrationService(vault: vault),
            bookingSetup: BookingSetupService(vault: vault),
            appointments: AppointmentService(vault: vault),
            defaults: defaults
        )
    }
    #endif
}
