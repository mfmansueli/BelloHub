//
//  PrivacyViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("PrivacyViewModel and PrivacySummary")
struct PrivacyViewModelTests {
    private struct World {
        let lock: AppLockService
        let recoveryKey: RecoveryKeyService
        let notifications: NotificationSettingsService
        let legal: FakeLegalNoticeLibrary
        let viewModel: PrivacyViewModel
        let defaults: UserDefaults
        let suite: String
    }

    private func makeWorld(localization: AppLocalization = .ptBR, texts: [LegalNoticeText] = []) -> World {
        let suite = "privacy-vm-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        let keyManager = KeyManager(store: InMemoryKeyStore())
        let lock = AppLockService(keyManager: keyManager, biometrics: FakeBiometrics([.success]), defaults: defaults)
        let recoveryKey = RecoveryKeyService(
            keyManager: keyManager, biometrics: FakeBiometrics([.success]), defaults: defaults,
            now: { TestClock.now }
        )
        let notifications = NotificationSettingsService(
            store: FakeNotificationPrefsStore(), permissions: PermissionService(provider: FakePermissionProvider()),
            defaults: defaults
        )
        let legal = FakeLegalNoticeLibrary(texts)
        let viewModel = PrivacyViewModel(
            lock: lock, recoveryKey: recoveryKey, notifications: notifications, legal: legal,
            localization: localization
        )
        return World(
            lock: lock, recoveryKey: recoveryKey, notifications: notifications, legal: legal, viewModel: viewModel,
            defaults: defaults, suite: suite
        )
    }

    private func text(_ notice: LegalNotice, _ localization: String) -> LegalNoticeText {
        LegalNoticeText(notice: notice, localization: localization, version: "2026-10", status: "draft",
                        body: "Body \(localization)")
    }

    @Test("The lock switch and the grace period write through to the lock service")
    func lock() {
        let world = makeWorld()
        defer { world.defaults.removePersistentDomain(forName: world.suite) }
        let viewModel = world.viewModel
        #expect(viewModel.lockEnabled, "on by default")

        viewModel.setLockEnabled(false)
        #expect(!viewModel.lockEnabled)
        #expect(!world.lock.isEnabled)

        viewModel.setGraceSeconds(300)
        #expect(viewModel.graceSeconds == 300)
        viewModel.setGraceSeconds(45)
        #expect(LockPolicy.graceOptions.contains(viewModel.graceSeconds), "an unknown value becomes a known one")
        #expect(viewModel.graceOptions == LockPolicy.graceOptions)
    }

    @Test("Hiding names on the lock screen is on by default and stored when switched")
    func hideNames() {
        let world = makeWorld()
        defer { world.defaults.removePersistentDomain(forName: world.suite) }

        #expect(world.viewModel.hideNames)
        world.viewModel.setHideNames(false)
        #expect(!world.viewModel.hideNames)
        #expect(world.defaults.object(forKey: DefaultsKey.hideNamesOnLockScreen) as? Bool == false)
    }

    @Test("The recovery key line says not saved until she confirms, then the date")
    func recoveryLine() {
        let world = makeWorld()
        defer { world.defaults.removePersistentDomain(forName: world.suite) }
        let formatters = Formatters(locale: Locale(identifier: "en_US"), timeZone: .current, currencyCode: "USD")

        #expect(PrivacySummary.recoveryLine(world.viewModel.recoveryStatus, formatters: formatters) == .notSaved)
        world.recoveryKey.markSaved()
        #expect(PrivacySummary.recoveryLine(world.viewModel.recoveryStatus, formatters: formatters)
            == .saved(dateText: formatters.shortDate(TestClock.now)))
    }

    @Test("Legal texts open in her language, fall back to English, and a missing one explains")
    func legal() {
        let world = makeWorld(localization: .ptBR, texts: [
            text(.termsAndDPA, "pt-BR"), text(.termsAndDPA, "en"), text(.privacyPolicy, "en")
        ])
        defer { world.defaults.removePersistentDomain(forName: world.suite) }
        let viewModel = world.viewModel

        viewModel.open(.termsAndDPA)
        #expect(viewModel.openedNotice?.localization == "pt-BR")
        viewModel.open(.privacyPolicy)
        #expect(viewModel.openedNotice?.localization == "en")
        #expect(world.legal.requests == ["terms-dpa-pt-BR", "privacy-policy-pt-BR"])
        viewModel.closeNotice()
        #expect(viewModel.openedNotice == nil)

        let empty = makeWorld()
        defer { empty.defaults.removePersistentDomain(forName: empty.suite) }
        empty.viewModel.open(.privacyPolicy)
        #expect(empty.viewModel.openedNotice == nil)
        #expect(empty.viewModel.legalErrorMessage != nil)
    }

    @Test("Every grace option has a label key and the bundled terms and policy exist in all fourteen localizations")
    func keysAndBundle() throws {
        for seconds in LockPolicy.graceOptions {
            #expect(PrivacySummary.graceKey(seconds).hasPrefix("privacy.lockAfter."))
        }
        let library = BundleLegalNoticeLibrary()
        for localization in AppLocalization.allCases {
            for notice in LegalNotice.allCases {
                let text = try library.latest(notice, localization: localization)
                #expect(text.localization == localization.rawValue, "\(notice) \(localization)")
                #expect(!text.body.isEmpty)
                #expect(!text.body.hasPrefix("---"), "the header never reaches the screen")
            }
        }
    }
}
