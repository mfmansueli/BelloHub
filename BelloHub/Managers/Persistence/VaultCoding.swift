//
//  VaultCoding.swift
//  BelloHub
//

import Foundation

/// Turns a `VaultStorable` into the two byte strings the store keeps (plain JSON and the sensitive part) and back.
/// Dates are encoded as exact seconds so a value round-trips unchanged.
enum VaultCoding {
    enum Failure: Error, Equatable {
        case notAnObject
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .deferredToDate
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        return decoder
    }

    /// Splits `value` into its clear JSON and the JSON of its sensitive keys (nil when there is none to seal).
    static func split<Value: VaultStorable>(_ value: Value) throws -> (plain: Data, sensitive: Data?) {
        let encoded = try makeEncoder().encode(value)
        let keys = Value.sensitiveKeys
        guard !keys.isEmpty else { return (encoded, nil) }
        guard var object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else {
            throw Failure.notAnObject
        }
        var secret: [String: Any] = [:]
        for key in keys {
            if let part = object.removeValue(forKey: key) { secret[key] = part }
        }
        let plain = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        let sensitive = secret.isEmpty ? nil : try JSONSerialization.data(withJSONObject: secret,
                                                                          options: [.sortedKeys])
        return (plain, sensitive)
    }

    /// The inverse of `split`.
    static func merge<Value: VaultStorable>(_ type: Value.Type, plain: Data, sensitive: Data?) throws -> Value {
        guard let sensitive else { return try makeDecoder().decode(type, from: plain) }
        guard var object = try JSONSerialization.jsonObject(with: plain) as? [String: Any],
              let secret = try JSONSerialization.jsonObject(with: sensitive) as? [String: Any] else {
            throw Failure.notAnObject
        }
        object.merge(secret) { _, new in new }
        return try makeDecoder().decode(type, from: JSONSerialization.data(withJSONObject: object))
    }
}
