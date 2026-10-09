//
//  NoShowMarkViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("NoShowMarkViewModel")
@MainActor
struct NoShowMarkViewModelTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private struct Rig {
        let model: NoShowMarkViewModel
        let appointments: AppointmentService
        let sender: FakeMessageSender
        let visitID: UUID
    }

    private func makeRig(startedHoursAgo: Double = 5) async throws -> Rig {
        let repository = InMemoryClientRecordRepository(clock: { now })
        let vault = VaultService(repository: repository)
        let client = Client(name: "Beatriz Lima", phoneE164: "+5511970001111", createdAt: now)
        await repository.save(client)
        let start = now.addingTimeInterval(-startedHoursAgo * 3600)
        let visit = Appointment(
            clientID: client.id, serviceName: "Facial", startsAt: start, endsAt: start.addingTimeInterval(3600),
            totalMinutes: 60, createdAt: start.addingTimeInterval(-86_400)
        )
        await repository.save(visit)
        let sender = FakeMessageSender()
        let appointments = AppointmentService(repository: repository)
        let model = NoShowMarkViewModel(
            appointmentID: visit.id, appointments: appointments, vault: vault,
            profile: ProfileService(vault: vault), setup: BookingSetupService(vault: vault),
            messages: MessageService(repository: repository, sender: sender), now: { [now] in now }
        )
        return Rig(model: model, appointments: appointments, sender: sender, visitID: visit.id)
    }

    @Test("A visit that started hours ago can be marked, and confirming saves it and opens the note")
    func confirmsAndSendsTheNote() async throws {
        let rig = try await makeRig()
        await rig.model.loadAsync()
        #expect(rig.model.canMark)

        await rig.model.confirmAsync()

        #expect(rig.model.done?.forgiven == false)
        #expect(try await rig.appointments.appointment(id: rig.visitID)?.status == .noShow)
        #expect(rig.sender.opened.count == 1)
    }

    @Test("Excusing the absence is saved as forgiven and no note opens when she turns it off")
    func excusedWithoutNote() async throws {
        let rig = try await makeRig()
        await rig.model.loadAsync()
        rig.model.countsAgainstClient = false
        rig.model.sendsNote = false

        await rig.model.confirmAsync()

        #expect(rig.model.done?.forgiven == true)
        #expect(rig.model.done?.message == nil)
        #expect(rig.sender.opened.isEmpty)
    }

    @Test("A visit that has not started cannot be marked")
    func notStartedCannotBeMarked() async throws {
        let rig = try await makeRig(startedHoursAgo: -24)
        await rig.model.loadAsync()
        #expect(!rig.model.canMark)

        await rig.model.confirmAsync()

        #expect(rig.model.done == nil)
        #expect(try await rig.appointments.appointment(id: rig.visitID)?.status == .booked)
    }

    @Test("An unknown visit says it is missing")
    func missingVisit() async throws {
        let rig = try await makeRig()
        let model = NoShowMarkViewModel(
            appointmentID: UUID(), appointments: rig.appointments,
            vault: VaultService(repository: InMemoryClientRecordRepository()),
            profile: ProfileService(vault: VaultService(repository: nil)),
            setup: BookingSetupService(vault: VaultService(repository: nil)),
            messages: MessageService(repository: InMemoryClientRecordRepository(), sender: rig.sender)
        )
        await model.loadAsync()
        #expect(model.isMissing || model.errorMessage != nil)
        #expect(!model.canMark)
    }
}
