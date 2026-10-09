//
//  MessageDispatchPlan.swift
//  BelloHub
//

import Foundation

/// The ways to get one message to a client, in the order to try them: WhatsApp when it is installed, then the Messages
/// app, then the system share sheet, which always works (so a client with no number, or an iPhone without WhatsApp or
/// SMS, still gets the text to copy or send some other way). Pure: the service walks `attempts` and stops at the first
/// that opens.
struct MessageDispatchPlan: Equatable, Sendable {
    enum Attempt: Equatable, Sendable {
        case whatsApp(URL)
        case sms(URL)
        /// The share sheet: needs no number and no app.
        case share

        var channel: MessageChannel {
            switch self {
            case .whatsApp: .whatsapp
            case .sms: .sms
            case .share: .share
            }
        }
    }

    let attempts: [Attempt]

    /// `preferred` is the region's usual channel (`RegionPreset`): WhatsApp first almost everywhere, Messages first
    /// where people text.
    static func make(phoneE164: String?, text: String, preferred: MessagingChannel = .whatsapp) -> MessageDispatchPlan {
        var attempts: [Attempt] = []
        let whatsApp = MessageLinks.whatsApp(phoneE164: phoneE164, text: text).map(Attempt.whatsApp)
        let sms = MessageLinks.sms(phoneE164: phoneE164, text: text).map(Attempt.sms)
        switch preferred {
        case .whatsapp: attempts += [whatsApp, sms].compactMap { $0 }
        case .messages: attempts += [sms, whatsApp].compactMap { $0 }
        }
        attempts.append(.share)
        return MessageDispatchPlan(attempts: attempts)
    }
}
