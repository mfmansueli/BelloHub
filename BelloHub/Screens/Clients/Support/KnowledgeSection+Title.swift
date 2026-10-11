//
//  KnowledgeSection+Title.swift
//  BelloHub
//

import SwiftUI

extension KnowledgeSection {
    /// The heading of the list, in the reader's language.
    var title: LocalizedStringKey {
        switch self {
        case .sensitivities: "clientKnowledge.section.sensitivities"
        case .preferences: "clientKnowledge.section.preferences"
        case .recurringRequests: "clientKnowledge.section.recurringRequests"
        }
    }
}
