//
//  TreatmentRecord.swift
//  BelloHub
//

import Foundation

/// What was done in a visit. A record starts as a **draft** (saved as she goes, never locked) and becomes
/// **finalized** when she says so. A finalized record **locks 24 hours after it was finalized**: after `lockedAt` it
/// changes only through a `RecordCorrection` (`RecordLockPolicy`). The text fields are encrypted at rest.
///
/// `createdAt` is when the record was first written; `performedAt` is the day the treatment actually happened, which
/// can be earlier (she writes Monday's visit on Tuesday). Records from before `performedAt` existed have none: the
/// screens fall back to the linked appointment's start, or say the visit day was not noted (`RecordVisitDate`). No
/// date is ever invented for them.
struct TreatmentRecord: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var clientID: UUID
    var appointmentID: UUID?
    var serviceID: UUID?
    var serviceName: String
    var createdAt: Date
    /// When the treatment happened, as she set it. Nil on records from before this field existed.
    var performedAt: Date?
    var status: RecordStatus
    /// When she finalized it. Nil on a draft, and on records from before drafts existed (they were final at
    /// `createdAt`).
    var finalizedAt: Date?
    /// `.distantFuture` while a draft; the finalize time + 24 h once finalized.
    var lockedAt: Date
    var source: RecordSource
    var result: RecordResult
    /// True when the on-device AI proposed the draft. It was always reviewed before saving.
    var aiAssisted: Bool

    // Encrypted at rest.
    var notes: String?
    var technique: String?
    var productsUsed: [String]
    var resultDetail: String?
    /// How the client reacted, in her words. `result == .reaction` is the quick marker; this is the detail.
    var reaction: String?
    var aftercare: String?
    var nextSessionSuggestion: String?
    /// What she wants to remember at the next visit ("try the 0.15 curl", "she asked for less volume"). Shown in
    /// "Before you start" under "Remember for today".
    var nextVisitReminder: String?
    /// Her answers to the template's own fields (everything but the ones that have a place above), by field key.
    /// Nil on a record saved before the treatment flow existed.
    var fieldEntries: [RecordFieldEntry]?

    init(
        id: UUID = UUID(),
        clientID: UUID,
        appointmentID: UUID? = nil,
        serviceID: UUID? = nil,
        serviceName: String,
        createdAt: Date,
        performedAt: Date? = nil,
        status: RecordStatus = .finalized,
        source: RecordSource = .manual,
        result: RecordResult = .neutral,
        aiAssisted: Bool = false,
        notes: String? = nil,
        technique: String? = nil,
        productsUsed: [String] = [],
        resultDetail: String? = nil,
        reaction: String? = nil,
        aftercare: String? = nil,
        nextSessionSuggestion: String? = nil,
        nextVisitReminder: String? = nil,
        fieldEntries: [RecordFieldEntry]? = nil
    ) {
        self.id = id
        self.clientID = clientID
        self.appointmentID = appointmentID
        self.serviceID = serviceID
        self.serviceName = serviceName
        self.createdAt = createdAt
        self.performedAt = performedAt
        self.status = status
        switch status {
        case .draft:
            self.finalizedAt = nil
            self.lockedAt = RecordLockPolicy.draftLockedAt
        case .finalized:
            self.finalizedAt = createdAt
            self.lockedAt = RecordLockPolicy.lockedAt(createdAt: createdAt)
        }
        self.source = source
        self.result = result
        self.aiAssisted = aiAssisted
        self.notes = notes
        self.technique = technique
        self.productsUsed = productsUsed
        self.resultDetail = resultDetail
        self.reaction = reaction
        self.aftercare = aftercare
        self.nextSessionSuggestion = nextSessionSuggestion
        self.nextVisitReminder = nextVisitReminder
        self.fieldEntries = fieldEntries
    }

    private enum CodingKeys: String, CodingKey {
        case id, clientID, appointmentID, serviceID, serviceName, createdAt, performedAt, status, finalizedAt
        case lockedAt, source, result, aiAssisted
        case notes, technique, productsUsed, resultDetail, reaction, aftercare, nextSessionSuggestion
        case nextVisitReminder, fieldEntries
    }

    /// Reads today's shape and every older one. A record from before drafts has no `status`: it was final when it
    /// was written, and its lock stays the one it was stored with. A missing `performedAt` stays nil on purpose.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        clientID = try container.decode(UUID.self, forKey: .clientID)
        appointmentID = try container.decodeIfPresent(UUID.self, forKey: .appointmentID)
        serviceID = try container.decodeIfPresent(UUID.self, forKey: .serviceID)
        serviceName = try container.decodeIfPresent(String.self, forKey: .serviceName) ?? ""
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        performedAt = try container.decodeIfPresent(Date.self, forKey: .performedAt)
        status = try container.decodeIfPresent(RecordStatus.self, forKey: .status) ?? .finalized
        finalizedAt = try container.decodeIfPresent(Date.self, forKey: .finalizedAt)
        lockedAt = try container.decodeIfPresent(Date.self, forKey: .lockedAt)
            ?? RecordLockPolicy.lockedAt(createdAt: createdAt)
        source = try container.decodeIfPresent(RecordSource.self, forKey: .source) ?? .fallback
        result = try container.decodeIfPresent(RecordResult.self, forKey: .result) ?? .fallback
        aiAssisted = try container.decodeIfPresent(Bool.self, forKey: .aiAssisted) ?? false
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        technique = try container.decodeIfPresent(String.self, forKey: .technique)
        productsUsed = try container.decodeIfPresent([String].self, forKey: .productsUsed) ?? []
        resultDetail = try container.decodeIfPresent(String.self, forKey: .resultDetail)
        reaction = try container.decodeIfPresent(String.self, forKey: .reaction)
        aftercare = try container.decodeIfPresent(String.self, forKey: .aftercare)
        nextSessionSuggestion = try container.decodeIfPresent(String.self, forKey: .nextSessionSuggestion)
        nextVisitReminder = try container.decodeIfPresent(String.self, forKey: .nextVisitReminder)
        fieldEntries = try container.decodeIfPresent([RecordFieldEntry].self, forKey: .fieldEntries)
    }

    var isDraft: Bool { status == .draft }

    /// Turns a draft into a finalized record at `now`. The 24-hour lock starts here, not at creation, so a draft
    /// left open overnight still gets its full day of direct edits after she finalizes it. Finalizing twice keeps
    /// the first time.
    mutating func finalize(at now: Date) {
        guard status == .draft else { return }
        status = .finalized
        finalizedAt = now
        lockedAt = RecordLockPolicy.lockedAt(createdAt: now)
    }
}
