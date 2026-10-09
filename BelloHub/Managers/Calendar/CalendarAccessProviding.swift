//
//  CalendarAccessProviding.swift
//  BelloHub
//

/// Her iPhone calendar behind a protocol, so the Integrations screen is tested without EventKit and without the
/// system dialog. Only access is modelled here; writing appointments through to the calendar is S6's write-through.
protocol CalendarAccessProviding: Sendable {
    func status() -> CalendarAccessStatus
    /// Asks for full access (the only level that allows a two-way sync); iOS may answer with write-only access.
    func requestFullAccess() async -> CalendarAccessStatus
}
