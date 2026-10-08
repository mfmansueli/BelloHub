//
//  HealthAnswer.swift
//  BelloHub
//

import Foundation

/// One answer of a health form. A form version defines the questions; answers are keyed by question key.
enum HealthAnswer: Hashable, Codable, Sendable {
    case yes
    case no
    case text(String)
    case choices([String])

    private enum CodingKeys: String, CodingKey {
        case kind
        case value
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .kind) {
        case "yes": self = .yes
        case "no": self = .no
        case "choices": self = .choices(try container.decode([String].self, forKey: .value))
        default: self = .text(try container.decodeIfPresent(String.self, forKey: .value) ?? "")
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .yes: try container.encode("yes", forKey: .kind)
        case .no: try container.encode("no", forKey: .kind)
        case .text(let value):
            try container.encode("text", forKey: .kind)
            try container.encode(value, forKey: .value)
        case .choices(let values):
            try container.encode("choices", forKey: .kind)
            try container.encode(values, forKey: .value)
        }
    }
}
