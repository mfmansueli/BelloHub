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
        Row(name: "booked, starts exactly now", status: .booked, minutes: 0, primary: .beforeYouStart,
            quick: [.complete, .message, .runningLate], secondary: [.reschedule, .noShow, .cancel]),
        Row(name: "confirmed, in progress", status: .confirmed, minutes: 45, primary: .beforeYouStart,
            quick: [.complete, .message, .runningLate], secondary: [.reschedule, .noShow, .cancel]),
        Row(name: "booked, ended but not closed", status: .booked, minutes: 90, primary: .complete,
            quick: [.message], secondary: [.noShow, .reschedule, .cancel]),
        Row(name: "completed", status: .completed, minutes: 200, primary: nil, quick: [.message], secondary: []),
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

    @Test("A closed visit can only be written to")
    func closedVisits() {
        for status in [AppointmentStatus.completed, .cancelled, .noShow] {
            let layout = AppointmentActionRules.layout(for: visit(status), now: start)
            #expect(layout.all == [.message], "\(status)")
        }
    }

    @Test("Every action appears at most once in a layout")
    func noRepeats() {
        for status in AppointmentStatus.allCases {
            for minutes in [-300, 0, 60, 300] {
                let layout = AppointmentActionRules.layout(
                    for: visit(status), now: start.addingTimeInterval(TimeInterval(minutes * 60))
                )
                #expect(Set(layout.all).count == layout.all.count)
            }
        }
    }
}
