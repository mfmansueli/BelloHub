//
//  QuickReply.swift
//  BelloHub
//

import Foundation

/// One ready-made message she sends a client from WhatsApp (docs/07-LOCALIZATION.md section 6). The text may carry the
/// words `{name} {service} {date} {time} {link}`, filled in for each client by `QuickReplyRenderer`. Stored in the
/// clear in the vault: it is her own wording and holds no client data.
///
/// No message ever contains clinical content (docs/06-PRIVACY-SECURITY.md section 8); the built-in ones are general.
struct QuickReply: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    /// Which built-in message this one started as; nil for one she wrote. Lets her put the original back.
    var builtInKey: String?
    var title: String
    var text: String
    var position: Int
    var updatedAt: Date

    /// The built-in message this one started as.
    var builtIn: BuiltInQuickReply? {
        builtInKey.flatMap(BuiltInQuickReply.init(rawValue:))
    }

    /// Longest message she can save: WhatsApp takes far more, but a longer text is no longer a quick reply.
    static let maxTextLength = 1000
    static let maxTitleLength = 40
}
