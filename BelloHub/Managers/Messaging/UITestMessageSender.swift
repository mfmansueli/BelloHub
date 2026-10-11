//
//  UITestMessageSender.swift
//  BelloHub
//

#if DEBUG
import Foundation

/// What a UI-test launch uses in place of the system: it pretends WhatsApp is installed and opens nothing, so a
/// test can press "Open WhatsApp" without the app leaving the screen. DEBUG only.
@MainActor
final class UITestMessageSender: MessageSending {
    func openInApp(_ url: URL) async -> Bool {
        url.scheme == "https"
    }
}
#endif
