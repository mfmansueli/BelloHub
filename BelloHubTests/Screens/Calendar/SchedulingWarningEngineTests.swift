//
//  SchedulingWarningEngineTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("SchedulingWarningEngine")
struct SchedulingWarningEngineTests {
    private let catalog = makeHealthCatalog()

    /// Friday 2026-10-02, a working day (Tuesday to Saturday, 09:00 to 19:00, lunch 12:30 to 13:30, 15 min buffer).
    private func input(
        start: String, minutes: Int = 60, settings: AvailabilitySettings = makeAvailability(),
        appointments: [Appointment] = [], blocks: [TimeBlock] = [], service: Service? = nil, clientID: UUID? = nil,
        clientAppointments: [Appointment] = [], form: HealthForm? = nil, patchTests: [PatchTest] = [],
        ignoring: UUID? = nil, day: String = "2026-10-02"
    ) -> SchedulingWarningInput {
        let begin = TestClock.date("\(day) \(start)")
        return SchedulingWarningInput(
            interval: DateInterval(start: begin, duration: TimeInterval(minutes * 60)), settings: settings,
            appointments: appointments, blocks: blocks, service: service, clientID: clientID,
            clientAppointments: clientAppointments, form: form, catalog: catalog, patchTests: patchTests,
            ignoring: ignoring, now: TestClock.now
        )
    }

    private func warnings(_ input: SchedulingWarningInput) -> [SchedulingWarning] {
        SchedulingWarningEngine.warnings(for: input)
    }

    // MARK: - The time

    @Test("A free time inside her hours has no warning")
    func clean() {
        #expect(warnings(input(start: "10:00")).isEmpty)
    }

    @Test("A time that has passed warns, and she can still book it")
    func past() {
        #expect(warnings(input(start: "09:00", day: "2026-10-01")).contains(.inThePast))
    }

    @Test("An overlap names the visit it clashes with; touching is not an overlap")
    func overlap() {
        let existing = makeVisit(start: friday("10:30"))
        #expect(warnings(input(start: "11:00", appointments: [existing])) == [.overlap(with: existing.id)])
        let touching = makeVisit(start: friday("10:00"))
        #expect(warnings(input(start: "11:00", appointments: [touching]))
            == [.buffer(minutes: 15, neighbour: touching.id)])
    }

    @Test("The buffer warns below her setting and not at it", arguments: [
        (10, true), (14, true), (15, false), (30, false)
    ])
    func buffer(gap: Int, warns: Bool) {
        let before = makeVisit(start: friday("10:00")) // ends 11:00
        let candidateStart = TestClock.calendar().date(byAdding: .minute, value: gap, to: friday("11:00")) ?? .now
        let begin = DateInterval(start: candidateStart, duration: 3_600)
        var query = input(start: "11:00", appointments: [before])
        query.interval = begin
        let found = warnings(query).filter { if case .buffer = $0 { true } else { false } }
        #expect(found.isEmpty == !warns)
    }

    @Test("A buffer of zero never warns")
    func zeroBuffer() {
        let before = makeVisit(start: friday("10:00"))
        let settings = makeAvailability(bufferMinutes: 0)
        #expect(warnings(input(start: "11:00", settings: settings, appointments: [before])).isEmpty)
    }

    @Test("A cancelled visit and a no-show are not neighbours")
    func ignoresFreed() {
        let cancelled = makeVisit(start: friday("10:30"), status: .cancelled)
        let missed = makeVisit(start: friday("10:30"), status: .noShow)
        #expect(warnings(input(start: "11:00", appointments: [cancelled, missed])).isEmpty)
    }

    @Test("The visit being moved is not its own neighbour")
    func ignoringItself() {
        let own = makeVisit(start: friday("10:00"))
        #expect(warnings(input(start: "10:00", appointments: [own], ignoring: own.id)).isEmpty)
        #expect(warnings(input(start: "10:00", appointments: [own])) == [.overlap(with: own.id)])
    }

    @Test("Lunch warns by its name")
    func lunch() {
        #expect(warnings(input(start: "12:00")) == [.insideBreak(label: "Lunch")])
        #expect(warnings(input(start: "13:30")).isEmpty)
    }

    @Test("Before opening, after closing, and between two stretches", arguments: [
        ("08:00", SchedulingWarning.OutsideHours.beforeOpening),
        ("18:30", SchedulingWarning.OutsideHours.afterClosing)
    ])
    func outside(time: String, kind: SchedulingWarning.OutsideHours) {
        #expect(warnings(input(start: time)) == [.outsideHours(kind)])
    }

    @Test("A visit between a morning and an evening stretch falls between them")
    func between() {
        var settings = makeAvailability(breaks: [])
        settings.weekly = [
            AvailabilityRule(weekday: 6, startMinutes: 540, endMinutes: 720),
            AvailabilityRule(weekday: 6, startMinutes: 840, endMinutes: 1_080)
        ]
        #expect(warnings(input(start: "12:15", minutes: 60, settings: settings))
            == [.outsideHours(.betweenStretches)])
        #expect(warnings(input(start: "10:00", minutes: 60, settings: settings)).isEmpty)
    }

    @Test("A visit that runs past closing time warns even when it starts inside her hours")
    func runsPastClosing() {
        #expect(warnings(input(start: "18:30", minutes: 90)) == [.outsideHours(.afterClosing)])
    }

    @Test("A weekday she does not work, and a day off, warn once")
    func closedDays() {
        #expect(warnings(input(start: "10:00", day: "2026-10-04")).contains(.closedDay))
        var settings = makeAvailability()
        settings.daysOff = [DayOff(
            id: UUID(), startDate: TestClock.date("2026-10-02 00:00"), endDate: TestClock.date("2026-10-03 00:00"),
            kind: .vacation
        )]
        #expect(warnings(input(start: "10:00", settings: settings)) == [.dayOff])
        #expect(warnings(input(start: "10:00", settings: settings, day: "2026-10-03")) == [.dayOff])
    }

    @Test("A blocked time warns")
    func blocked() {
        let block = makeBlock(start: friday("14:00"), minutes: 120)
        #expect(warnings(input(start: "15:00", blocks: [block])) == [.blocked])
        #expect(warnings(input(start: "16:00", blocks: [block])).isEmpty)
    }

    // MARK: - The patch test

    private func patchTest(_ result: PatchTestResult, daysBefore: Int) -> PatchTest {
        PatchTest(
            id: UUID(), clientID: UUID(), testedAt: TestClock.days(1, from: friday("10:00")).addingTimeInterval(
                TimeInterval(-daysBefore * 86_400 - 86_400)
            ),
            observedHours: 48, product: "Serum", area: nil, result: result, notes: nil
        )
    }

    @Test("A service that asks for a patch test warns when none is on record")
    func patchTestMissing() {
        let service = Service(name: "Brazilian Glow", durationMinutes: 60, requiresPatchTest: true)
        #expect(warnings(input(start: "10:00", service: service)) == [.missingPatchTest(hoursBefore: 48)])
        let other = Service(name: "Glow Facial", durationMinutes: 60)
        #expect(warnings(input(start: "10:00", service: other)).isEmpty)
    }

    @Test("A clean test before the visit clears it; a reaction, or a test after the visit, does not")
    func patchTestResults() {
        let service = Service(name: "Brazilian Glow", durationMinutes: 60, requiresPatchTest: true)
        let clean = patchTest(.noReaction, daysBefore: 5)
        #expect(warnings(input(start: "10:00", service: service, patchTests: [clean])).isEmpty)
        let reaction = patchTest(.reaction, daysBefore: 3)
        #expect(warnings(input(start: "10:00", service: service, patchTests: [clean, reaction]))
            == [.patchTestReaction])
        let mild = patchTest(.mildReaction, daysBefore: 3)
        #expect(warnings(input(start: "10:00", service: service, patchTests: [mild])) == [.patchTestReaction])
        var later = patchTest(.noReaction, daysBefore: 0)
        later.testedAt = friday("10:00").addingTimeInterval(3_600)
        #expect(warnings(input(start: "10:00", service: service, patchTests: [later]))
            == [.missingPatchTest(hoursBefore: 48)])
    }

    // MARK: - Contraindications

    @Test("A health answer that matches a contraindication warns with the match; no answer does not")
    func contraindication() {
        let service = Service(name: "Deep Cleansing", durationMinutes: 60, contraindications: ["pregnancy"])
        let yes = makeHealthForm(answers: ["pregnancy": .yes])
        let found = warnings(input(start: "10:00", service: service, form: yes))
        guard case .contraindicated(let matches) = found.first else {
            Issue.record("expected a contraindication, got \(found)")
            return
        }
        #expect(matches.map(\.token) == ["pregnancy"])
        #expect(warnings(input(start: "10:00", service: service, form: makeHealthForm(answers: ["pregnancy": .no])))
            .isEmpty)
    }

    @Test("Without a health form, a service with contraindications says there is nothing to check against")
    func noForm() {
        let service = Service(name: "Deep Cleansing", durationMinutes: 60, contraindications: ["pregnancy"])
        #expect(warnings(input(start: "10:00", service: service)) == [.noHealthForm])
        let none = Service(name: "Glow Facial", durationMinutes: 60)
        #expect(warnings(input(start: "10:00", service: none)).isEmpty)
    }

    @Test("A minor's form triggers the minor token")
    func minor() {
        let token = ContraindicationMatcher.minorToken
        let service = Service(name: "Peel", durationMinutes: 60, contraindications: [token])
        let form = makeHealthForm(answers: [:], isForMinor: true)
        let found = warnings(input(start: "10:00", service: service, form: form))
        #expect(found.count == 1)
    }

    // MARK: - Habits

    private func history(completed: Int, cancelled: Int, clientID: UUID) -> [Appointment] {
        var visits: [Appointment] = []
        for index in 0..<completed {
            visits.append(makeAppointment(clientID: clientID, daysFromNow: -(10 + index * 7), status: .completed))
        }
        for index in 0..<cancelled {
            visits.append(makeAppointment(
                clientID: clientID, daysFromNow: -(3 + index), hour: 15, status: .cancelled, cancelledBy: .client
            ))
        }
        return visits
    }

    @Test("A client who cancels often (HabitsCalculator) is mentioned; one who does not is not")
    func cancelsOften() {
        let often = UUID()
        let found = warnings(input(
            start: "10:00", clientID: often, clientAppointments: history(completed: 5, cancelled: 3, clientID: often)
        ))
        #expect(found == [.cancelsOften(cancelled: 3, noShows: 0)])
        let reliable = UUID()
        #expect(warnings(input(
            start: "10:00", clientID: reliable,
            clientAppointments: history(completed: 8, cancelled: 1, clientID: reliable)
        )).isEmpty)
    }

    @Test("A cancellation by the professional never counts as the client's habit")
    func professionalCancellations() {
        let client = UUID()
        var visits = history(completed: 5, cancelled: 0, clientID: client)
        for index in 0..<4 {
            visits.append(makeAppointment(
                clientID: client, daysFromNow: -(3 + index), hour: 15, status: .cancelled, cancelledBy: .professional
            ))
        }
        #expect(warnings(input(start: "10:00", clientID: client, clientAppointments: visits)).isEmpty)
    }

    // MARK: - Order and independence

    @Test("The time comes first, then the client's health, then her habits")
    func order() {
        let client = UUID()
        let service = Service(
            name: "Brazilian Glow", durationMinutes: 60, contraindications: ["pregnancy"], requiresPatchTest: true
        )
        let existing = makeVisit(start: friday("11:00"))
        let found = warnings(input(
            start: "11:30", appointments: [existing], service: service, clientID: client,
            clientAppointments: history(completed: 5, cancelled: 3, clientID: client),
            form: makeHealthForm(answers: ["pregnancy": .yes])
        ))
        let kinds = found.map(\.rank)
        #expect(kinds == kinds.sorted())
        #expect(found.first == .overlap(with: existing.id))
        #expect(found.last == .cancelsOften(cancelled: 3, noShows: 0))
        #expect(found.contains { if case .contraindicated = $0 { true } else { false } })
        #expect(found.contains(.missingPatchTest(hoursBefore: 48)))
    }

    @Test("Only the time warnings are about the schedule; the others never change the button")
    func scheduleConflicts() {
        #expect(SchedulingWarning.overlap(with: UUID()).isScheduleConflict)
        #expect(SchedulingWarning.insideBreak(label: "Lunch").isScheduleConflict)
        #expect(SchedulingWarning.outsideHours(.afterClosing).isScheduleConflict)
        #expect(SchedulingWarning.buffer(minutes: 15, neighbour: UUID()).isScheduleConflict)
        #expect(!SchedulingWarning.missingPatchTest(hoursBefore: 48).isScheduleConflict)
        #expect(!SchedulingWarning.noHealthForm.isScheduleConflict)
        #expect(!SchedulingWarning.cancelsOften(cancelled: 1, noShows: 0).isScheduleConflict)
    }
}
