//
//  NotificationSettingsServiceTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("NotificationSettingsService")
struct NotificationSettingsServiceTests {
    private func makeService(defaults: UserDefaults) -> NotificationSettingsService {
        let permissions = PermissionService(provider: FakePermissionProvider(answers: [.notifications: .granted]))
        return NotificationSettingsService(permissions: permissions, defaults: defaults)
    }

    @Test("Without an explicit store the switches live in the given defaults suite, never in the standard one")
    func storeFollowsTheDefaultsSuite() throws {
        let suite = "notification-service-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        var prefs = NotificationPrefs.standard
        prefs.dailySummary = true
        try makeService(defaults: defaults).save(prefs)

        #expect(defaults.data(forKey: DefaultsKey.notificationPrefs) != nil)
        #expect(makeService(defaults: defaults).prefs.dailySummary)
        let fresh = try #require(UserDefaults(suiteName: "\(suite)-other"))
        defer { fresh.removePersistentDomain(forName: "\(suite)-other") }
        #expect(makeService(defaults: fresh).prefs == .standard)
    }
}
