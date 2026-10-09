//
//  AvailabilityViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("AvailabilityViewModel")
@MainActor
struct AvailabilityViewModelTests {
    private struct Rig {
        let model: AvailabilityViewModel
        let service: BookingSetupService
        let repository: FakeBookingSetupRepository
    }

    private func make(stored: AvailabilitySettings? = nil, loaded: Bool = true) async throws -> Rig {
        let repository = FakeBookingSetupRepository()
        if let stored { await repository.seed(availability: stored) }
        let service = BookingSetupService(repository: repository, now: { TestClock.now })
        let model = AvailabilityViewModel(service: service, timeZoneID: "America/Sao_Paulo", now: { TestClock.now })
        if loaded { await model.loadAsync() }
        return Rig(model: model, service: service, repository: repository)
    }

    private func draft(_ start: Int, _ end: Int) -> StretchDraft {
        StretchDraft(startMinutes: start, endMinutes: end)
    }

    // MARK: - Loading

    @Test("With nothing stored the screen shows the starting week and says so")
    func starter() async throws {
        let rig = try await make()
        #expect(rig.model.isStarter && rig.model.hasLoaded && rig.model.errorMessage == nil)
        #expect(rig.model.settings.weekly.map(\.weekday) == [2, 3, 4, 5, 6])
        #expect(try await rig.repository.availability() == nil, "showing the suggestion stores nothing")
    }

    @Test("Stored hours are shown as they are")
    func stored() async throws {
        let stored = makeAvailability(weekdays: [3, 4], bufferMinutes: 30)
        let rig = try await make(stored: stored)
        #expect(rig.model.settings == stored && !rig.model.isStarter)
    }

    @Test("A failed read shows the error and a retry works")
    func loadFailure() async throws {
        let rig = try await make(loaded: false)
        await rig.repository.setFailsReads(true)
        await rig.model.loadAsync()
        #expect(rig.model.errorMessage != nil && rig.model.hasLoaded)
        await rig.repository.setFailsReads(false)
        await rig.model.loadAsync()
        #expect(rig.model.errorMessage == nil)
    }

    @Test("The skeleton shows while the first read runs and not after")
    func skeleton() async throws {
        let rig = try await make(loaded: false)
        #expect(!rig.model.showsSkeleton)
        await rig.model.loadAsync()
        #expect(!rig.model.showsSkeleton)
    }

    // MARK: - Weekly hours

    @Test("Switching a day on or off is saved at once, and the first change stores the whole week")
    func toggles() async throws {
        let rig = try await make()
        await rig.model.setDay(1, open: true)
        let stored = try #require(try await rig.repository.availability())
        #expect(AvailabilityEditor.isOpen(1, in: stored) && AvailabilityEditor.isOpen(2, in: stored))
        #expect(!rig.model.isStarter && !rig.service.isStarterAvailability)
        await rig.model.setDay(2, open: false)
        #expect(!AvailabilityEditor.isOpen(2, in: try #require(try await rig.repository.availability())))
    }

    @Test("A day switched off and on again gets its hours back")
    func restoresHours() async throws {
        let rig = try await make()
        #expect(await rig.model.saveStretches(of: 3, [draft(480, 720), draft(840, 1020)]) == nil)
        await rig.model.setDay(3, open: false)
        await rig.model.setDay(3, open: true)
        let stretches = AvailabilityEditor.stretches(for: 3, in: rig.model.settings)
        #expect(stretches.map(\.startMinutes) == [480, 840] && stretches.map(\.endMinutes) == [720, 1020])
    }

    @Test("Saving stretches stores them; invalid ones come back with the reason and store nothing")
    func stretches() async throws {
        let rig = try await make()
        #expect(await rig.model.saveStretches(of: 4, [draft(600, 600)]) == .order)
        #expect(await rig.model.saveStretches(of: 4, [draft(600, 605)]) == .tooShort)
        #expect(await rig.model.saveStretches(of: 4, [draft(540, 700), draft(650, 900)]) == .overlap)
        #expect(await rig.repository.writeCount == 0)
        #expect(await rig.model.saveStretches(of: 4, [draft(540, 700)]) == nil)
        #expect(AvailabilityEditor.stretches(for: 4,
            in: try #require(try await rig.repository.availability())).first?.endMinutes == 700)
    }

    // MARK: - Breaks

    @Test("A break is added, edited and deleted")
    func breaks() async throws {
        let rig = try await make()
        let coffee = BreakRule(weekday: nil, startMinutes: 990, endMinutes: 1005, label: "Coffee")
        #expect(await rig.model.saveBreak(coffee, at: nil, fallbackLabel: "Break") == nil)
        #expect(rig.model.sortedBreaks.map(\.rule.label) == ["Coffee"])
        var moved = coffee
        moved.endMinutes = 1020
        #expect(await rig.model.saveBreak(moved, at: 0, fallbackLabel: "Break") == nil)
        #expect(rig.model.settings.breaks[0].endMinutes == 1020)
        await rig.model.deleteBreak(at: 0)
        #expect(rig.model.settings.breaks.isEmpty && rig.model.sortedBreaks.isEmpty)
    }

    @Test("A break that ends before it starts is refused")
    func breakRefused() async throws {
        let rig = try await make()
        let bad = BreakRule(weekday: nil, startMinutes: 700, endMinutes: 600, label: "Lunch")
        #expect(await rig.model.saveBreak(bad, at: nil, fallbackLabel: "Break") == .order)
        #expect(await rig.repository.writeCount == 0)
    }

    // MARK: - Days off

    @Test("Days off are added, listed from today, edited and deleted")
    func daysOff() async throws {
        let rig = try await make()
        let vacation = DayOff(id: UUID(), startDate: TestClock.date("2026-12-22 10:00"),
            endDate: TestClock.date("2027-01-05 10:00"), kind: .vacation)
        #expect(await rig.model.saveDayOff(vacation) == nil)
        #expect(rig.model.upcomingDaysOff.map(\.id) == [vacation.id])
        var blocked = vacation
        blocked.kind = .blocked
        #expect(await rig.model.saveDayOff(blocked) == nil)
        #expect(rig.model.upcomingDaysOff.count == 1 && rig.model.upcomingDaysOff[0].kind == .blocked)
        await rig.model.deleteDayOff(id: vacation.id)
        #expect(rig.model.upcomingDaysOff.isEmpty)
    }

    @Test("Days off that end before they start are refused")
    func daysOffRefused() async throws {
        let rig = try await make()
        let bad = DayOff(id: UUID(), startDate: TestClock.date("2026-12-22 10:00"),
            endDate: TestClock.date("2026-12-20 10:00"), kind: .dayOff)
        #expect(await rig.model.saveDayOff(bad) == .order)
    }

    // MARK: - Buffer

    @Test("The buffer is saved")
    func buffer() async throws {
        let rig = try await make()
        await rig.model.setBuffer(30)
        #expect(rig.model.settings.bufferMinutes == 30)
        #expect(try await rig.repository.availability()?.bufferMinutes == 30)
    }

    // MARK: - Failures

    @Test("A failed save puts the hours back and shows the error; dismissing clears it")
    func saveFailure() async throws {
        let rig = try await make()
        await rig.repository.setFailsWrites(true)
        await rig.model.setDay(1, open: true)
        #expect(!AvailabilityEditor.isOpen(1, in: rig.model.settings))
        #expect(rig.model.saveErrorMessage != nil && rig.model.isStarter)
        rig.model.dismissSaveError()
        #expect(rig.model.saveErrorMessage == nil)
    }

    @Test("A change that changes nothing does not write")
    func noChange() async throws {
        let rig = try await make(stored: makeAvailability(bufferMinutes: 15))
        await rig.model.setBuffer(15)
        #expect(await rig.repository.writeCount == 0)
    }
}
