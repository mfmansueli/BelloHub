//
//  SystemClipboard.swift
//  BelloHub
//

import UIKit

/// The iPhone's general pasteboard. Writing to it needs no permission and shows no prompt.
struct SystemClipboard: ClipboardWriting {
    func write(_ text: String) {
        UIPasteboard.general.string = text
    }
}
