//
//  SessionPlanViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("SessionPlanViewModel")
@MainActor
struct SessionPlanViewModelTests {
    private let planID = UUID()

    private func makeModel(_ store: AppointmentTestStore, clientID: UUID? = nil) -> SessionPlanViewModel {
        SessionPlanViewModel(
            clientID: clientID ?? store.client.id, vault: store.vault, appointments: store.appointments,
            profile: store.profile, now: { [now = store.now] in now }, makeID: { [planID] in planID }
        )
    }

    @Test("A client without a plan starts a blank one that cannot be saved until it has a name")
    func startsBlank() async {
        let store = await AppointmentTestStore()
        let model = makeModel(store)

        await model.loadAsync()

        #expect(!model.isLoading)
        #expect(model.client?.id == store.client.id)
        #expect(model.existing == nil)
        #expect(model.draft == SessionPlanDraft())
        #expect(!model.canSave)
        #expect(!model.isFinished)

        model.draft.name = "Laser, 6 sessions"

        #expect(model.canSave)
    }

    @Test("Saving stores the plan with the injected id, and editing again clears Saved")
    func savesThePlan() async {
        let store = await AppointmentTestStore()
        let model = makeModel(store)
        await model.loadAsync()
        model.draft.name = "Laser"
        model.draft.totalSessions = 4
        model.draft.intervalWeeks = 3

        await model.saveAsync()

        #expect(model.didSave)
        #expect(model.saveErrorMessage == nil)
        #expect(model.existing?.id == planID)
        let stored = await store.repository.sessionPlans(for: store.client.id)
        #expect(stored.count == 1)
        #expect(stored.first?.name == "Laser")
        #expect(stored.first?.totalSessions == 4)
        #expect(stored.first?.intervalWeeks == 3)
        #expect(model.timeline.totalSessions == 4)

        model.draft.name = "Laser legs"

        #expect(!model.didSave)
    }

    @Test("Saving again updates the same plan instead of adding one")
    func savingTwiceKeepsOnePlan() async {
        let store = await AppointmentTestStore()
        let model = makeModel(store)
        await model.loadAsync()
        model.draft.name = "Laser"
        await model.saveAsync()

        model.draft.totalSessions = 8
        await model.saveAsync()

        let stored = await store.repository.sessionPlans(for: store.client.id)
        #expect(stored.count == 1)
        #expect(stored.first?.totalSessions == 8)
    }

    @Test("An open plan is loaded into the form, with its completed sessions in the timeline")
    func loadsTheOpenPlan() async {
        let store = await AppointmentTestStore()
        let plan = SessionPlan(
            id: UUID(), clientID: store.client.id, name: "Peeling", totalSessions: 3, intervalWeeks: 2,
            startDate: store.now.addingTimeInterval(-21 * 86_400), remindToRebook: false
        )
        await store.repository.save(plan)
        await store.save(hoursFromNow: -24 * 20, status: .completed)
        let model = makeModel(store)

        await model.loadAsync()

        #expect(model.existing == plan)
        #expect(model.draft == SessionPlanDraft(plan: plan))
        #expect(model.canSave)
        #expect(!model.isFinished)
        #expect(model.timeline.totalSessions == 3)
    }

    @Test("Starting a new plan leaves the stored one alone and blanks the form")
    func startNewPlan() async {
        let store = await AppointmentTestStore()
        let model = makeModel(store)
        await model.loadAsync()
        model.draft.name = "Laser"
        await model.saveAsync()

        model.startNewPlan()

        #expect(model.existing == nil)
        #expect(model.draft == SessionPlanDraft())
        #expect(!model.didSave)
        #expect(await store.repository.sessionPlans(for: store.client.id).count == 1)
    }

    @Test("An unknown client says it is missing")
    func missingClient() async {
        let store = await AppointmentTestStore()
        let model = makeModel(store, clientID: UUID())
        await model.loadAsync()
        #expect(model.isMissing)
        #expect(!model.isLoading)
    }

    @Test("A locked vault reports the load error instead of a blank form")
    func lockedVault() async {
        let store = await AppointmentTestStore()
        let model = SessionPlanViewModel(
            clientID: store.client.id, vault: VaultService(repository: nil), appointments: store.appointments,
            profile: store.profile, now: { [now = store.now] in now }
        )
        await model.loadAsync()
        #expect(model.errorMessage != nil)
        #expect(!model.isLoading)
    }
}
