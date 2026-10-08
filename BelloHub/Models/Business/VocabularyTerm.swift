//
//  VocabularyTerm.swift
//  BelloHub
//

import Foundation

/// A name the professional uses for a service or a protocol ("Protocol 360"), kept exactly as she typed it.
struct VocabularyTerm: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var text: String
    var kind: VocabularyKind

    init(id: UUID = UUID(), text: String, kind: VocabularyKind = .service) {
        self.id = id
        self.text = text
        self.kind = kind
    }
}
