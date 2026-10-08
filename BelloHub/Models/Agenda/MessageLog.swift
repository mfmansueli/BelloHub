//
//  MessageLog.swift
//  BelloHub
//

import Foundation

/// Records that a chat was **opened** with the text ready. The app never sends by itself (D14), so this is
/// "she was about to send", not "it was sent".
struct MessageLog: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var clientID: UUID
    var channel: MessageChannel
    /// The template kind (`reminder`, `winBack`, ...), never the text: messages stay out of the log.
    var template: String
    var openedAt: Date
}
