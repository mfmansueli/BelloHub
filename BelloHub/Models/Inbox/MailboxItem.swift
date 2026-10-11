//
//  MailboxItem.swift
//  BelloHub
//

import Foundation

/// One item of her sealed mailbox as the server lists it (`inbox/{uid}/items/{itemId}`, API.md section 8): metadata
/// and, when small, the envelope itself. Larger envelopes come through `getMailboxItem`.
struct MailboxItem: Identifiable, Hashable, Codable, Sendable {
    let id: String
    var kind: MailboxKind
    var bookingId: String
    var keyId: String?
    var sizeBytes: Int
    var createdAt: Date
    var expiresAt: Date?
    var envelope: SealedEnvelope?
    /// Set when the envelope lives in Storage: fetch it with `getMailboxItem`.
    var storagePath: String?

    init(
        id: String, kind: MailboxKind, bookingId: String, keyId: String? = nil, sizeBytes: Int = 0, createdAt: Date,
        expiresAt: Date? = nil, envelope: SealedEnvelope? = nil, storagePath: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.bookingId = bookingId
        self.keyId = keyId
        self.sizeBytes = sizeBytes
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.envelope = envelope
        self.storagePath = storagePath
    }

    /// The envelope is here, or must be fetched.
    var needsFetch: Bool { envelope == nil }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = MailboxKind(persisted: try container.decodeIfPresent(String.self, forKey: .kind) ?? "intake")
        bookingId = try container.decodeIfPresent(String.self, forKey: .bookingId) ?? ""
        keyId = try container.decodeIfPresent(String.self, forKey: .keyId)
        sizeBytes = try container.decodeIfPresent(Int.self, forKey: .sizeBytes) ?? 0
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date(timeIntervalSince1970: 0)
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        envelope = try? container.decodeIfPresent(SealedEnvelope.self, forKey: .envelope)
        storagePath = try container.decodeIfPresent(String.self, forKey: .storagePath)
    }
}
