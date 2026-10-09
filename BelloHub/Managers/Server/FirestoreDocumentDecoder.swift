//
//  FirestoreDocumentDecoder.swift
//  BelloHub
//

import Foundation

/// Turns a Firestore REST document (`{name, fields: {key: {stringValue: ...}}}`) into the plain JSON the models
/// decode: typed wrappers unwrapped, timestamps rewritten as `CallableJSON` instants (the REST API writes up to nine
/// fractional digits), the document id (last segment of `name`) added as `"id"`. Pure, so the mapping is tested
/// without a network.
enum FirestoreDocumentDecoder {
    /// Plain JSON bytes of one document, or nil when `object` is not a document.
    static func data(fromDocument object: [String: Any]) -> Data? {
        guard let name = object["name"] as? String, let id = name.split(separator: "/").last else { return nil }
        var fields = json(fromFields: object["fields"] as? [String: Any] ?? [:])
        fields["id"] = String(id)
        return try? JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
    }

    /// The documents of a `runQuery` answer (`[{document: {...}}]`) or a list answer (`{documents: [...]}`).
    static func documents(fromResponse body: Data) -> [Data] {
        guard let object = try? JSONSerialization.jsonObject(with: body) else { return [] }
        if let rows = object as? [[String: Any]] {
            return rows.compactMap { ($0["document"] as? [String: Any]).flatMap(data(fromDocument:)) }
        }
        if let page = object as? [String: Any], let documents = page["documents"] as? [[String: Any]] {
            return documents.compactMap(data(fromDocument:))
        }
        return []
    }

    static func json(fromFields fields: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, wrapped) in fields {
            if let wrapped = wrapped as? [String: Any], let value = value(from: wrapped) { result[key] = value }
        }
        return result
    }

    // MARK: - Values

    private static func value(from wrapped: [String: Any]) -> Any? {
        if let text = wrapped["stringValue"] as? String { return text }
        if let integer = wrapped["integerValue"] {
            // The REST API writes 64-bit integers as strings.
            if let text = integer as? String {
                if let whole = Int(text) { return whole }
                return Double(text) ?? 0
            }
            return integer
        }
        if let number = wrapped["doubleValue"] { return number }
        if let flag = wrapped["booleanValue"] as? Bool { return flag }
        if let stamp = wrapped["timestampValue"] as? String { return instant(stamp) }
        if wrapped.keys.contains("nullValue") { return NSNull() }
        if let map = wrapped["mapValue"] as? [String: Any] {
            return json(fromFields: map["fields"] as? [String: Any] ?? [:])
        }
        if let array = wrapped["arrayValue"] as? [String: Any] {
            let values = array["values"] as? [[String: Any]] ?? []
            return values.compactMap(value(from:))
        }
        if let reference = wrapped["referenceValue"] as? String { return reference }
        return nil
    }

    /// Nine fractional digits become three, so `CallableJSON.decoder` reads it like a function result.
    private static func instant(_ text: String) -> String {
        if let date = try? Date(text, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) {
            return CallableJSON.instant(date)
        }
        if let date = try? Date(text, strategy: Date.ISO8601FormatStyle()) { return CallableJSON.instant(date) }
        return text
    }
}
