//
//  PersistedEnum.swift
//  BelloHub
//

/// An enum stored as its `String` raw value. Reading a value written by a newer version of the app, with a case
/// this version does not know, must never crash and never lose data: decoding and `init(persisted:)` fall back to a
/// safe default instead (docs/05-DATA-MODEL.md section 1, forward compatibility). The store keeps the original raw
/// string, so the newer app still reads its own value.
protocol PersistedEnum: Codable, RawRepresentable, CaseIterable, Sendable where RawValue == String {
    /// The case used when the stored raw value is unknown to this version.
    static var fallback: Self { get }
}

extension PersistedEnum {
    init(persisted rawValue: String) {
        self = Self(rawValue: rawValue) ?? Self.fallback
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(persisted: try container.decode(String.self))
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
