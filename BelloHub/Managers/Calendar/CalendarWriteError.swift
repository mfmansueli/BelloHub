//
//  CalendarWriteError.swift
//  BelloHub
//

/// Why the "Bello Hub" calendar could not be written.
enum CalendarWriteError: Error, Equatable {
    /// The iPhone has no calendar account that can hold a new calendar.
    case noSource
}
