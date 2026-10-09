//
//  ClipboardWriting.swift
//  BelloHub
//

/// Puts text on the system clipboard. A protocol so a ViewModel that copies a link never touches `UIPasteboard` and its
/// tests can see what was copied.
@MainActor
protocol ClipboardWriting {
    func write(_ text: String)
}
