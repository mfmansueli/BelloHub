//
//  RepositoryAgendaContractTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("Repository contract: agenda", .serialized)
struct RepositoryAgendaContractTests {
    private let fixture = ContractFixture()
    private var clock: MutableClock { fixture.clock }

    private func seeded(_ flavor: RepositoryFlavor) throws -> (any ClientRecordRepository, Client) {
        try fixture.seeded(flavor)
    }

    // MARK: - Agenda

    @Test("Appointments are found by the range they overlap, in order", arguments: RepositoryFlavor.allCases)
    func appointmentRange(flavor: RepositoryFlavor) async throws {
        let (repository, client) = try seeded(flavor)
        try await repository.save(client)
        func appointment(_ start: String, minutes: Int = 60) -> Appointment {
            let date = TestClock.date(start)
            return Appointment(clientID: client.id, serviceName: "Glow", startsAt: date,
                               endsAt: date.addingTimeInterval(TimeInterval(minutes * 60)), createdAt: date)
        }
        let early = appointment("2026-10-08 09:00")
        let late = appointment("2026-10-08 15:00")
        let nextDay = appointment("2026-10-09 09:00")
        let overnight = appointment("2026-10-07 23:30", minutes: 90)
        for item in [late, nextDay, early, overnight] { try await repository.save(item) }

        let day = DateInterval(start: TestClock.date("2026-10-08 00:00"), end: TestClock.date("2026-10-09 00:00"))

        #expect(try await repository.loadAppointments(in: day).map(\.id) == [overnight.id, early.id, late.id])
        #expect(try await repository.appointments(for: client.id).count == 4)
    }

    @Test("An appointment can be updated and deleted", arguments: RepositoryFlavor.allCases)
    func appointmentUpdateAndDelete(flavor: RepositoryFlavor) async throws {
        let (repository, client) = try seeded(flavor)
        let start = TestClock.date("2026-10-08 09:00")
        var appointment = Appointment(clientID: client.id, serviceName: "Glow", startsAt: start,
                                      endsAt: start.addingTimeInterval(3_600), createdAt: start,
                                      privateNote: "Sentinel-PRIV")
        try await repository.save(appointment)
        appointment.status = .completed
        try await repository.save(appointment)

        #expect(try await repository.appointment(id: appointment.id)?.status == .completed)
        #expect(try await repository.appointment(id: appointment.id)?.privateNote == "Sentinel-PRIV")
        try await repository.deleteAppointment(id: appointment.id)
        #expect(try await repository.appointment(id: appointment.id) == nil)
    }

    @Test("Services keep a price as an exact decimal", arguments: RepositoryFlavor.allCases)
    func serviceRoundTrip(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: clock)
        let price = Decimal(string: "119.90") ?? 0
        let service = Service(name: "Brazilian Glow", durationMinutes: 90, priceAmount: price, followUpWeeks: 4,
                              contraindications: ["isotretinoin"], requiresPatchTest: true)
        try await repository.save(service)

        let stored = try #require(try await repository.services().first)
        #expect(stored == service)
        #expect(stored.priceAmount == price)
        try await repository.deleteService(id: service.id)
        #expect(try await repository.services().isEmpty)
    }
}
