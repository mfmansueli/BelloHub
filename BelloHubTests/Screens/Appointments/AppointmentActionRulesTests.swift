//
//  AppointmentActionRulesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("AppointmentActionRules")
struct AppointmentActionRulesTests {
    private let start = TestClock.date("2026-10-01 15:00")

    private func visit(_ status: AppointmentStatus) -> Appointment {
        Appointment(
            clientID: UUID(), serviceName: "Glow", startsAt: start, endsAt: start.addingTimeInterval(90 * 60),
            status: status, createdAt: TestClock.days(-3)
        )
    }

    private struct Row: Sendable, CustomTestStringConvertible {
        let name: String
        let status: AppointmentStatus
        /// Minutes after the start (negative: before it).
        let minutes: Int
        let primary: AppointmentAction?
        let quick: [AppointmentAction]
        let secondary: [AppointmentAction]

        var testDescription: String { name }
    }

    private static let rows: [Row] = [
        Row(name: "booked, ahead", status: .booked, minutes: -120, primary: .beforeYouStart,
            quick: [.message, .runningLate], secondary: [.reschedule, .cancel]),
        Row(name: "confirmed, ahead", status: .confirmed, minutes: -1, primary: .beforeYouStart,
            quick: [.message, .runningLate], secondary: [.reschedule, .cancel]),
        Row(name: "booked, starts exactly now", status: .booked, minutes: 0, primary: .registerVisit,
            quick: [.complete, .beforeYouStart, .message], secondary: [.runningLate, .reschedule, .noShow, .cancel]),
        Row(name: "confirmed, in progress", status: .confirmed, minutes: 45, primary: .registerVisit,
            quick: [.complete, .beforeYouStart, .message], secondary: [.runningLate, .reschedule, .noShow, .cancel]),
        Row(name: "booked, ended but not closed", status: .booked, minutes: 90, primary: .complete,
            quick: [.registerVisit, .message], secondary: [.noShow, .reschedule, .cancel]),
        Row(name: "completed, no record", status: .completed, minutes: 200, primary: .registerVisit,
            quick: [.message], secondary: []),
        Row(name: "cancelled, ahead", status: .cancelled, minutes: -200, primary: nil, quick: [.message],
            secondary: []),
        Row(name: "no-show", status: .noShow, minutes: 200, primary: nil, quick: [.message], secondary: [])
    ]

    @Test("Each status and moment allows exactly its actions", arguments: rows)
    private func layout(row: Row) {
        let now = start.addingTimeInterval(TimeInterval(row.minutes * 60))
        let layout = AppointmentActionRules.layout(for: visit(row.status), now: now)

        #expect(layout.primary == row.primary)
        #expect(layout.quick == row.quick)
        #expect(layout.secondary == row.secondary)
    }

    @Test("A visit that has not started can never be marked a no-show or completed")
    func neverBeforeTheStart() {
        let layout = AppointmentActionRules.layout(for: visit(.booked), now: start.addingTimeInterval(-60))

        #expect(!layout.all.contains(.noShow))
        #expect(!layout.all.contains(.complete))
    }

    @Test("A cancelled booking or a no-show has nothing to document; a completed one leads to its record")
    func closedVisits() {
        for status in [AppointmentStatus.cancelled, .noShow] {
            let layout = AppointmentActionRules.layout(for: visit(status), now: start)
            #expect(layout.all == [.message], "\(status)")
        }
        let done = visit(.completed)
        #expect(AppointmentActionRules.layout(for: done, record: .none, now: start).primary == .registerVisit)
        #expect(AppointmentActionRules.layout(for: done, record: .draft, now: start).primary == .continueRecord)
        #expect(AppointmentActionRules.layout(for: done, record: .finalized, now: start).primary == .openRecord)
    }

    @Test("A draft started before the visit stays one tap away; completing never needs a record")
    func draftBeforeTheStart() {
        let ahead = AppointmentActionRules.layout(for: visit(.booked), record: .draft,
                                                  now: start.addingTimeInterval(-600))
        #expect(ahead.quick.first == .continueRecord)
        let ended = AppointmentActionRules.layout(for: visit(.booked), record: .none,
                                                  now: start.addingTimeInterval(100 * 60))
        #expect(ended.primary == .complete)
    }

    @Test("Every action appears at most once in a layout")
    func noRepeats() {
        for status in AppointmentStatus.allCases {
            for record in [AppointmentRecordState.none, .draft, .finalized] {
                for minutes in [-300, 0, 60, 300] {
                    let layout = AppointmentActionRules.layout(
                        for: visit(status), record: record, now: start.addingTimeInterval(TimeInterval(minutes * 60))
                    )
                    #expect(Set(layout.all).count == layout.all.count)
                }
            }
        }
    }
}
