//
//  Appointment.swift
//  BelloHub
//

import Foundation

/// Why a manual visit saved on the phone still needs attention before it appears on the booking site.
enum ManualBookingSyncIssue: String, Codable, Hashable, Sendable {
    case conflict
    case failed
}

/// A visit in the calendar. The time, status and names are in the clear (lists, notifications and conflict
/// detection need them); `privateNote` is encrypted at rest.
struct Appointment: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var clientID: UUID
    var serviceID: UUID?
    /// Copied at booking time; the service may be renamed or deleted later.
    var serviceName: String
    var startsAt: Date
    var endsAt: Date
    /// Service plus add-ons plus guests in sequence (D19). `endsAt - startsAt` for a booked visit.
    var totalMinutes: Int
    var status: AppointmentStatus
    var cancelledAt: Date?
    var cancelledBy: CancelledBy?
    /// Cancelled by the client inside the policy's free window cutoff (`CancellationEvaluator` decides).
    var isLateCancellation: Bool
    var origin: AppointmentOrigin
    /// The server's id for a visit booked through the link.
    var bookingID: String?
    /// Set only after the server definitively refused a manual booking. Nil in older stored visits.
    var manualBookingSyncIssue: ManualBookingSyncIssue?
    var visitType: VisitType
    /// The visit this one checks after a reaction.
    var linkedAppointmentID: UUID?
    var addOns: [AppointmentAddOn]
    /// Names of guests, booked back to back with the same service.
    var guests: [String]
    /// Web bookings know the number of guests but not their names; nil for older local visits.
    var guestCount: Int?
    var numberOfGuests: Int { max(guestCount ?? guests.count, guests.count) }
    /// The service's timing when this visit was created; later catalog edits must not reshape it on retry.
    var serviceTiming: VisitTiming?
    /// The service duration when this visit was created, needed to preserve the web booking's offer.
    var serviceMinutes: Int?
    var sessionPlanID: UUID?
    var rescheduleCount: Int
    /// When she opened the reminder chat with the text ready (D31). It proves neither sending nor delivery.
    var reminderSentAt: Date?
    /// When she said she sent the reminder herself (routine-a item 6): her own statement, shown as "marked as sent by
    /// you". Optional and added later, so visits stored before it read as nil.
    var reminderMarkedSentAt: Date?
    var clientConfirmedAt: Date?
    var lateByMinutes: Int?
    /// A no-show the professional chose not to count (D13).
    var noShowForgiven: Bool
    var createdAt: Date
    var updatedAt: Date

    // Encrypted at rest.
    var privateNote: String?

    init(
        id: UUID = UUID(),
        clientID: UUID,
        serviceID: UUID? = nil,
        serviceName: String,
        startsAt: Date,
        endsAt: Date,
        totalMinutes: Int? = nil,
        status: AppointmentStatus = .booked,
        cancelledAt: Date? = nil,
        cancelledBy: CancelledBy? = nil,
        isLateCancellation: Bool = false,
        origin: AppointmentOrigin = .manual,
        bookingID: String? = nil,
        manualBookingSyncIssue: ManualBookingSyncIssue? = nil,
        visitType: VisitType = .treatment,
        linkedAppointmentID: UUID? = nil,
        addOns: [AppointmentAddOn] = [],
        guests: [String] = [],
        guestCount: Int? = nil,
        serviceTiming: VisitTiming? = nil,
        serviceMinutes: Int? = nil,
        sessionPlanID: UUID? = nil,
        rescheduleCount: Int = 0,
        reminderSentAt: Date? = nil,
        reminderMarkedSentAt: Date? = nil,
        clientConfirmedAt: Date? = nil,
        lateByMinutes: Int? = nil,
        noShowForgiven: Bool = false,
        createdAt: Date,
        updatedAt: Date? = nil,
        privateNote: String? = nil
    ) {
        self.id = id
        self.clientID = clientID
        self.serviceID = serviceID
        self.serviceName = serviceName
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.totalMinutes = totalMinutes ?? Int(endsAt.timeIntervalSince(startsAt) / 60)
        self.status = status
        self.cancelledAt = cancelledAt
        self.cancelledBy = cancelledBy
        self.isLateCancellation = isLateCancellation
        self.origin = origin
        self.bookingID = bookingID
        self.manualBookingSyncIssue = manualBookingSyncIssue
        self.visitType = visitType
        self.linkedAppointmentID = linkedAppointmentID
        self.addOns = addOns
        self.guests = guests
        self.guestCount = guestCount
        self.serviceTiming = serviceTiming
        self.serviceMinutes = serviceMinutes
        self.sessionPlanID = sessionPlanID
        self.rescheduleCount = rescheduleCount
        self.reminderSentAt = reminderSentAt
        self.reminderMarkedSentAt = reminderMarkedSentAt
        self.clientConfirmedAt = clientConfirmedAt
        self.lateByMinutes = lateByMinutes
        self.noShowForgiven = noShowForgiven
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.privateNote = privateNote
    }

    var interval: DateInterval {
        DateInterval(start: startsAt, end: max(endsAt, startsAt))
    }
}
