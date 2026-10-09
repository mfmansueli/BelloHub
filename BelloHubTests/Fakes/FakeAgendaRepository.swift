//
//  FakeAgendaRepository.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation

/// The appointments and services of the in-memory vault, with writes that can be told to fail: how the error paths
/// of the calendar ViewModels are tested. Behavior is the vault's (the contract tests cover it against both stores).
actor FakeAgendaRepository: AgendaRepository {
    struct Failure: Error, Equatable {}

    let inner: InMemoryClientRecordRepository
    private var failsAllWrites = false
    private var failingIDs: Set<UUID> = []
    private(set) var savedAppointmentIDs: [UUID] = []

    init(inner: InMemoryClientRecordRepository = InMemoryClientRecordRepository(clock: { TestClock.now })) {
        self.inner = inner
    }

    /// While true every write throws `Failure` and changes nothing.
    func setFailsWrites(_ value: Bool) { failsAllWrites = value }

    /// Writes of the appointment with this id throw `Failure`.
    func failWrites(ofAppointment id: UUID) { failingIDs.insert(id) }

    // MARK: - AgendaRepository

    nonisolated func appointments(in range: DateInterval) -> AsyncStream<[Appointment]> {
        inner.appointments(in: range)
    }

    func loadAppointments(in range: DateInterval) async throws -> [Appointment] {
        await inner.loadAppointments(in: range)
    }

    func appointments(for clientID: UUID) async throws -> [Appointment] {
        await inner.appointments(for: clientID)
    }

    func appointment(id: UUID) async throws -> Appointment? {
        await inner.appointment(id: id)
    }

    func save(_ appointment: Appointment) async throws {
        if failsAllWrites || failingIDs.contains(appointment.id) { throw Failure() }
        savedAppointmentIDs.append(appointment.id)
        await inner.save(appointment)
    }

    func deleteAppointment(id: UUID) async throws {
        if failsAllWrites { throw Failure() }
        await inner.deleteAppointment(id: id)
    }

    func services() async throws -> [Service] { await inner.services() }

    func save(_ service: Service) async throws {
        if failsAllWrites { throw Failure() }
        await inner.save(service)
    }

    func deleteService(id: UUID) async throws {
        if failsAllWrites { throw Failure() }
        await inner.deleteService(id: id)
    }
}
