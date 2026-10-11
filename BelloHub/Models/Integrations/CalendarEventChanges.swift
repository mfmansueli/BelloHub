//
//  CalendarEventChanges.swift
//  BelloHub
//

import Foundation

/// What has to change in her "Bello Hub" calendar so it shows her visits again: events to add, to change and to
/// remove. Built by `CalendarEventPlanner.changes(drafts:existing:)`, applied by a `CalendarEventWriting`.
struct CalendarEventChanges: Hashable, Sendable {
    struct Update: Hashable, Sendable {
        let identifier: String
        let draft: CalendarEventDraft
    }

    var creates: [CalendarEventDraft] = []
    var updates: [Update] = []
    var deletes: [String] = []

    var isEmpty: Bool { creates.isEmpty && updates.isEmpty && deletes.isEmpty }
}
