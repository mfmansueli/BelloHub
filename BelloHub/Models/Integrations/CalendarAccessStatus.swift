//
//  CalendarAccessStatus.swift
//  BelloHub
//

/// What the iPhone lets the app do with her calendar (EventKit's statuses, in the app's words). Writing appointments
/// to her calendar needs `full`; iOS 17 and later offer `writeOnly` as well, which is enough to add events but not to
/// read them back, so a two-way sync is honest only with full access.
enum CalendarAccessStatus: Equatable, Sendable {
    case notDetermined
    case full
    case writeOnly
    /// Denied by her, or restricted by a profile: she changes it in Settings, not here.
    case denied

    var canWrite: Bool { self == .full || self == .writeOnly }
}
