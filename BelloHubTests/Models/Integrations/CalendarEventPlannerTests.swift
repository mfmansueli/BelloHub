//
//  CalendarEventPlannerTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("CalendarEventPlanner")
struct CalendarEventPlannerTests {
    private let ana = UUID()
    private let start = TestClock.date("2026-10-02 10:00")

    private func makeDraft(_ id: UUID, title: String = "Bello Hub appointment", hour: Int = 10) -> CalendarEventDraft {
        let begin = TestClock.date(String(format: "2026-10-02 %02d:00", hour))
        return CalendarEventDraft(appointmentID: id, title: title, start: begin, end: begin.addingTimeInterval(3_600))
    }

    private func makeRecord(_ identifier: String, of draft: CalendarEventDraft) -> CalendarEventRecord {
        CalendarEventRecord(
            identifier: identifier, appointmentID: draft.appointmentID, title: draft.title, start: draft.start,
            end: draft.end
        )
    }

    @Test("Cancelled visits and no-shows leave the calendar; booked, confirmed and completed visits stay")
    func whichVisits() {
        let statuses: [AppointmentStatus] = [.booked, .confirmed, .completed, .cancelled, .noShow]
        let visits = statuses.enumerated().map { index, status in
            makeVisit(clientID: ana, start: start.addingTimeInterval(TimeInterval(index * 3_600)), status: status)
        }
        let drafts = CalendarEventPlanner.drafts(
            appointments: visits, clientNames: [ana: "Ana Costa"], showsNames: false, genericTitle: "Visit"
        )
        #expect(drafts.map(\.appointmentID) == Array(visits.prefix(3)).map(\.id))
        #expect(drafts.first?.start == start)
        #expect(drafts.first?.end == start.addingTimeInterval(3_600))
    }

    @Test("Names reach the calendar only when she lets them reach the lock screen")
    func titles() {
        let visit = makeVisit(clientID: ana, start: start, serviceName: "Glow Facial")
        let hidden = CalendarEventPlanner.drafts(
            appointments: [visit], clientNames: [ana: "Ana Costa"], showsNames: false, genericTitle: "Visit"
        )
        let shown = CalendarEventPlanner.drafts(
            appointments: [visit], clientNames: [ana: "Ana Costa"], showsNames: true, genericTitle: "Visit"
        )
        let unknown = CalendarEventPlanner.drafts(
            appointments: [visit], clientNames: [:], showsNames: true, genericTitle: "Visit"
        )
        #expect(hidden.first?.title == "Visit")
        #expect(shown.first?.title == "Ana Costa · Glow Facial")
        #expect(unknown.first?.title == "Visit", "a visit of a deleted client never shows an empty name")
    }

    @Test("An empty calendar gets one event per visit")
    func createsAll() {
        let drafts = [makeDraft(UUID()), makeDraft(UUID(), hour: 11)]
        let changes = CalendarEventPlanner.changes(drafts: drafts, existing: [])
        #expect(changes.creates == drafts)
        #expect(changes.updates.isEmpty && changes.deletes.isEmpty)
    }

    @Test("A calendar that already matches needs nothing")
    func nothingToDo() {
        let draft = makeDraft(UUID())
        let changes = CalendarEventPlanner.changes(drafts: [draft], existing: [makeRecord("e1", of: draft)])
        #expect(changes.isEmpty)
    }

    @Test("A moved or renamed visit updates its event in place")
    func updates() {
        let id = UUID()
        let old = makeDraft(id, hour: 10)
        let moved = makeDraft(id, hour: 14)
        let changes = CalendarEventPlanner.changes(drafts: [moved], existing: [makeRecord("e1", of: old)])
        #expect(changes.updates == [.init(identifier: "e1", draft: moved)])
        #expect(changes.creates.isEmpty && changes.deletes.isEmpty)
    }

    @Test("Events of no visit, of a visit that left, and second copies of one visit are removed")
    func deletes() {
        let kept = makeDraft(UUID())
        let gone = makeDraft(UUID(), hour: 12)
        let foreign = CalendarEventRecord(
            identifier: "z-foreign", appointmentID: nil, title: "Lunch", start: start, end: start.addingTimeInterval(60)
        )
        let changes = CalendarEventPlanner.changes(
            drafts: [kept],
            existing: [makeRecord("a", of: kept), makeRecord("b", of: kept), makeRecord("c", of: gone), foreign]
        )
        #expect(changes.creates.isEmpty && changes.updates.isEmpty)
        #expect(Set(changes.deletes) == ["b", "c", "z-foreign"])
    }

    @Test("The event address carries the visit id and nothing else, and reads back")
    func address() throws {
        let id = UUID()
        let url = try #require(CalendarEventPlanner.url(for: id))
        #expect(url.absoluteString == "bellohub-visit:\(id.uuidString)")
        #expect(CalendarEventPlanner.appointmentID(from: url) == id)
        #expect(CalendarEventPlanner.appointmentID(from: URL(string: "https://example.com/\(id.uuidString)")) == nil)
        #expect(CalendarEventPlanner.appointmentID(from: nil) == nil)
    }

    @Test("The mirrored stretch is yesterday to three months ahead")
    func window() {
        let window = CalendarEventPlanner.window(now: TestClock.now)
        #expect(window.start == TestClock.now.addingTimeInterval(-86_400))
        #expect(window.end == TestClock.now.addingTimeInterval(90 * 86_400))
    }
}
