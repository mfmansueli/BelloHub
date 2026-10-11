//
//  VaultFieldCodec.swift
//  BelloHub
//

import CryptoKit
import Foundation

/// Encrypts and decrypts the sensitive fields of a record (D26, docs/05-DATA-MODEL.md section 1). The
/// associated data is `model|id|field`, so a sealed field only opens in the exact column of the exact record it
/// was written to: copying it to another record, or another field, fails authentication.
///
/// Sensitive fields of one record are encoded together as one JSON value and sealed once (`sealed`), which keeps
/// the schema small and the nonce count low. Photo bytes go through `sealData`.
struct VaultFieldCodec: Sendable {
    let keys: any VaultKeyProviding

    static func associatedData(model: String, id: UUID, field: String) -> Data {
        Data("\(model)|\(id.uuidString.lowercased())|\(field)".utf8)
    }

    func sealData(_ plaintext: Data, model: String, id: UUID, field: String) throws -> Data {
        try SecretBox.seal(plaintext, using: keys.vaultKey(),
                           authenticating: Self.associatedData(model: model, id: id, field: field))
    }

    func openData(_ sealed: Data, model: String, id: UUID, field: String) throws -> Data {
        try SecretBox.open(sealed, using: keys.vaultKey(),
                           authenticating: Self.associatedData(model: model, id: id, field: field))
    }

    /// JSON with sorted keys, sealed. Dates are ISO 8601 so the bytes do not depend on the device's locale.
    func sealed<Value: Encodable>(_ value: Value, model: String, id: UUID, field: String) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try sealData(encoder.encode(value), model: model, id: id, field: field)
    }

    func opened<Value: Decodable>(
        _ type: Value.Type, from sealed: Data, model: String, id: UUID, field: String
    ) throws -> Value {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: openData(sealed, model: model, id: id, field: field))
    }
}
