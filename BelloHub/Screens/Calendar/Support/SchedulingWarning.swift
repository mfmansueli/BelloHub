//
//  SchedulingWarning.swift
//  BelloHub
//

import Foundation

/// One thing she may want to know before she books (or moves) a visit. Working outside published hours remains her
/// decision; an occupied visit or time block cannot be overridden.
enum SchedulingWarning: Hashable, Sendable {
    /// Where the "way out" is the time: moving the visit or closing the time would fix it.
    case inThePast
    case overlap(with: UUID)
    case blocked
    case dayOff
    case closedDay
    case outsideHours(OutsideHours)
    case insideBreak(label: String)
    /// Less than her buffer between this visit and the neighbouring one.
    case buffer(minutes: Int, neighbour: UUID)

    // The client and the service: the time can be fine and these still matter.
    case missingPatchTest(hoursBefore: Int)
    case patchTestReaction
    case contraindicated([ContraindicationReport.Match])
    /// The service lists contraindications and the client has no health form to check them against.
    case noHealthForm
    case cancelsOften(cancelled: Int, noShows: Int)

    enum OutsideHours: Hashable, Sendable {
        case beforeOpening
        case afterClosing
        case betweenStretches
    }

    /// The warnings about the time itself. When any is present the primary button says "Book anyway".
    var isScheduleConflict: Bool {
        switch self {
        case .inThePast, .overlap, .blocked, .dayOff, .closedDay, .outsideHours, .insideBreak, .buffer: true
        case .missingPatchTest, .patchTestReaction, .contraindicated, .noHealthForm, .cancelsOften: false
        }
    }

    var preventsBooking: Bool {
        switch self {
        case .overlap, .blocked: true
        default: false
        }
    }

    /// The order they are shown in: the time first, then the client's health, then her habits.
    var rank: Int {
        switch self {
        case .inThePast: 0
        case .overlap: 1
        case .blocked: 2
        case .dayOff: 3
        case .closedDay: 4
        case .outsideHours: 5
        case .insideBreak: 6
        case .buffer: 7
        case .contraindicated: 8
        case .noHealthForm: 9
        case .patchTestReaction: 10
        case .missingPatchTest: 11
        case .cancelsOften: 12
        }
    }
}
