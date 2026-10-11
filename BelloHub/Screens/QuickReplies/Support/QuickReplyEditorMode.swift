//
//  QuickReplyEditorMode.swift
//  BelloHub
//

import Foundation

/// What the quick reply sheet is for: a new reply or one she opened. `Identifiable`, so `.sheet(item:)` builds a fresh
/// sheet for each.
enum QuickReplyEditorMode: Identifiable, Equatable {
    case add
    case edit(QuickReply)

    var id: String {
        switch self {
        case .add: "new"
        case .edit(let reply): reply.id.uuidString
        }
    }

    var reply: QuickReply? {
        if case .edit(let reply) = self { reply } else { nil }
    }
}
