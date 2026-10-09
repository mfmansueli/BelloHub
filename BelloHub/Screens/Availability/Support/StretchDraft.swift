//
//  StretchDraft.swift
//  BelloHub
//

import Foundation

/// One working stretch while she edits a day: minutes after midnight, with an identity so the list can add and remove
/// rows without confusing two equal ones.
struct StretchDraft: Identifiable, Hashable, Sendable {
    let id: UUID
    var startMinutes: Int
    var endMinutes: Int

    init(id: UUID = UUID(), startMinutes: Int, endMinutes: Int) {
        self.id = id
        self.startMinutes = startMinutes
        self.endMinutes = endMinutes
    }
}
