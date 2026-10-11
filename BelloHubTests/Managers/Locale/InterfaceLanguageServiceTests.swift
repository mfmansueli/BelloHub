//
//  InterfaceLanguageServiceTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import SwiftUI
import Synchronization
import Testing

/// Records what the service hands to code outside the view tree, instead of the process-wide `InterfaceLocale`.
private final class MirroredLocale: Sendable {
    private let storage = Mutex<Locale?>(nil)

    var last: Locale? { storage.withLock { $0 } }

    func set(_ locale: Locale) { storage.withLock { $0 = locale } }
}

@Suite("InterfaceLanguageService")
@MainActor
struct InterfaceLanguageServiceTests {
    @MainActor
    private struct Rig {
        let suite: String
        let defaults: UserDefaults
        let system: UserDefaults
        let systemSuite: String

        init() {
            suite = "interface-tests-\(UUID().uuidString)"
            systemSuite = "interface-system-\(UUID().uuidString)"
            defaults = UserDefaults(suiteName: suite) ?? .standard
            system = UserDefaults(suiteName: systemSuite) ?? .standard
        }

        func clean() {
            defaults.removePersistentDomain(forName: suite)
            system.removePersistentDomain(forName: systemSuite)
        }

        let mirrored = MirroredLocale()

        /// What was written in the suite itself (a plain read would also see the simulator's global language list).
        var writtenLanguages: [String]? {
            system.persistentDomain(forName: systemSuite)?[InterfaceLanguageService.appleLanguagesKey] as? [String]
        }

        func service(appDomain: [String]? = nil, bundle: [String] = ["en"]) -> InterfaceLanguageService {
            InterfaceLanguageService(
                defaults: defaults, systemDefaults: system, appDomainLanguages: appDomain,
                systemLocalizations: { bundle }, device: Locale(identifier: "en_BR"), mirror: mirrored.set
            )
        }
    }

    @Test("A choice applies at once, is remembered and tells iOS for the next launch")
    func chooseApplies() {
        let rig = Rig()
        defer { rig.clean() }
        let service = rig.service()
        #expect(service.choice == .system)
        #expect(service.localization == .en)

        service.choose(.fixed(.ptPT))
        #expect(service.localization == .ptPT)
        #expect(AppLocalization(resolving: service.locale) == .ptPT)
        #expect(rig.mirrored.last.map(AppLocalization.init(resolving:)) == .ptPT)
        #expect(rig.defaults.string(forKey: DefaultsKey.interfaceLanguage) == "pt-PT")
        #expect(rig.writtenLanguages == ["pt-PT"])
        #expect(rig.service(appDomain: ["pt-PT"]).choice == .fixed(.ptPT))
        service.choose(.system)
    }

    @Test("Same as iPhone removes the override")
    func systemRemovesOverride() {
        let rig = Rig()
        defer { rig.clean() }
        let service = rig.service()
        service.choose(.fixed(.de))
        service.choose(.system)
        #expect(rig.writtenLanguages == nil)
        #expect(service.localization == .en)
        #expect(rig.defaults.string(forKey: DefaultsKey.interfaceLanguage) == "system")
    }

    @Test("Arabic turns the layout right to left")
    func arabicIsRightToLeft() {
        let rig = Rig()
        defer { rig.clean() }
        let service = rig.service()
        service.choose(.fixed(.ar))
        #expect(service.layoutDirection == .rightToLeft)
        service.choose(.fixed(.tr))
        #expect(service.layoutDirection == .leftToRight)
        service.choose(.system)
    }

    @Test("A change made later in iOS Settings is adopted at launch")
    func adoptsIOSSettings() {
        let rig = Rig()
        defer { rig.clean() }
        rig.service().choose(.fixed(.de))
        let relaunched = rig.service(appDomain: ["it"], bundle: ["it"])
        #expect(relaunched.choice == .fixed(.it))
        #expect(relaunched.localization == .it)
        relaunched.choose(.system)
    }

    @Test("Tests and UI-test launches never write the simulator's languages")
    func noSystemDefaultsNoWrite() {
        let rig = Rig()
        defer { rig.clean() }
        let service = InterfaceLanguageService(
            defaults: rig.defaults, systemDefaults: nil, systemLocalizations: { ["en"] },
            device: Locale(identifier: "en_US"), mirror: rig.mirrored.set
        )
        service.choose(.fixed(.hi))
        #expect(service.localization == .hi)
        #expect(rig.writtenLanguages == nil)
        service.choose(.system)
    }
}
