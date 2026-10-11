//
//  SystemMessageSender.swift
//  BelloHub
//

import Foundation
import UIKit

/// The real thing. `universalLinksOnly` makes `https://wa.me/...` open the WhatsApp app and nothing else: without it,
/// a phone with no WhatsApp would open the link in Safari, and the fallback to the Messages app would never run. It
/// also needs no `LSApplicationQueriesSchemes` entry, so the app does not ask the system which apps are installed.
@MainActor
final class SystemMessageSender: MessageSending {
    func openInApp(_ url: URL) async -> Bool {
        let universalOnly = url.scheme == "https" || url.scheme == "http"
        let options: [UIApplication.OpenExternalURLOptionsKey: Any] = universalOnly
            ? [.universalLinksOnly: true] : [:]
        return await UIApplication.shared.open(url, options: options)
    }
}
