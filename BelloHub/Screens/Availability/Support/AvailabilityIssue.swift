//
//  AvailabilityIssue.swift
//  BelloHub
//

/// Why a change to her hours, a break or days off cannot be saved. The sheets say so under the field instead of failing
/// after the tap.
enum AvailabilityIssue: Error, Equatable, Sendable {
    /// A stretch (or a break) ends at or before its start.
    case order
    /// A working stretch shorter than the shortest bookable time.
    case tooShort
    /// Two stretches of one day overlap.
    case overlap
}
