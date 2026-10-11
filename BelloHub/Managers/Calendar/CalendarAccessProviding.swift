//
//  CalendarAccessProviding.swift
//  BelloHub
//

/// Her iPhone calendar behind a protocol, so the Integrations screen is tested without EventKit and without the
/// system dialog. Only access is modelled here; the events are written by a `CalendarEventWriting`.
protocol CalendarAccessProviding: Sendable {
    func status() -> CalendarAccessStatus
    /// Asks for full access (the only level that allows a two-way sync); iOS may answer with write-only access.
    func requestFullAccess() async -> CalendarAccessStatus
}
