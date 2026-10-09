//
//  AppointmentTestStore.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation

/// The services an appointment-slice ViewModel needs, over an in-memory vault, with the phone and the health form
/// catalog faked at the boundary. One client ("Beatriz") is saved; tests add the visits they need with `save`.
@MainActor
struct AppointmentTestStore {
    let now: Date
    let repository: InMemoryClientRecordRepository
    let vault: VaultService
    let profile: ProfileService
    let setup: BookingSetupService
    let appointments: AppointmentService
    let messages: MessageService
    let sender: FakeMessageSender
    let client: Client

    init(now: Date = TestClock.now) async {
        self.now = now
        repository = InMemoryClientRecordRepository(clock: { now })
        vault = VaultService(repository: repository)
        profile = ProfileService(vault: vault)
        setup = BookingSetupService(vault: vault, now: { now })
        appointments = AppointmentService(repository: repository)
        sender = FakeMessageSender()
        messages = MessageService(repository: repository, sender: sender)
        client = Client(name: "Beatriz Lima", phoneE164: "+5511970001111", createdAt: now.addingTimeInterval(-86_400))
        await repository.save(client)
    }

    /// Saves a one-hour visit of Beatriz that starts `hoursFromNow` hours from `now` (negative: already started).
    @discardableResult
    func save(
        hoursFromNow: Double, status: AppointmentStatus = .booked, serviceName: String = "Facial",
        clientID: UUID? = nil, forgiven: Bool = false
    ) async -> Appointment {
        let start = now.addingTimeInterval(hoursFromNow * 3600)
        let visit = Appointment(
            clientID: clientID ?? client.id, serviceName: serviceName, startsAt: start,
            endsAt: start.addingTimeInterval(3600), totalMinutes: 60, status: status, noShowForgiven: forgiven,
            createdAt: start.addingTimeInterval(-86_400)
        )
        await repository.save(visit)
        return visit
    }

    func visit(_ id: UUID) async throws -> Appointment? {
        try await appointments.appointment(id: id)
    }
}
