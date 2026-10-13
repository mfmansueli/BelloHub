//
//  PublishTestFactories.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation

/// A fixed inbox key (the shape the server checks: an 11-character id, a 43-character public key).
func makeInboxKey() -> InboxPublicKey {
    InboxPublicKey(
        keyId: "AAAAAAAAAAA",
        pub: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    )
}

/// Maria's profile: Brazilian business language, English as a second booking language.
func makeProfessionalProfile(
    displayName: String = "Maria Silva",
    businessName: String = "Studio Maria",
    appLocaleID: String = "pt-BR",
    bookingLocaleIDs: [String] = ["en"]
) -> ProfessionalProfile {
    ProfessionalProfile(
        displayName: displayName, businessName: businessName, regionCode: "BR", timeZoneID: "America/Sao_Paulo",
        currencyCode: "BRL", appLocaleID: appLocaleID, bookingLocaleIDs: bookingLocaleIDs,
        professions: [.esthetician], createdAt: TestClock.days(-100)
    )
}

/// Everything needed to build both requests: two services (one inactive), an add-on, a shown credential, a chosen
/// address and Maria's usual week.
func makePublishInputs(
    slug: String? = "maria",
    services: [Service]? = nil,
    appointments: [Appointment] = [],
    blocks: [TimeBlock] = [],
    page: BookingPageSettings = .standard
) -> PublishInputs {
    var setup = BookingSetup.starter(now: TestClock.now)
    setup.slug = slug
    setup.page = page
    setup.location = BusinessLocation(
        street: "Rua Augusta 1200", postalCode: "01304-001", city: "São Paulo", countryCode: "BR"
    )
    let offered = services ?? [
        Service(
            id: UUID(uuidString: "11111111-1111-4111-8111-111111111111") ?? UUID(), name: "Glow Facial",
            category: "Face", durationMinutes: 60, priceAmount: 250, priceDisplay: .show, position: 0
        ),
        Service(
            id: UUID(uuidString: "22222222-2222-4222-8222-222222222222") ?? UUID(), name: "Old peel",
            durationMinutes: 45, isActive: false, position: 1
        )
    ]
    return PublishInputs(
        profile: makeProfessionalProfile(),
        services: offered,
        addOns: [AddOn(
            id: UUID(uuidString: "33333333-3333-4333-8333-333333333333") ?? UUID(), name: "LED mask", minutes: 15,
            priceAmount: 40, isOffered: true, position: 0
        )],
        credentials: [Credential(title: "Aesthetics course", institution: "Senac", year: 2019)],
        setup: setup,
        availability: makeAvailability(),
        appointments: appointments,
        blocks: blocks,
        inboxKey: makeInboxKey()
    )
}

/// A visit of her own agenda `hours` from `TestClock.now` (negative: already started), carrying details that must never
/// reach the server (a service name and a private note).
func makeVisit(
    hours: Double,
    status: AppointmentStatus = .booked,
    origin: AppointmentOrigin = .manual,
    bookingID: String? = nil,
    minutes: Int = 60
) -> Appointment {
    let start = TestClock.now.addingTimeInterval(hours * 3_600)
    return Appointment(
        clientID: UUID(), serviceName: "Secret treatment", startsAt: start,
        endsAt: start.addingTimeInterval(TimeInterval(minutes * 60)), status: status, origin: origin,
        bookingID: bookingID, createdAt: TestClock.now, privateNote: "private note"
    )
}

/// A closed stretch `hours` from `TestClock.now`, with a private reason.
func makeBlock(hours: Double, length: Double = 1, reason: String? = "Dentist") -> TimeBlock {
    let start = TestClock.now.addingTimeInterval(hours * 3_600)
    return TimeBlock(id: UUID(), startsAt: start, endsAt: start.addingTimeInterval(length * 3_600), reason: reason)
}

extension PublishFailure {
    /// Every case, so a table test cannot miss a new one by forgetting to extend a list.
    static let allCasesForTests: [PublishFailure] = [
        .needsAddress, .needsService, .addressTaken, .offline, .busy, .signedOut, .locked, .rejected, .keyMismatch
    ]
}
