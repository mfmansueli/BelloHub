//
//  CalendarEventDraft.swift
//  BelloHub
//

import Foundation

/// The event one visit should have in her "Bello Hub" calendar on this iPhone (7.6 Apple Calendar).
struct CalendarEventDraft: Hashable, Sendable {
    let appointmentID: UUID
    let title: String
    let start: Date
    let end: Date
}
