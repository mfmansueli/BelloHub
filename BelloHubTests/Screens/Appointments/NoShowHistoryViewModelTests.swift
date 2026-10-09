//
//  NoShowHistoryViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("NoShowHistoryViewModel")
@MainActor
struct NoShowHistoryViewModelTests {
    private func makeModel(_ store: AppointmentTestStore, clientID: UUID? = nil) -> NoShowHistoryViewModel {
        NoShowHistoryViewModel(
            clientID: clientID ?? store.client.id, vault: store.vault, appointments: store.appointments,
            profile: store.profile, setup: store.setup, now: { [now = store.now] in now }
        )
    }

    @Test("Her misses are listed newest first, counted under the rule")
    func listsMisses() async {
        let store = await AppointmentTestStore()
        let older = await store.save(hoursFromNow: -24 * 40, status: .noShow)
        let newer = await store.save(hoursFromNow: -24 * 10, status: .noShow)
        await store.save(hoursFromNow: -24 * 20, status: .completed)
        let model = makeModel(store)

        await model.loadAsync()

        #expect(!model.isLoading)
        #expect(model.client?.id == store.client.id)
        #expect(model.entries.map(\.id) == [newer.id, older.id])
        #expect(model.entries.allSatisfy { $0.standing == .counts })
        #expect(model.status?.counted == 2)
        #expect(model.policy == NoShowPolicy.standard)
        #expect(!model.offersReset)
    }

    @Test("Forgiving a miss keeps it in the history and stops counting it")
    func forgivesAMiss() async throws {
        let store = await AppointmentTestStore()
        let missed = await store.save(hoursFromNow: -24 * 10, status: .noShow)
        let model = makeModel(store)
        await model.loadAsync()
        let entry = try #require(model.entries.first)
        #expect(entry.canForgive)

        await model.forgiveAsync(entry)

        #expect(model.actionErrorMessage == nil)
        #expect(model.entries.count == 1)
        #expect(model.entries.first?.standing == .forgiven)
        #expect(model.entries.first?.canForgive == false)
        #expect(model.status?.counted == 0)
        #expect(try await store.visit(missed.id)?.noShowForgiven == true)
    }

    @Test("Reaching the limit offers the reset, which starts her count from zero and reopens online booking")
    func resetsTheCount() async throws {
        let store = await AppointmentTestStore()
        for days in [5, 10, 15] {
            await store.save(hoursFromNow: -24 * Double(days), status: .noShow)
        }
        var stopped = store.client
        stopped.onlineBookingStopped = true
        stopped.stopReason = "no-shows"
        _ = await store.repository.save(stopped)
        let model = makeModel(store)
        await model.loadAsync()
        #expect(model.status?.limitReached == true)
        #expect(model.offersReset)

        await model.resetCountAsync()

        #expect(model.didReset)
        #expect(model.actionErrorMessage == nil)
        #expect(model.status?.counted == 0)
        #expect(model.entries.count == 3)
        #expect(model.entries.allSatisfy { $0.standing == .expired })
        #expect(!model.offersReset)
        let saved = try #require(await store.repository.client(id: store.client.id))
        #expect(saved.noShowCountResetAt == store.now)
        #expect(!saved.onlineBookingStopped)
        #expect(saved.stopReason == nil)
    }

    @Test("Booking stopped by hand offers the reset even under the limit")
    func stoppedByHandOffersReset() async {
        let store = await AppointmentTestStore()
        var stopped = store.client
        stopped.onlineBookingStopped = true
        _ = await store.repository.save(stopped)
        let model = makeModel(store)

        await model.loadAsync()

        #expect(model.status?.limitReached == false)
        #expect(model.offersReset)
    }

    @Test("An unknown client says it is missing")
    func missingClient() async {
        let store = await AppointmentTestStore()
        let model = makeModel(store, clientID: UUID())
        await model.loadAsync()
        #expect(model.isMissing)
        #expect(model.entries.isEmpty)
        #expect(!model.offersReset)
    }

    @Test("A locked vault reports the load error")
    func lockedVault() async {
        let store = await AppointmentTestStore()
        let model = NoShowHistoryViewModel(
            clientID: store.client.id, vault: VaultService(repository: nil), appointments: store.appointments,
            profile: store.profile, setup: store.setup, now: { [now = store.now] in now }
        )
        await model.loadAsync()
        #expect(model.errorMessage != nil)
        #expect(!model.isLoading)
    }
}
