//
//  RepositoryFlavor.swift
//  BelloHubTests
//

@testable import BelloHub
import CryptoKit
import Foundation
import Testing

/// The two vault implementations the contract tests run against. They must behave identically.
enum RepositoryFlavor: String, CaseIterable, Sendable, CustomTestStringConvertible {
    case inMemory
    case swiftData

    var testDescription: String { rawValue }

    func make(clock: MutableClock = MutableClock()) throws -> any ClientRecordRepository {
        switch self {
        case .inMemory:
            return InMemoryClientRecordRepository(clock: { clock.now })
        case .swiftData:
            let container = try VaultContainerFactory.make(storage: .inMemory)
            let codec = VaultFieldCodec(keys: FixedKeyProvider(key: SymmetricKey(size: .bits256)))
            return SwiftDataClientRecordRepository(modelContainer: container, codec: codec, clock: { clock.now })
        }
    }
}
