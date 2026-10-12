//
//  SuggestedField.swift
//  BelloHub
//

/// A field of the treatment record the catalog suggests for a profession.
struct SuggestedField: Identifiable, Hashable, Codable, Sendable {
    let key: String
    let name: String
    /// Whether it starts switched on.
    let on: Bool
    /// The quick answers the field offers as chips, in the profession's own words ("Oily", "Rosacea", "0,07 mm"): one
    /// tap writes one on its own line, and she can still type anything. Empty for a free note.
    var tags: [String] = []

    var id: String { key }

    init(key: String, name: String, on: Bool, tags: [String] = []) {
        self.key = key
        self.name = name
        self.on = on
        self.tags = tags
    }

    private enum CodingKeys: String, CodingKey {
        case key, name, on, tags
    }

    /// A catalog written before quick tags has none.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(String.self, forKey: .key)
        name = try container.decode(String.self, forKey: .name)
        on = try container.decode(Bool.self, forKey: .on)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
    }
}
