//
//  ClientMessageRequest.swift
//  BelloHub
//

import Foundation

/// A message to a client that is not about one visit: a follow-up, a win-back note, birthday wishes or a plain hello
/// from her record. The sheet opens
/// with the text ready; she reads it, may edit it, and presses send in WhatsApp (D14: nothing is sent by the app).
struct ClientMessageRequest: Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        /// The return date of a service has arrived; the service is the one of her last visit.
        case followUp(serviceName: String)
        /// She has not been back for two months or more.
        case winBack
        case birthday
        /// "Message" on her client record: a greeting with her name, for whatever she wants to say.
        case general
    }

    let clientID: UUID
    let kind: Kind

    /// What the message log keeps: the kind, never the text.
    var logTemplate: String {
        switch kind {
        case .followUp: "followUp"
        case .winBack: "winBack"
        case .birthday: "birthday"
        case .general: "general"
        }
    }
}
