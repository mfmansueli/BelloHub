//
//  TimeZoneNoticeServiceTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("TimeZoneNoticeService")
struct TimeZoneNoticeServiceTests {
    private let pair = TimeZoneMismatch.Pair(businessZoneID: "America/Sao_Paulo", phoneZoneID: "Europe/Rome")

    private func makeDefaults() -> (UserDefaults, String) {
        let suite = "test.timeZoneNotice.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suite) ?? .standard, suite)
    }

    private func makeService(defaults: UserDefaults, zone: MutablePhoneZone) -> TimeZoneNoticeService {
        TimeZoneNoticeService(defaults: defaults, regions: RegionCatalog(presets: []), phoneZone: { zone.zone })
    }

    @Test("Keep it is stored per user and read back on the next unlock")
    func keepIsStoredPerUser() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let zone = MutablePhoneZone("Europe/Rome")
        let service = makeService(defaults: defaults, zone: zone)

        service.start(userID: "maria")
        #expect(service.kept == nil)
        service.keep(pair)
        #expect(service.kept == pair)
        #expect(defaults.data(forKey: DefaultsKey.timeZoneNoticeKept + ".maria") != nil)

        service.stop()
        #expect(service.kept == nil, "a lock forgets it in memory")
        service.start(userID: "ana")
        #expect(service.kept == nil, "another professional on this iPhone was never asked")
        service.stop()

        let relaunched = makeService(defaults: defaults, zone: zone)
        relaunched.start(userID: "maria")
        #expect(relaunched.kept == pair)
        relaunched.stop()
    }

    @Test("Keep it before the session started stores nothing")
    func keepWithoutUser() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let service = makeService(defaults: defaults, zone: MutablePhoneZone("Europe/Rome"))
        service.keep(pair)
        #expect(service.kept == nil)
        #expect(defaults.dictionaryRepresentation().keys.allSatisfy { !$0.hasPrefix(DefaultsKey.timeZoneNoticeKept) })
    }

    @Test("The iPhone's zone is read at start, on refresh, and when iOS says it changed")
    func followsThePhoneZone() async {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let zone = MutablePhoneZone("Europe/Rome")
        let service = makeService(defaults: defaults, zone: zone)
        #expect(service.phoneZoneID == "Europe/Rome")

        zone.set("Asia/Tokyo")
        service.refreshPhoneZone()
        #expect(service.phoneZoneID == "Asia/Tokyo")

        service.start(userID: "maria")
        defer { service.stop() }
        zone.set("America/New_York")
        // The listener is a task: post until it has subscribed and answered, never a fixed wait.
        let followed = await Wait.untilMain {
            NotificationCenter.default.post(name: .NSSystemTimeZoneDidChange, object: nil)
            return service.phoneZoneID == "America/New_York"
        }
        #expect(followed)
    }

    @Test("Account deletion removes what she kept")
    func clearedWithTheAccount() {
        #expect(DefaultsKey.prefixesClearedOnAccountDeletion.contains(DefaultsKey.timeZoneNoticeKept))
    }
}
