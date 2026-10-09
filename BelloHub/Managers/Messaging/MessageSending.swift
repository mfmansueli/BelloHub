//
//  MessageSending.swift
//  BelloHub
//

import Foundation

/// Opens another app with a message ready, behind a protocol so the screens are tested without leaving the app (like
/// `PhoneLaunching`). The app never sends by itself (D14): the other app opens, she reads the text and presses send.
@MainActor
protocol MessageSending: AnyObject {
    /// Opens `url` in the app that owns it, **only** when an app does (WhatsApp installed). False when none handles
    /// it, so the caller can fall back instead of landing on a web page.
    func openInApp(_ url: URL) async -> Bool
}
