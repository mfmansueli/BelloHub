//
//  QuickAccessItemTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Testing

@Suite("QuickAccessItem")
struct QuickAccessItemTests {
    @Test("Every item is in exactly one section, in the order the sheet shows")
    func sections() {
        let shown = QuickAccessItem.business + QuickAccessItem.preferences
        #expect(Set(shown) == Set(QuickAccessItem.allCases))
        #expect(shown.count == QuickAccessItem.allCases.count)
        #expect(QuickAccessItem.business.first == .bookingPage)
    }

    @Test("Each item opens its own screen of More, the last route of its path")
    func paths() {
        let screens = QuickAccessItem.allCases.compactMap(\.path.last)
        #expect(screens.count == QuickAccessItem.allCases.count)
        #expect(Set(screens).count == screens.count)
        #expect(QuickAccessItem.recordFields.path == [.recordTemplate])
    }

    @Test("Language and region opens under Account, as in More, so Back leads to Account")
    func languageUnderAccount() {
        #expect(QuickAccessItem.languageRegion.path == [.account, .languageRegion])
    }

    @Test("Identifiers are unique and follow screen.element.id")
    func identifiers() {
        let identifiers = QuickAccessItem.allCases.map(\.identifier)
        #expect(Set(identifiers).count == identifiers.count)
        #expect(QuickAccessItem.services.identifier == "home.quickAccess.services")
    }
}
