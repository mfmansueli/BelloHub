//
//  AppointmentServiceTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("AppointmentService")
@MainActor
struct AppointmentServiceTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeAppointment() -> Appointment {
        let start = now.addingTimeInterval(48 * 3600)
        return Appointment(
            clientID: UUID(), serviceName: "Facial", startsAt: start, endsAt: start.addingTimeInterval(3600),
            totalMinutes: 60, createdAt: now
        )
    }

    @Test("A booked visit can be read back, moved, cancelled and marked, each stored")
    func lifecycle() async throws {
        let service = AppointmentService(repository: InMemoryClientRecordRepository())
        let booked = makeAppointment()
        try await service.book(booked)
        #expect(try await service.appointment(id: booked.id)?.status == .booked)

        let newStart = booked.startsAt.addingTimeInterval(86_400)
        let moved = try await service.reschedule(id: booked.id, to: newStart, now: now)
        #expect(moved.rescheduleCount == 1)
        #expect(try await service.appointment(id: booked.id)?.startsAt == moved.startsAt)

        let cancelled = try await service.cancel(id: booked.id, by: .client, policy: .standard, now: now)
        #expect(cancelled.status == .cancelled)
        #expect(try await service.appointment(id: booked.id)?.status == .cancelled)
    }

    @Test("Opening the reminder chat and her own mark of sending are stored apart")
    func reminderStates() async throws {
        let service = AppointmentService(repository: InMemoryClientRecordRepository())
        let booked = makeAppointment()
        try await service.book(booked)

        try await service.markReminderSent(id: booked.id, now: now)
        var stored = try #require(try await service.appointment(id: booked.id))
        #expect(stored.reminderSentAt == now && stored.reminderMarkedSentAt == nil)

        try await service.markReminderSentByHer(id: booked.id, now: now.addingTimeInterval(60))
        stored = try #require(try await service.appointment(id: booked.id))
        #expect(stored.reminderSentAt == now && stored.reminderMarkedSentAt == now.addingTimeInterval(60))
    }

    @Test("Changing a visit that does not exist says so")
    func missing() async {
        let service = AppointmentService(repository: InMemoryClientRecordRepository())
        await #expect(throws: VaultRepositoryError.notFound) {
            try await service.markNoShow(id: UUID(), forgive: false, now: now)
        }
    }

    @Test("Without a vault every call is unavailable and the stream is empty")
    func unavailable() async throws {
        let service = AppointmentService(vault: VaultService(repository: nil))
        await #expect(throws: VaultRepositoryError.unavailable) { try await service.book(makeAppointment()) }
        var seen = 0
        for await _ in service.stream(in: DateInterval(start: now, duration: 3600)) { seen += 1 }
        #expect(seen == 0)
    }
}
