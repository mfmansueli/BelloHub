//
//  PublishAvailabilityRequest.swift
//  BelloHub
//

import Foundation

/// The request of `publishAvailability` (firebase/functions/API.md section 6.2): when she can be booked and which
/// stretches
/// of her own agenda are taken. `busy` carries no names and no reasons, only that a stretch is occupied.
struct PublishAvailabilityRequest: Encodable, Equatable, Sendable {
    var timeZoneID: String
    var weekly: [Weekly]
    var breaks: [Break]
    var daysOff: [DayOff]
    var bufferMinutes: Int
    var minNoticeHours: Int
    var maxDaysAhead: Int
    /// D56: the grid of start times; 0 is "match the service".
    var slotStepMinutes: Int
    /// D56: "Keep my day compact".
    var compactDay: Bool
    var busy: [Busy]
    var noShow: NoShow

    struct Weekly: Encodable, Equatable, Sendable {
        /// 1 is Sunday, as in the app's calendar.
        var weekday: Int
        var startMinutes: Int
        var endMinutes: Int
    }

    struct Break: Encodable, Equatable, Sendable {
        var weekday: Int?
        var startMinutes: Int
        var endMinutes: Int
    }

    /// Inclusive days, `YYYY-MM-DD` in the business time zone.
    struct DayOff: Encodable, Equatable, Sendable {
        var startDate: String
        var endDate: String
    }

    struct Busy: Encodable, Equatable, Sendable {
        /// `appointment` gets the buffer around it, `block` does not.
        var kind: String
        /// Opaque visit identifier, used only to avoid counting a registered manual booking twice.
        var appointmentId: String?
        var startsAt: Date
        var endsAt: Date
        /// D56, appointments only: the visit's extra and processing time, sent only when not 0.
        var prepMinutes: Int?
        var cleanupMinutes: Int?
        var processingStartMinutes: Int?
        var processingMinutes: Int?

        init(kind: String, startsAt: Date, endsAt: Date, timing: VisitTiming = .noExtraTime,
             appointmentId: String? = nil) {
            self.kind = kind
            self.appointmentId = appointmentId
            self.startsAt = startsAt
            self.endsAt = endsAt
            let fields = PublishTimingFields(timing, visibleMinutes: Int(endsAt.timeIntervalSince(startsAt) / 60))
            prepMinutes = fields.prepMinutes
            cleanupMinutes = fields.cleanupMinutes
            processingStartMinutes = fields.processingStartMinutes
            processingMinutes = fields.processingMinutes
        }
    }

    struct NoShow: Encodable, Equatable, Sendable {
        var isOn: Bool
        var limit: Int
        var action: String
        var lateCancelCounts: Bool
        var countingMonths: Int
    }
}
