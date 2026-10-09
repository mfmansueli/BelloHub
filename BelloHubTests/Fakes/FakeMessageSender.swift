//
//  FakeMessageSender.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation

/// A phone that records the links it was asked to open. `opens` decides, per scheme, whether an app took the link.
@MainActor
final class FakeMessageSender: MessageSending {
    var whatsAppInstalled = true
    var messagesAvailable = true
    private(set) var opened: [URL] = []

    func openInApp(_ url: URL) async -> Bool {
        opened.append(url)
        switch url.scheme {
        case "https": return whatsAppInstalled
        case "sms": return messagesAvailable
        default: return false
        }
    }
}
