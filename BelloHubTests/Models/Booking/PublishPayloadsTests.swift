//
//  PublishPayloadsTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("PublishPayloads: the page")
struct PublishPayloadsTests {
    private let now = TestClock.now

    private func profile(_ inputs: PublishInputs = makePublishInputs()) -> PublishProfileRequest.Profile {
        PublishPayloads.profile(inputs, now: now).profile
    }

    // MARK: - Readiness

    @Test("A page needs an address, a workplace location and at least one active service")
    func blockers() {
        #expect(PublishPayloads.blocker(makePublishInputs()) == nil)
        #expect(PublishPayloads.blocker(makePublishInputs(slug: nil)) == .needsAddress)
        let inactive = [Service(name: "Old", durationMinutes: 30, isActive: false)]
        #expect(PublishPayloads.blocker(makePublishInputs(services: inactive)) == .needsService)
        #expect(PublishPayloads.blocker(makePublishInputs(slug: nil, services: [])) == .needsAddress)

        var noLocation = makePublishInputs()
        noLocation.setup.location = nil
        #expect(PublishPayloads.blocker(noLocation) == .needsWorkplace)

        var incompleteLocation = makePublishInputs()
        incompleteLocation.setup.location = BusinessLocation(street: "", city: "", countryCode: "BR")
        #expect(PublishPayloads.blocker(incompleteLocation) == .needsWorkplace)
    }

    // MARK: - Profile

    @Test("Only active services are offered, with lower-case ids")
    func services() {
        let page = profile()
        #expect(page.services.map(\.name) == ["Glow Facial"])
        #expect(page.services.first?.id == "11111111-1111-4111-8111-111111111111")
        #expect(page.services.first?.category == "Face")
        #expect(page.services.first?.durationMinutes == 60)
    }

    private struct PriceCase: Sendable {
        let display: PriceDisplay
        let amount: Decimal?
        let wireDisplay: String?
        let wireAmount: Decimal?
    }

    @Test("A price is sent as she chose to show it", arguments: [
        PriceCase(display: .show, amount: 250, wireDisplay: "show", wireAmount: 250),
        PriceCase(display: .startingFrom, amount: 99.9, wireDisplay: "startingFrom", wireAmount: 99.9),
        PriceCase(display: .onRequest, amount: 50, wireDisplay: "onRequest", wireAmount: nil),
        PriceCase(display: .show, amount: nil, wireDisplay: nil, wireAmount: nil),
        PriceCase(display: .hide, amount: 250, wireDisplay: nil, wireAmount: nil)
    ])
    private func prices(_ row: PriceCase) {
        let service = Service(name: "S", durationMinutes: 30, priceAmount: row.amount, priceDisplay: row.display)
        let sent = profile(makePublishInputs(services: [service])).services.first?.price
        #expect(sent?.display == row.wireDisplay)
        #expect(sent?.amount == row.wireAmount)
    }

    @Test("Amounts are rounded to cents and durations kept inside the contract's range")
    func clamping() {
        let long = Service(
            name: "S", durationMinutes: 5_000, priceAmount: Decimal(string: "10.456"), priceDisplay: .show
        )
        let short = Service(name: "T", durationMinutes: 1)
        let sent = profile(makePublishInputs(services: [long, short])).services
        #expect(sent[0].price?.amount == Decimal(string: "10.46"))
        #expect(sent.map(\.durationMinutes).sorted() == [5, 720])
    }

    @Test("Long names are cut to 80 characters and an empty business name is left out")
    func names() {
        var inputs = makePublishInputs()
        inputs.profile.displayName = String(repeating: "A", count: 200)
        inputs.profile.businessName = ""
        let page = profile(inputs)
        #expect(page.displayName.count == 80)
        #expect(page.businessName == nil)
        #expect(profile().businessName == "Studio Maria")
    }

    @Test("The business language comes first, then the others once each, at most six, only known ones")
    func locales() {
        var inputs = makePublishInputs()
        inputs.profile.bookingLocaleIDs = ["en", "pt-BR", "xx", "fr", "en", "de", "it", "es", "tr"]
        #expect(profile(inputs).locales == ["pt-BR", "en", "fr", "de", "it", "es"])
        inputs.profile.bookingLocaleIDs = []
        #expect(profile(inputs).locales == ["pt-BR"])
        inputs.profile.appLocaleID = "zz"
        #expect(profile(inputs).locales == ["en"])
    }

    @Test("The rules text is the PolicyRuleText of every offered language, one line per rule")
    func rulesText() {
        var inputs = makePublishInputs()
        inputs.profile.bookingLocaleIDs = AppLocalization.allCases.map(\.rawValue)
        let page = profile(inputs)
        #expect(Set(page.rulesText.keys) == Set(page.locales))
        for locale in page.locales {
            guard let localization = AppLocalization(rawValue: locale) else { continue }
            let expected = PolicyRuleText(localization: localization, professionalName: "Maria")
                .lines(cancellation: inputs.setup.cancellation, noShow: inputs.setup.noShow).joined(separator: "\n")
            #expect(page.rulesText[locale] == expected)
            #expect((page.rulesText[locale] ?? "").count <= PublishPayloads.rulesLimit)
        }
        #expect(page.rulesText["en"]?.contains("Maria") == true)
        #expect(page.rulesText["en"]?.contains("{") == false)
    }

    @Test("Only credentials she chose to show are sent, and the registration number gets a title")
    func credentials() {
        var inputs = makePublishInputs()
        inputs.credentials = [
            Credential(title: "Shown", institution: "Senac", year: 2019, showOnBookingPage: true, position: 0),
            Credential(title: "Hidden", showOnBookingPage: false, position: 1),
            Credential(kind: .registration, title: "", registrationNumber: "CRBM 1234", position: 2),
            Credential(kind: .registration, title: "", registrationNumber: "  ", position: 3),
            Credential(title: "Odd year", year: 1900, position: 4)
        ]
        let sent = profile(inputs).credentials
        #expect(sent.map(\.title) == ["Shown", "Registro profissional", "Odd year"])
        #expect(sent[0].institution == "Senac" && sent[0].year == 2019)
        #expect(sent[1].registrationNumber == "CRBM 1234")
        #expect(sent[2].year == nil)
    }

    @Test("Add-ons she offers are sent with their price as text")
    func addOns() {
        let sent = profile().addOns
        #expect(sent.count == 1 && sent[0].name == "LED mask" && sent[0].minutes == 15)
        #expect(sent[0].priceText?.contains("40") == true)
    }

    @Test("The booking switches follow the page settings, the pause and the window")
    func booking() {
        var page = BookingPageSettings.standard
        page.confirmNewClients = true
        page.maxGuests = 2
        let open = profile(makePublishInputs(page: page)).booking
        #expect(open.acceptingBookings && open.pausedUntil == nil && open.requiresApproval && open.maxGuests == 2)
        #expect(open.maxDaysAhead == 60)

        let back = TestClock.days(10)
        let paused = BookingPause.pausing(.standard, until: back, now: now, timeZone: TestClock.saoPaulo)
        let sent = profile(makePublishInputs(page: paused)).booking
        #expect(!sent.acceptingBookings)
        #expect(sent.pausedUntil == TestClock.calendar().startOfDay(for: back))

        let foreverPaused = BookingPause.pausing(.standard, until: nil, now: now, timeZone: TestClock.saoPaulo)
        let forever = profile(makePublishInputs(page: foreverPaused)).booking
        #expect(!forever.acceptingBookings && forever.pausedUntil == nil)
    }

    @Test("A pause whose return day has come is published as open")
    func expiredPause() {
        var paused = BookingPageSettings.standard
        paused.acceptingBookings = false
        paused.pausedUntil = TestClock.days(-1)
        #expect(profile(makePublishInputs(page: paused)).booking.acceptingBookings)
    }

    @Test("The policy maps field by field")
    func policy() {
        var inputs = makePublishInputs()
        inputs.setup.cancellation = CancellationPolicy(
            freeWindowHours: 48, clientCanReschedule: false, maxReschedules: nil, afterWindowCancel: .message,
            afterWindowReschedule: .message, askConfirmation: true, graceMinutes: 10
        )
        let sent = profile(inputs).policy
        #expect(sent.freeWindowHours == 48 && !sent.clientCanReschedule && sent.maxReschedules == nil)
        #expect(sent.afterWindowCancel == "message" && sent.afterWindowReschedule == "message")
        #expect(sent.askConfirmation && sent.graceMinutes == 10)
    }

    @Test("The public inbox key travels with the page")
    func inboxKey() {
        #expect(profile().inboxKey == makeInboxKey())
    }
}
