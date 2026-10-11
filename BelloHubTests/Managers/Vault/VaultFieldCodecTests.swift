//
//  VaultFieldCodecTests.swift
//  BelloHubTests
//

@testable import BelloHub
import CryptoKit
import Foundation
import Testing

/// A fixed key for tests, or none to simulate a locked app.
struct FixedKeyProvider: VaultKeyProviding {
    let key: SymmetricKey?

    func vaultKey() throws -> SymmetricKey {
        guard let key else { throw VaultError.locked }
        return key
    }
}

@Suite("VaultFieldCodec")
struct VaultFieldCodecTests {
    struct Sensitive: Codable, Equatable {
        var note: String
        var allergies: [String]
        var when: Date
    }

    private let id = UUID(uuidString: "11111111-2222-3333-4444-555555555555") ?? UUID()
    private let codec = VaultFieldCodec(keys: FixedKeyProvider(key: SymmetricKey(size: .bits256)))
    private let sample = Sensitive(note: "Sentinel-A91 reacts to fragrance", allergies: ["fragrance"],
                                   when: Date(timeIntervalSince1970: 1_790_000_000))

    @Test("A value round-trips through seal and open")
    func roundTrip() throws {
        let sealed = try codec.sealed(sample, model: "client", id: id, field: "sensitive")

        #expect(try codec.opened(Sensitive.self, from: sealed, model: "client", id: id, field: "sensitive") == sample)
    }

    @Test("The sealed bytes do not contain the text")
    func notReadable() throws {
        let sealed = try codec.sealed(sample, model: "client", id: id, field: "sensitive")

        #expect(sealed.range(of: Data("Sentinel-A91".utf8)) == nil)
        #expect(sealed.range(of: Data("fragrance".utf8)) == nil)
    }

    @Test("A sealed field opens only in the record, model and column it was written to")
    func bindingToRecordModelAndField() throws {
        let sealed = try codec.sealed(sample, model: "client", id: id, field: "sensitive")
        let otherID = UUID()

        #expect(throws: SecretBox.Failure.authenticationFailed) {
            try codec.opened(Sensitive.self, from: sealed, model: "client", id: otherID, field: "sensitive")
        }
        #expect(throws: SecretBox.Failure.authenticationFailed) {
            try codec.opened(Sensitive.self, from: sealed, model: "appointment", id: id, field: "sensitive")
        }
        #expect(throws: SecretBox.Failure.authenticationFailed) {
            try codec.opened(Sensitive.self, from: sealed, model: "client", id: id, field: "privateNote")
        }
    }

    @Test("A different vault key cannot open it")
    func wrongKey() throws {
        let sealed = try codec.sealed(sample, model: "client", id: id, field: "sensitive")
        let other = VaultFieldCodec(keys: FixedKeyProvider(key: SymmetricKey(size: .bits256)))

        #expect(throws: SecretBox.Failure.authenticationFailed) {
            try other.opened(Sensitive.self, from: sealed, model: "client", id: id, field: "sensitive")
        }
    }

    @Test("A locked vault can neither seal nor open")
    func locked() throws {
        let sealed = try codec.sealed(sample, model: "client", id: id, field: "sensitive")
        let lockedCodec = VaultFieldCodec(keys: FixedKeyProvider(key: nil))

        #expect(throws: VaultError.locked) { try lockedCodec.sealed(sample, model: "client", id: id, field: "x") }
        #expect(throws: VaultError.locked) {
            try lockedCodec.opened(Sensitive.self, from: sealed, model: "client", id: id, field: "sensitive")
        }
    }

    @Test("Raw bytes (photos) round-trip and tampering is detected")
    func photoBytes() throws {
        let photo = Data((0..<2_000).map { UInt8($0 % 251) })
        var sealed = try codec.sealData(photo, model: "photo", id: id, field: "image")

        #expect(try codec.openData(sealed, model: "photo", id: id, field: "image") == photo)
        sealed[sealed.startIndex + 100] ^= 0x80
        #expect(throws: SecretBox.Failure.authenticationFailed) {
            try codec.openData(sealed, model: "photo", id: id, field: "image")
        }
    }

    @Test("Associated data is model, lowercase id and field, in that order")
    func associatedDataFormat() {
        let data = VaultFieldCodec.associatedData(model: "client", id: id, field: "sensitive")

        #expect(String(bytes: data, encoding: .utf8) == "client|11111111-2222-3333-4444-555555555555|sensitive")
    }
}
