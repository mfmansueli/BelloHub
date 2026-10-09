//
//  IntegrationsSummaryTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Testing

@Suite("IntegrationsSummary")
struct IntegrationsSummaryTests {
    @Test("Apple Calendar reads connected only with the switch on and the access granted")
    func appleCalendar() {
        #expect(IntegrationsSummary.appleCalendarState(access: .full, enabled: true) == .connected)
        #expect(IntegrationsSummary.appleCalendarState(access: .writeOnly, enabled: true) == .connected)
        #expect(IntegrationsSummary.appleCalendarState(access: .full, enabled: false) == .available)
        #expect(IntegrationsSummary.appleCalendarState(access: .notDetermined, enabled: true) == .available)
        #expect(IntegrationsSummary.appleCalendarState(access: .denied, enabled: true) == .deniedInSettings)
    }

    @Test("Google is coming soon (H9); WhatsApp is connected in a WhatsApp region, available elsewhere")
    func otherRows() {
        let brazil = IntegrationsSummary(
            calendarAccess: .notDetermined, calendarEnabled: false, messagingChannel: .whatsapp
        )
        #expect(brazil.googleCalendar == .comingSoon)
        #expect(brazil.whatsApp == .connected)
        #expect(brazil.instagram == .available)
        #expect(brazil.contacts == .available)

        let usa = IntegrationsSummary(
            calendarAccess: .notDetermined, calendarEnabled: false, messagingChannel: .messages
        )
        #expect(usa.whatsApp == .available)
    }
}
