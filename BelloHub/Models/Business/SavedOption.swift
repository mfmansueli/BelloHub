//
//  SavedOption.swift
//  BelloHub
//

import Foundation

/// A word or short phrase she saved to reuse in one list (a technique, a preference…). Records and clients keep the
/// text itself, never a reference: renaming or archiving an option changes what is offered next time and nothing
/// already written. The name is encrypted at rest (a sensitivity can be health information).
struct SavedOption: Identifiable, Hashable, Codable, Sendable, Positioned {
    let id: UUID
    var context: OptionContext
    var name: String
    var position: Int
    /// Archived options are no longer offered; they stay listed in Personalization to restore.
    var isArchived: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(), context: OptionContext, name: String, position: Int = 0, isArchived: Bool = false,
        createdAt: Date
    ) {
        self.id = id
        self.context = context
        self.name = name
        self.position = position
        self.isArchived = isArchived
        self.createdAt = createdAt
    }
}
