//
//  AppointmentStatus.swift
//  BelloHub
//

/// Where an appointment is in its life. `noShow` is set by the professional after the time has passed.
enum AppointmentStatus: String, PersistedEnum {
    case booked
    case confirmed
    case completed
    case cancelled
    case noShow

    static let fallback = AppointmentStatus.booked

    /// Still ahead of her and holding a time in the calendar.
    var holdsTime: Bool {
        self == .booked || self == .confirmed
    }
}
