//
//  Client.swift
//  BelloHub
//

import Foundation

/// A client of the professional (docs/05-DATA-MODEL.md). Lives only in the vault (iPhone and her iCloud). The names,
/// phone and dates are stored in the clear so lists, search and notifications work; `importantNote`, `allergies`,
/// `sensitivities`, `preferences`, `recurringRequests` and `stopReason` are encrypted by the repository.
struct Client: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    var phoneE164: String?
    var email: String?
    var tagIDs: [UUID]
    var source: ClientSource
    var birthday: Birthday?
    var isArchived: Bool
    /// She cannot book on her own; the professional can still book her.
    var onlineBookingStopped: Bool
    var remindersEnabled: Bool
    /// "Start her count from zero": no-shows before this moment no longer count. The history stays.
    var noShowCountResetAt: Date?
    var createdAt: Date
    var updatedAt: Date

    // Encrypted at rest.
    var importantNote: String?
    var allergies: [String]
    var sensitivities: [String]
    var preferences: [String]
    var recurringRequests: [String]
    var stopReason: String?

    init(
        id: UUID = UUID(),
        name: String,
        phoneE164: String? = nil,
        email: String? = nil,
        tagIDs: [UUID] = [],
        source: ClientSource = .manual,
        birthday: Birthday? = nil,
        isArchived: Bool = false,
        onlineBookingStopped: Bool = false,
        remindersEnabled: Bool = true,
        noShowCountResetAt: Date? = nil,
        createdAt: Date,
        updatedAt: Date? = nil,
        importantNote: String? = nil,
        allergies: [String] = [],
        sensitivities: [String] = [],
        preferences: [String] = [],
        recurringRequests: [String] = [],
        stopReason: String? = nil
    ) {
        self.id = id
        self.name = name
        self.phoneE164 = phoneE164
        self.email = email
        self.tagIDs = tagIDs
        self.source = source
        self.birthday = birthday
        self.isArchived = isArchived
        self.onlineBookingStopped = onlineBookingStopped
        self.remindersEnabled = remindersEnabled
        self.noShowCountResetAt = noShowCountResetAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.importantNote = importantNote
        self.allergies = allergies
        self.sensitivities = sensitivities
        self.preferences = preferences
        self.recurringRequests = recurringRequests
        self.stopReason = stopReason
    }
}
