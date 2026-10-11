//
//  SwiftDataClientRecordRepository.swift
//  BelloHub
//

import Foundation
import os
import SwiftData

/// The vault on SwiftData (synced by CloudKit when the container is built with a CloudKit database). It is the only
/// place that reads and writes the store and the only place that encrypts and decrypts sensitive fields.
/// An actor with its own `ModelContext`: domain values cross the boundary as `Sendable` structs, never `@Model`
/// instances (docs/04-ARCHITECTURE.md section 6).
actor SwiftDataClientRecordRepository: ModelActor, ClientRecordRepository {
    nonisolated let modelContainer: ModelContainer
    nonisolated let modelExecutor: any ModelExecutor
    let codec: VaultFieldCodec
    let clock: @Sendable () -> Date
    let changes = VaultChangeBroadcaster()
    private let logger = Logger(subsystem: "app.bellohub", category: "vault")

    init(
        modelContainer: ModelContainer,
        codec: VaultFieldCodec,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.modelContainer = modelContainer
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(modelContainer))
        self.codec = codec
        self.clock = clock
    }

    // MARK: - Generic access (used by the protocol extensions)

    func item(kind: VaultKind, id: UUID) throws -> VaultItem? {
        let raw = kind.rawValue
        var descriptor = FetchDescriptor<VaultItem>(predicate: #Predicate { $0.kindRaw == raw && $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func items(kind: VaultKind) throws -> [VaultItem] {
        let raw = kind.rawValue
        return try modelContext.fetch(FetchDescriptor<VaultItem>(predicate: #Predicate { $0.kindRaw == raw }))
    }

    func items(kind: VaultKind, ownerID: UUID) throws -> [VaultItem] {
        let raw = kind.rawValue
        return try modelContext.fetch(FetchDescriptor<VaultItem>(
            predicate: #Predicate { $0.kindRaw == raw && $0.ownerID == ownerID }
        ))
    }

    /// Decodes a stored item. Throws `VaultError.locked` while the app is locked and `VaultRepositoryError.unreadable`
    /// for anything else that cannot be read back.
    func value<Value: VaultStorable>(_ type: Value.Type, from item: VaultItem) throws -> Value {
        do {
            let sensitive = try item.sealed.map {
                try codec.openData($0, model: Value.kind.rawValue, id: item.id, field: "sensitive")
            }
            return try VaultCoding.merge(type, plain: item.plain, sensitive: sensitive)
        } catch let error as VaultError {
            throw error
        } catch {
            logger.error("unreadable kind=\(Value.kind.rawValue, privacy: .public) id=\(item.id, privacy: .public)")
            throw VaultRepositoryError.unreadable
        }
    }

    /// Decodes every item, leaving out the ones that cannot be read so one damaged record never hides the rest.
    /// A locked vault fails the whole call (nothing can be read), and so does a vault where **every** item is
    /// unreadable (the wrong key): that must never look like an empty vault.
    func values<Value: VaultStorable>(_ type: Value.Type, from items: [VaultItem]) throws -> [Value] {
        var unreadable = 0
        let decoded: [Value] = try items.compactMap { item in
            do {
                return try value(type, from: item)
            } catch VaultRepositoryError.unreadable {
                unreadable += 1
                return nil
            }
        }
        if !items.isEmpty && unreadable == items.count { throw VaultRepositoryError.unreadable }
        return decoded
    }

    /// Inserts or updates the item for `value`. Returns true when it was inserted.
    @discardableResult
    func upsert<Value: VaultStorable>(_ value: Value, createdAt: Date? = nil) throws -> Bool {
        let (plain, sensitive) = try VaultCoding.split(value)
        let sealed = try sensitive.map {
            try codec.sealData($0, model: Value.kind.rawValue, id: value.id, field: "sensitive")
        }
        let now = clock()
        let existing = try item(kind: Value.kind, id: value.id)
        let target = existing ?? VaultItem(id: value.id, kindRaw: Value.kind.rawValue, createdAt: createdAt ?? now,
                                            updatedAt: now)
        if existing == nil { modelContext.insert(target) }
        let index = value.index
        target.ownerID = index.ownerID
        target.secondaryID = index.secondaryID
        target.dateA = index.dateA
        target.dateB = index.dateB
        target.textKey = index.textKey
        target.statusRaw = index.statusRaw
        target.plain = plain
        target.sealed = sealed
        target.updatedAt = now
        return existing == nil
    }

    func commit() throws {
        try modelContext.save()
        changes.notify()
    }

    func delete(_ items: [VaultItem]) {
        items.forEach { modelContext.delete($0) }
    }

    func deleteItems(kind: VaultKind, ownerID: UUID) throws {
        delete(try items(kind: kind, ownerID: ownerID))
    }
}
