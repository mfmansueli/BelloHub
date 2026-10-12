//
//  ConsentRecord.swift
//  BelloHub
//

import Foundation

/// The professional's own note that a client signed (or has not yet signed) a consent, for her control only (D55).
/// The app writes no consent text and collects no signature: the real paper is handled in person, outside the app.
/// What she keeps is a kind, a label in her own words, whether it is signed, the date, a note and, if she wants, a
/// photo or a file of the real signed document. The label, the note and the document are encrypted at rest.
///
/// The vault kind stays `consent`, so a record written before D55 (which carried a text version, a language and a
/// typed signature) is still read: it was signed, on its date, and the fields that no longer exist are ignored.
struct ConsentRecord: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var clientID: UUID
    /// The category: treatment, photos, guardian or something of her own. A signed `photos` record is what lets a
    /// photo be shared or shown in a portfolio (`PhotoConsentRules`).
    var kind: ConsentKind
    var isSigned: Bool
    /// When it was signed. Nil while it is not signed, or when she did not note the day.
    var signedAt: Date?
    var createdAt: Date
    /// The visit the paper belongs to, when she tied it to one. Optional: most documents are about the client, not one
    /// visit. Tying a document to a visit changes nothing about who can see the record.
    var recordID: UUID?

    // Encrypted at rest.
    /// Her own words ("Microblading consent, paper form"). Empty or nil shows the kind's title.
    var label: String?
    var note: String?
    var document: ConsentDocument?

    init(
        id: UUID,
        clientID: UUID,
        kind: ConsentKind,
        isSigned: Bool,
        signedAt: Date?,
        createdAt: Date,
        recordID: UUID? = nil,
        label: String? = nil,
        note: String? = nil,
        document: ConsentDocument? = nil
    ) {
        self.id = id
        self.clientID = clientID
        self.kind = kind
        self.isSigned = isSigned
        self.signedAt = signedAt
        self.createdAt = createdAt
        self.recordID = recordID
        self.label = label
        self.note = note
        self.document = document
    }

    private enum CodingKeys: String, CodingKey {
        case id, clientID, kind, isSigned, signedAt, createdAt, recordID, label, note, document
    }

    /// Reads the D55 shape and the shape before it. A record from before D55 has a `signedAt` and no `isSigned`: it
    /// was signed when it was written. Its `createdAt` is that date.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        clientID = try container.decode(UUID.self, forKey: .clientID)
        kind = try container.decodeIfPresent(ConsentKind.self, forKey: .kind) ?? ConsentKind.fallback
        let signed = try container.decodeIfPresent(Date.self, forKey: .signedAt)
        signedAt = signed
        isSigned = try container.decodeIfPresent(Bool.self, forKey: .isSigned) ?? (signed != nil)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? signed ?? .distantPast
        recordID = try container.decodeIfPresent(UUID.self, forKey: .recordID)
        label = try container.decodeIfPresent(String.self, forKey: .label)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        document = try container.decodeIfPresent(ConsentDocument.self, forKey: .document)
    }

    /// The moment the record stands for: the day it was signed, or the day she made the note.
    var effectiveDate: Date { signedAt ?? createdAt }
}
